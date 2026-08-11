-- ═══════════════════════════════════════════════════════════════
-- PARCHE: Facturación profesional (Finanzas)
-- - Agrupa los cobros TPV en "cobros" (columna cobro_id en transacciones).
-- - Crea facturas numeradas secuencialmente por año (F-2026-000123).
-- - Configuración del emisor (CIF, dirección, IVA…) en facturacion_config.
-- - RPCs: facturar_cobro, anular_factura, obtener/guardar facturacion_config.
-- - Actualiza tpv_cobrar_ticket para sellar cobro_id y guardar detalle por línea.
-- - Al anular una venta, se anula automáticamente su factura si existía.
-- Ejecutar en Supabase → SQL Editor (después de supabase_patch_tpv_cobrar_ticket.sql
-- y supabase_patch_caja_apertura_cierre.sql).
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────
-- 1. Agrupar cobros: cobro_id en transacciones
-- ───────────────────────────────────────────────
ALTER TABLE public.transacciones
  ADD COLUMN IF NOT EXISTS cobro_id UUID;

-- Backfill: las transacciones anteriores a este parche son su propio cobro.
UPDATE public.transacciones SET cobro_id = id WHERE cobro_id IS NULL;

-- Detalle por línea (nombre, qty, precio unitario) para reconstruir la factura.
ALTER TABLE public.transacciones
  ADD COLUMN IF NOT EXISTS detalle JSONB;

CREATE INDEX IF NOT EXISTS idx_transacciones_cobro ON public.transacciones(cobro_id);

-- ───────────────────────────────────────────────
-- 2. Tabla facturas
-- ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.facturas (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  numero           TEXT NOT NULL UNIQUE,
  anio             INTEGER NOT NULL,
  secuencia        INTEGER NOT NULL,
  cobro_id         UUID NOT NULL UNIQUE,
  perfil_id        UUID NOT NULL REFERENCES public.perfiles(id),
  cliente_nombre   TEXT,
  cliente_email    TEXT,
  importe_base     DECIMAL(12,2) NOT NULL DEFAULT 0,
  iva_porcentaje   DECIMAL(5,2)  NOT NULL DEFAULT 21,
  importe_iva      DECIMAL(12,2) NOT NULL DEFAULT 0,
  importe_total    DECIMAL(12,2) NOT NULL DEFAULT 0,
  metodo_pago      TEXT,
  nota             TEXT,
  lineas           JSONB NOT NULL DEFAULT '[]'::jsonb,
  emitida_por      UUID REFERENCES public.perfiles(id),
  estado           TEXT NOT NULL DEFAULT 'emitida' CHECK (estado IN ('emitida', 'anulada')),
  motivo_anulacion TEXT,
  anulada_por      UUID REFERENCES public.perfiles(id),
  anulada_at       TIMESTAMPTZ,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_facturas_anio ON public.facturas(anio, secuencia);
CREATE INDEX IF NOT EXISTS idx_facturas_perfil ON public.facturas(perfil_id);
CREATE INDEX IF NOT EXISTS idx_facturas_estado ON public.facturas(estado);

ALTER TABLE public.facturas ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve facturas" ON public.facturas;
CREATE POLICY "Staff ve facturas" ON public.facturas
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta facturas" ON public.facturas;
CREATE POLICY "Staff inserta facturas" ON public.facturas
  FOR INSERT WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff actualiza facturas" ON public.facturas;
CREATE POLICY "Staff actualiza facturas" ON public.facturas
  FOR UPDATE USING (public.mi_rol() IN ('empleado', 'admin'));

-- ───────────────────────────────────────────────
-- 3. Configuración del emisor (una única fila, id = 1)
-- ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.facturacion_config (
  id               INTEGER PRIMARY KEY CHECK (id = 1),
  nombre_emisor    TEXT NOT NULL DEFAULT 'NŌVA Pilates Studio',
  cif              TEXT NOT NULL DEFAULT '[pendiente de publicar]',
  direccion        TEXT,
  ciudad           TEXT DEFAULT 'Sevilla',
  codigo_postal    TEXT,
  telefono         TEXT,
  email            TEXT,
  iva_porcentaje   DECIMAL(5,2) NOT NULL DEFAULT 21 CHECK (iva_porcentaje >= 0 AND iva_porcentaje <= 100),
  pie_factura      TEXT DEFAULT 'Desconecta de lo de fuera. Conecta contigo.',
  updated_by       UUID REFERENCES public.perfiles(id),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.facturacion_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.facturacion_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve configuracion facturacion" ON public.facturacion_config;
CREATE POLICY "Staff ve configuracion facturacion" ON public.facturacion_config
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Admin gestiona configuracion facturacion" ON public.facturacion_config;
CREATE POLICY "Admin gestiona configuracion facturacion" ON public.facturacion_config
  FOR ALL USING (public.mi_rol() = 'admin') WITH CHECK (public.mi_rol() = 'admin');

-- ───────────────────────────────────────────────
-- 4. tpv_cobrar_ticket actualizado: sella cobro_id y detalle por línea
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.tpv_cobrar_ticket(
  p_cliente_id UUID,
  p_metodo_pago TEXT,
  p_nota TEXT DEFAULT NULL,
  p_lineas JSONB DEFAULT '[]'::jsonb
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_cliente RECORD;
  v_metodo TEXT := lower(trim(coalesce(p_metodo_pago, '')));
  v_linea JSONB;
  v_kind TEXT;
  v_idx INT := 0;
  v_bono_count INT := 0;
  v_qty INT;
  v_importe NUMERIC(10,2);
  v_nombre TEXT;
  v_tipo RECORD;
  v_prod RECORD;
  v_bono_id UUID;
  v_tx_id UUID;
  v_cobro_id UUID := uuid_generate_v4();
  v_fecha_inicio DATE := CURRENT_DATE;
  v_fecha_fin DATE;
  v_dias INT;
  v_nota_linea TEXT;
  v_nota_global TEXT := nullif(trim(coalesce(p_nota, '')), '');
  v_total NUMERIC(10,2) := 0;
  v_resumen TEXT[] := ARRAY[]::TEXT[];
  v_tx_ids UUID[] := ARRAY[]::UUID[];
  v_line_label TEXT;
  v_detalle JSONB;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  IF v_metodo NOT IN ('efectivo', 'tarjeta', 'transferencia') THEN
    RAISE EXCEPTION 'Método de pago no válido.';
  END IF;

  IF p_cliente_id IS NULL THEN
    RAISE EXCEPTION 'Selecciona un cliente.';
  END IF;

  SELECT id, email, rol
    INTO v_cliente
  FROM public.perfiles
  WHERE id = p_cliente_id;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Cliente no encontrado.';
  END IF;

  IF jsonb_typeof(p_lineas) IS DISTINCT FROM 'array' OR jsonb_array_length(p_lineas) = 0 THEN
    RAISE EXCEPTION 'El ticket está vacío.';
  END IF;

  FOR v_linea IN SELECT * FROM jsonb_array_elements(p_lineas)
  LOOP
    IF lower(coalesce(v_linea->>'kind', '')) = 'bono' THEN
      v_bono_count := v_bono_count + 1;
    END IF;
  END LOOP;

  IF v_bono_count > 1 THEN
    RAISE EXCEPTION 'Solo puede haber un bono por ticket.';
  END IF;

  FOR v_linea IN SELECT * FROM jsonb_array_elements(p_lineas)
  LOOP
    v_idx := v_idx + 1;
    v_kind := lower(trim(coalesce(v_linea->>'kind', '')));

    IF v_kind = 'producto' THEN
      v_qty := greatest(1, least(99, coalesce((v_linea->>'qty')::int, 1)));

      IF (v_linea->>'producto_id') IS NULL OR (v_linea->>'producto_id') = '' THEN
        RAISE EXCEPTION 'Línea %: falta producto_id.', v_idx;
      END IF;

      SELECT id, nombre, precio_referencia, activo
        INTO v_prod
      FROM public.productos_tienda
      WHERE id = (v_linea->>'producto_id')::uuid;

      IF NOT FOUND OR v_prod.activo IS NOT TRUE THEN
        RAISE EXCEPTION 'Línea %: producto no disponible.', v_idx;
      END IF;

      v_importe := round(coalesce(v_prod.precio_referencia, 0) * v_qty, 2);
      IF v_importe <= 0 THEN
        RAISE EXCEPTION 'Línea %: importe inválido.', v_idx;
      END IF;

      v_nombre := v_prod.nombre;
      v_nota_linea := 'Tienda · ' || v_nombre;
      IF v_qty > 1 THEN
        v_nota_linea := v_nota_linea || ' × ' || v_qty::text;
      END IF;
      IF v_nota_global IS NOT NULL THEN
        v_nota_linea := v_nota_linea || ' · ' || v_nota_global;
      END IF;

      v_detalle := jsonb_build_object('lineas', jsonb_build_array(
        jsonb_build_object(
          'kind', 'producto',
          'nombre', v_nombre,
          'qty', v_qty,
          'unit', coalesce(v_prod.precio_referencia, 0)
        )
      ));

      INSERT INTO public.transacciones (
        perfil_id, bono_activo_id, tipo_bono_id, importe, metodo_pago, nota,
        registrado_por, cobro_id, detalle
      ) VALUES (
        p_cliente_id, NULL, NULL, v_importe, v_metodo, v_nota_linea, v_uid,
        v_cobro_id, v_detalle
      )
      RETURNING id INTO v_tx_id;

      v_tx_ids := array_append(v_tx_ids, v_tx_id);
      v_line_label := v_nombre || CASE WHEN v_qty > 1 THEN ' ×' || v_qty::text ELSE '' END
        || ' (' || to_char(v_importe, 'FM999999990.00') || ' €)';
      v_resumen := array_append(v_resumen, v_line_label);
      v_total := v_total + v_importe;

    ELSIF v_kind = 'bono' THEN
      IF (v_linea->>'tipo_bono_id') IS NULL OR (v_linea->>'tipo_bono_id') = '' THEN
        RAISE EXCEPTION 'Línea %: falta tipo_bono_id.', v_idx;
      END IF;

      SELECT id, nombre, sesiones, duracion_dias, precio, activo
        INTO v_tipo
      FROM public.tipos_bono
      WHERE id = (v_linea->>'tipo_bono_id')::uuid;

      IF NOT FOUND OR v_tipo.activo IS NOT TRUE THEN
        RAISE EXCEPTION 'Línea %: tipo de bono no disponible.', v_idx;
      END IF;

      v_importe := round(coalesce(v_tipo.precio, 0), 2);
      IF v_importe <= 0 THEN
        RAISE EXCEPTION 'Línea %: importe de bono inválido.', v_idx;
      END IF;

      v_dias := greatest(1, coalesce(v_tipo.duracion_dias, 30));
      v_fecha_fin := v_fecha_inicio + v_dias;

      UPDATE public.bonos_activos
      SET activo = FALSE
      WHERE perfil_id = p_cliente_id
        AND activo = TRUE;

      INSERT INTO public.bonos_activos (
        perfil_id, tipo_bono_id, sesiones_totales, sesiones_usadas,
        fecha_inicio, fecha_fin, activo, asignado_por, notas
      ) VALUES (
        p_cliente_id, v_tipo.id, v_tipo.sesiones, 0,
        v_fecha_inicio, v_fecha_fin, TRUE, v_uid, 'TPV'
      )
      RETURNING id INTO v_bono_id;

      v_detalle := jsonb_build_object('lineas', jsonb_build_array(
        jsonb_build_object(
          'kind', 'bono',
          'nombre', v_tipo.nombre,
          'qty', 1,
          'unit', coalesce(v_tipo.precio, 0),
          'sesiones', v_tipo.sesiones
        )
      ));

      INSERT INTO public.transacciones (
        perfil_id, bono_activo_id, tipo_bono_id, importe, metodo_pago, nota,
        registrado_por, cobro_id, detalle
      ) VALUES (
        p_cliente_id, v_bono_id, v_tipo.id, v_importe, v_metodo, v_nota_global, v_uid,
        v_cobro_id, v_detalle
      )
      RETURNING id INTO v_tx_id;

      v_tx_ids := array_append(v_tx_ids, v_tx_id);
      v_line_label := v_tipo.nombre || ' (' || to_char(v_importe, 'FM999999990.00') || ' €)';
      v_resumen := array_append(v_resumen, v_line_label);
      v_total := v_total + v_importe;

    ELSE
      RAISE EXCEPTION 'Línea %: tipo no reconocido (usa bono o producto).', v_idx;
    END IF;
  END LOOP;

  IF v_total <= 0 THEN
    RAISE EXCEPTION 'Total del ticket inválido.';
  END IF;

  RETURN jsonb_build_object(
    'ok', true,
    'cobro_id', v_cobro_id,
    'total', v_total,
    'metodo_pago', v_metodo,
    'lineas', to_jsonb(v_resumen),
    'num_lineas', jsonb_array_length(p_lineas),
    'transaccion_ids', to_jsonb(v_tx_ids)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tpv_cobrar_ticket(UUID, TEXT, TEXT, JSONB) TO authenticated;

-- ───────────────────────────────────────────────
-- 5. RPC: emitir / recuperar factura de un cobro (idempotente)
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.facturar_cobro(p_cobro_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_factura RECORD;
  v_anio INT := EXTRACT(YEAR FROM NOW())::int;
  v_secuencia INT;
  v_numero TEXT;
  v_cliente RECORD;
  v_cfg RECORD;
  v_tx RECORD;
  v_total NUMERIC(12,2) := 0;
  v_base NUMERIC(12,2);
  v_iva NUMERIC(12,2);
  v_iva_pct NUMERIC(5,2);
  v_metodo TEXT;
  v_nota TEXT;
  v_lineas JSONB := '[]'::jsonb;
  v_nombre TEXT;
  v_qty INT;
  v_unit NUMERIC(12,2);
  v_item JSONB;
  v_detalle_lineas JSONB;
  v_id UUID;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  IF p_cobro_id IS NULL THEN
    RAISE EXCEPTION 'Falta el identificador del cobro.';
  END IF;

  -- Idempotente: si ya hay factura para este cobro, devuelve la existente.
  SELECT * INTO v_factura FROM public.facturas WHERE cobro_id = p_cobro_id;
  IF FOUND THEN
    RETURN v_factura.id;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.transacciones WHERE cobro_id = p_cobro_id) THEN
    RAISE EXCEPTION 'Cobro no encontrado.';
  END IF;

  SELECT * INTO v_cfg FROM public.facturacion_config WHERE id = 1;
  IF NOT FOUND THEN
    INSERT INTO public.facturacion_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
    SELECT * INTO v_cfg FROM public.facturacion_config WHERE id = 1;
  END IF;
  v_iva_pct := coalesce(v_cfg.iva_porcentaje, 21);

  -- Numeración secuencial por año con bloqueo de transacción.
  PERFORM pg_advisory_xact_lock(hashtext('nova_factura_' || v_anio::text));

  -- Re-comprueba dentro del bloqueo: otro proceso pudo crear la factura mientras esperábamos.
  SELECT * INTO v_factura FROM public.facturas WHERE cobro_id = p_cobro_id;
  IF FOUND THEN
    RETURN v_factura.id;
  END IF;

  SELECT COALESCE(MAX(secuencia), 0) + 1 INTO v_secuencia
  FROM public.facturas
  WHERE anio = v_anio;
  v_numero := 'F-' || v_anio::text || '-' || lpad(v_secuencia::text, 6, '0');

  FOR v_tx IN
    SELECT * FROM public.transacciones
    WHERE cobro_id = p_cobro_id
    ORDER BY created_at ASC, id ASC
  LOOP
    v_total := v_total + coalesce(v_tx.importe, 0);
    v_metodo := coalesce(v_tx.metodo_pago, v_metodo);
    v_nota := coalesce(v_tx.nota, v_nota);

    -- Detalle preferido (escrito por tpv_cobrar_ticket).
    v_detalle_lineas := v_tx.detalle -> 'lineas';
    IF jsonb_typeof(v_detalle_lineas) = 'array' AND jsonb_array_length(v_detalle_lineas) > 0 THEN
      SELECT elem
        INTO v_item
      FROM jsonb_array_elements(v_detalle_lineas) AS elem
      LIMIT 1;
    ELSE
      -- Fallback para cobros anteriores al parche.
      IF v_tx.tipo_bono_id IS NOT NULL THEN
        SELECT nombre INTO v_nombre FROM public.tipos_bono WHERE id = v_tx.tipo_bono_id;
        v_item := jsonb_build_object('kind', 'bono', 'nombre', coalesce(v_nombre, 'Bono'),
                                     'qty', 1, 'unit', v_tx.importe);
      ELSE
        v_nombre := regexp_replace(coalesce(v_tx.nota, ''), '^Tienda ·\s*', '');
        v_item := jsonb_build_object('kind', 'producto', 'nombre',
                                     coalesce(nullif(v_nombre, ''), 'Venta'),
                                     'qty', 1, 'unit', v_tx.importe);
      END IF;
    END IF;

    v_lineas := v_lineas || jsonb_build_array(v_item);
  END LOOP;

  v_base := round(v_total / (1 + v_iva_pct / 100), 2);
  v_iva := round(v_total - v_base, 2);

  SELECT perfil_id, cliente_nombre, cliente_email
    INTO v_cliente
  FROM (
    SELECT t.perfil_id,
           COALESCE(p.nombre || ' ' || coalesce(p.apellidos, ''), p.email) AS cliente_nombre,
           p.email AS cliente_email
    FROM public.transacciones t
    JOIN public.perfiles p ON p.id = t.perfil_id
    WHERE t.cobro_id = p_cobro_id
    ORDER BY t.created_at ASC, t.id ASC
    LIMIT 1
  ) AS sub;

  INSERT INTO public.facturas (
    numero, anio, secuencia, cobro_id, perfil_id, cliente_nombre, cliente_email,
    importe_base, iva_porcentaje, importe_iva, importe_total,
    metodo_pago, nota, lineas, emitida_por, estado
  ) VALUES (
    v_numero, v_anio, v_secuencia, p_cobro_id, v_cliente.perfil_id,
    v_cliente.cliente_nombre, v_cliente.cliente_email,
    v_base, v_iva_pct, v_iva, v_total,
    v_metodo, v_nota, v_lineas, v_uid, 'emitida'
  )
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.facturar_cobro(UUID) TO authenticated;

-- ───────────────────────────────────────────────
-- 6. RPC: anular factura
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.anular_factura(p_factura_id UUID, p_motivo TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_factura RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT * INTO v_factura FROM public.facturas WHERE id = p_factura_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Factura no encontrada.';
  END IF;

  IF v_factura.estado = 'anulada' THEN
    RAISE EXCEPTION 'La factura ya está anulada.';
  END IF;

  IF v_rol = 'empleado' AND v_factura.emitida_por IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Solo puedes anular facturas que emitiste tú.';
  END IF;

  UPDATE public.facturas
  SET estado = 'anulada',
      motivo_anulacion = coalesce(nullif(trim(coalesce(p_motivo, '')), ''), 'Anulada por el staff'),
      anulada_por = v_uid,
      anulada_at = NOW()
  WHERE id = p_factura_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.anular_factura(UUID, TEXT) TO authenticated;

-- ───────────────────────────────────────────────
-- 7. RPCs de configuración del emisor
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.obtener_facturacion_config()
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_cfg RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT * INTO v_cfg FROM public.facturacion_config WHERE id = 1;
  IF NOT FOUND THEN
    INSERT INTO public.facturacion_config (id) VALUES (1) ON CONFLICT (id) DO NOTHING;
    SELECT * INTO v_cfg FROM public.facturacion_config WHERE id = 1;
  END IF;

  RETURN to_jsonb(v_cfg);
END;
$$;

GRANT EXECUTE ON FUNCTION public.obtener_facturacion_config() TO authenticated;

CREATE OR REPLACE FUNCTION public.guardar_facturacion_config(
  p_nombre_emisor TEXT,
  p_cif TEXT,
  p_direccion TEXT DEFAULT NULL,
  p_ciudad TEXT DEFAULT NULL,
  p_codigo_postal TEXT DEFAULT NULL,
  p_telefono TEXT DEFAULT NULL,
  p_email TEXT DEFAULT NULL,
  p_iva_porcentaje DECIMAL DEFAULT 21,
  p_pie_factura TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() <> 'admin' THEN
    RAISE EXCEPTION 'Solo administración puede editar la configuración de facturación.';
  END IF;

  INSERT INTO public.facturacion_config (id)
  VALUES (1)
  ON CONFLICT (id) DO NOTHING;

  UPDATE public.facturacion_config
  SET nombre_emisor    = coalesce(nullif(trim(p_nombre_emisor), ''), 'NŌVA Pilates Studio'),
      cif              = coalesce(nullif(trim(p_cif), ''), '[pendiente de publicar]'),
      direccion        = nullif(trim(coalesce(p_direccion, '')), ''),
      ciudad           = nullif(trim(coalesce(p_ciudad, '')), ''),
      codigo_postal    = nullif(trim(coalesce(p_codigo_postal, '')), ''),
      telefono         = nullif(trim(coalesce(p_telefono, '')), ''),
      email            = nullif(trim(coalesce(p_email, '')), ''),
      iva_porcentaje   = greatest(0, least(100, coalesce(p_iva_porcentaje, 21))),
      pie_factura      = nullif(trim(coalesce(p_pie_factura, '')), ''),
      updated_by       = v_uid,
      updated_at       = NOW()
  WHERE id = 1;
END;
$$;

GRANT EXECUTE ON FUNCTION public.guardar_facturacion_config(
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, DECIMAL, TEXT
) TO authenticated;

-- ───────────────────────────────────────────────
-- 8. Al anular una venta, anular su factura si existe
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.anular_transaccion_tpv(p_transaccion_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  r RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT t.* INTO r FROM public.transacciones t WHERE t.id = p_transaccion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transacción no encontrada.';
  END IF;

  IF v_rol = 'empleado' AND (r.registrado_por IS DISTINCT FROM v_uid) THEN
    RAISE EXCEPTION 'Solo puedes anular ventas que registraste tú.';
  END IF;

  IF r.bono_activo_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.reservas z
      WHERE z.bono_activo_id = r.bono_activo_id
        AND z.estado IS DISTINCT FROM 'cancelada'
    ) THEN
      RAISE EXCEPTION 'No se puede anular: hay reservas activas ligadas a este bono.';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.bonos_activos b
      WHERE b.id = r.bono_activo_id
        AND COALESCE(b.sesiones_usadas, 0) > 0
    ) THEN
      RAISE EXCEPTION 'No se puede anular: el bono ya tiene sesiones usadas.';
    END IF;

    UPDATE public.bonos_activos SET activo = FALSE WHERE id = r.bono_activo_id;
  END IF;

  DELETE FROM public.transacciones WHERE id = p_transaccion_id;

  -- Si el cobro tenía factura y ya no queda ninguna transacción, se anula.
  UPDATE public.facturas
  SET estado = 'anulada',
      motivo_anulacion = 'Factura anulada por anulación de la venta',
      anulada_por = v_uid,
      anulada_at = NOW()
  WHERE cobro_id = r.cobro_id
    AND estado = 'emitida'
    AND NOT EXISTS (
      SELECT 1 FROM public.transacciones x WHERE x.cobro_id = r.cobro_id
    );
END;
$$;

REVOKE ALL ON FUNCTION public.anular_transaccion_tpv(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.anular_transaccion_tpv(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.anular_transaccion_tpv(UUID) TO authenticated;

-- Empleados ven solo sus cobros (para listado y anulación); admin ya tenía SELECT global.
DROP POLICY IF EXISTS "Empleado ve sus transacciones registradas" ON public.transacciones;
CREATE POLICY "Empleado ve sus transacciones registradas" ON public.transacciones
  FOR SELECT USING (
    public.mi_rol() = 'empleado' AND registrado_por = auth.uid()
  );
