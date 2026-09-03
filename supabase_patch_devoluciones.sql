-- ═══════════════════════════════════════════════════════════════
-- PARCHE: Devoluciones y tickets regalo (Finanzas)
-- - devolver_cobro: reembolso de un cobro en efectivo o ticket regalo.
-- - vales_regalo: tickets regalo canjeables (código único, saldo,
--   caducidad y estados activo / canjeado / anulado).
-- - tpv_cobrar_ticket acepta pago con ticket regalo (p_vale_codigo).
-- - Guardas: un cobro solo se devuelve una vez; no se factura ni se
--   anula por separado un cobro devuelto; no se anula un reembolso.
-- Ejecutar en Supabase → SQL Editor (después de supabase_patch_facturacion.sql).
-- ═══════════════════════════════════════════════════════════════

-- ───────────────────────────────────────────────
-- 1. Tabla vales_regalo
-- ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vales_regalo (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  codigo           TEXT NOT NULL UNIQUE,
  importe_original DECIMAL(12,2) NOT NULL CHECK (importe_original > 0),
  saldo            DECIMAL(12,2) NOT NULL CHECK (saldo >= 0),
  estado           TEXT NOT NULL DEFAULT 'activo' CHECK (estado IN ('activo', 'canjeado', 'anulado')),
  cliente_id       UUID REFERENCES public.perfiles(id),
  emitido_por      UUID NOT NULL REFERENCES public.perfiles(id),
  devolucion_id    UUID,
  motivo           TEXT,
  valido_hasta     DATE NOT NULL,
  canjeado_at      TIMESTAMPTZ,
  anulado_at       TIMESTAMPTZ,
  anulado_por      UUID REFERENCES public.perfiles(id),
  motivo_anulacion TEXT,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vales_regalo_cliente ON public.vales_regalo(cliente_id);
CREATE INDEX IF NOT EXISTS idx_vales_regalo_estado ON public.vales_regalo(estado);

ALTER TABLE public.vales_regalo ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve vales regalo" ON public.vales_regalo;
CREATE POLICY "Staff ve vales regalo" ON public.vales_regalo
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta vales regalo" ON public.vales_regalo;
CREATE POLICY "Staff inserta vales regalo" ON public.vales_regalo
  FOR INSERT WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff actualiza vales regalo" ON public.vales_regalo;
CREATE POLICY "Staff actualiza vales regalo" ON public.vales_regalo
  FOR UPDATE USING (public.mi_rol() IN ('empleado', 'admin'));

-- ───────────────────────────────────────────────
-- 2. Tabla vales_regalo_uso (historial de canjes)
-- ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.vales_regalo_uso (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vale_id        UUID NOT NULL REFERENCES public.vales_regalo(id),
  cobro_id       UUID,
  monto          DECIMAL(12,2) NOT NULL CHECK (monto > 0),
  usado_en       UUID REFERENCES public.perfiles(id),
  registrado_por UUID NOT NULL REFERENCES public.perfiles(id),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_vales_uso_vale ON public.vales_regalo_uso(vale_id);

ALTER TABLE public.vales_regalo_uso ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve usos de vales" ON public.vales_regalo_uso;
CREATE POLICY "Staff ve usos de vales" ON public.vales_regalo_uso
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta usos de vales" ON public.vales_regalo_uso;
CREATE POLICY "Staff inserta usos de vales" ON public.vales_regalo_uso
  FOR INSERT WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

-- ───────────────────────────────────────────────
-- 3. Tabla devoluciones
-- ───────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.devoluciones (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cobro_id         UUID NOT NULL UNIQUE,
  factura_id       UUID REFERENCES public.facturas(id),
  importe_total    DECIMAL(12,2) NOT NULL CHECK (importe_total > 0),
  metodo_reembolso TEXT NOT NULL CHECK (metodo_reembolso IN ('efectivo', 'vale')),
  vale_regalo_id   UUID REFERENCES public.vales_regalo(id),
  motivo           TEXT,
  registrado_por   UUID NOT NULL REFERENCES public.perfiles(id),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_devoluciones_registrado ON public.devoluciones(registrado_por);

ALTER TABLE public.devoluciones ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve devoluciones" ON public.devoluciones;
CREATE POLICY "Staff ve devoluciones" ON public.devoluciones
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta devoluciones" ON public.devoluciones;
CREATE POLICY "Staff inserta devoluciones" ON public.devoluciones
  FOR INSERT WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff actualiza devoluciones" ON public.devoluciones;
CREATE POLICY "Staff actualiza devoluciones" ON public.devoluciones
  FOR UPDATE USING (public.mi_rol() IN ('empleado', 'admin'));

-- ───────────────────────────────────────────────
-- 4. Columnas nuevas en transacciones
-- ───────────────────────────────────────────────
ALTER TABLE public.transacciones
  ADD COLUMN IF NOT EXISTS tipo_movimiento TEXT NOT NULL DEFAULT 'venta'
    CHECK (tipo_movimiento IN ('venta', 'reembolso')),
  ADD COLUMN IF NOT EXISTS devolucion_id UUID REFERENCES public.devoluciones(id),
  ADD COLUMN IF NOT EXISTS vale_regalo_id UUID REFERENCES public.vales_regalo(id);

-- ───────────────────────────────────────────────
-- 5. tpv_cobrar_ticket: pago con ticket regalo
-- ───────────────────────────────────────────────
-- Se elimina la sobrecarga anterior de 4 parámetros para evitar
-- llamadas ambiguas ("function is not unique") con la nueva de 5.
DROP FUNCTION IF EXISTS public.tpv_cobrar_ticket(UUID, TEXT, TEXT, JSONB);

CREATE OR REPLACE FUNCTION public.tpv_cobrar_ticket(
  p_cliente_id UUID,
  p_metodo_pago TEXT,
  p_nota TEXT DEFAULT NULL,
  p_lineas JSONB DEFAULT '[]'::jsonb,
  p_vale_codigo TEXT DEFAULT NULL
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
  v_cobro_id UUID := gen_random_uuid();
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
  v_vale RECORD;
  v_vale_id UUID;
  v_vale_restante NUMERIC(12,2);
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  IF v_metodo NOT IN ('efectivo', 'tarjeta', 'transferencia', 'vale') THEN
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

  -- Validación del ticket regalo (saldo se comprueba al final con el total).
  IF v_metodo = 'vale' THEN
    IF p_vale_codigo IS NULL OR btrim(p_vale_codigo) = '' THEN
      RAISE EXCEPTION 'Introduce el código del ticket regalo.';
    END IF;
    SELECT * INTO v_vale
    FROM public.vales_regalo
    WHERE upper(codigo) = upper(btrim(p_vale_codigo));
    IF NOT FOUND THEN
      RAISE EXCEPTION 'El código del ticket regalo no existe.';
    END IF;
    IF v_vale.estado = 'anulado' THEN
      RAISE EXCEPTION 'Este ticket regalo fue anulado.';
    END IF;
    IF v_vale.estado = 'canjeado' OR v_vale.saldo <= 0 THEN
      RAISE EXCEPTION 'Este ticket regalo ya está agotado.';
    END IF;
    IF v_vale.valido_hasta < CURRENT_DATE THEN
      RAISE EXCEPTION 'Este ticket regalo ha caducado.';
    END IF;
    v_vale_id := v_vale.id;
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
        registrado_por, cobro_id, detalle, vale_regalo_id
      ) VALUES (
        p_cliente_id, NULL, NULL, v_importe, v_metodo, v_nota_linea, v_uid,
        v_cobro_id, v_detalle, v_vale_id
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
        registrado_por, cobro_id, detalle, vale_regalo_id
      ) VALUES (
        p_cliente_id, v_bono_id, v_tipo.id, v_importe, v_metodo, v_nota_global, v_uid,
        v_cobro_id, v_detalle, v_vale_id
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

  -- Aplicación del ticket regalo: saldo suficiente y descuento del saldo.
  IF v_metodo = 'vale' THEN
    IF v_total > v_vale.saldo THEN
      RAISE EXCEPTION 'Saldo del ticket regalo insuficiente: % € para un total de % €.',
        to_char(v_vale.saldo, 'FM999999990.00'), to_char(v_total, 'FM999999990.00');
    END IF;
    v_vale_restante := v_vale.saldo - v_total;
    UPDATE public.vales_regalo
    SET saldo = v_vale_restante,
        estado = CASE WHEN v_vale_restante <= 0 THEN 'canjeado' ELSE 'activo' END,
        canjeado_at = CASE WHEN v_vale_restante <= 0 THEN NOW() ELSE canjeado_at END
    WHERE id = v_vale_id;

    INSERT INTO public.vales_regalo_uso (vale_id, cobro_id, monto, usado_en, registrado_por)
    VALUES (v_vale_id, v_cobro_id, v_total, p_cliente_id, v_uid);
  END IF;

  IF v_metodo = 'vale' THEN
    RETURN jsonb_build_object(
      'ok', true,
      'cobro_id', v_cobro_id,
      'total', v_total,
      'metodo_pago', v_metodo,
      'lineas', to_jsonb(v_resumen),
      'num_lineas', jsonb_array_length(p_lineas),
      'transaccion_ids', to_jsonb(v_tx_ids),
      'vale_codigo', v_vale.codigo,
      'vale_restante', v_vale_restante
    );
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

GRANT EXECUTE ON FUNCTION public.tpv_cobrar_ticket(UUID, TEXT, TEXT, JSONB, TEXT) TO authenticated;

-- ───────────────────────────────────────────────
-- 6. RPC: consultar ticket regalo (para el TPV)
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.consultar_vale_regalo(p_codigo TEXT)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_vale RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;
  IF p_codigo IS NULL OR btrim(p_codigo) = '' THEN
    RAISE EXCEPTION 'Introduce el código del ticket regalo.';
  END IF;

  SELECT v.*, p.nombre AS cli_nombre, p.apellidos AS cli_apellidos, p.email AS cli_email
    INTO v_vale
  FROM public.vales_regalo v
  LEFT JOIN public.perfiles p ON p.id = v.cliente_id
  WHERE upper(v.codigo) = upper(btrim(p_codigo));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El código del ticket regalo no existe.';
  END IF;

  RETURN jsonb_build_object(
    'id', v_vale.id,
    'codigo', v_vale.codigo,
    'importe_original', v_vale.importe_original,
    'saldo', v_vale.saldo,
    'estado', v_vale.estado,
    'valido_hasta', v_vale.valido_hasta,
    'caducado', v_vale.valido_hasta < CURRENT_DATE,
    'cliente', btrim(coalesce(v_vale.cli_nombre, '') || ' ' || coalesce(v_vale.cli_apellidos, '')),
    'cliente_email', v_vale.cli_email
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.consultar_vale_regalo(TEXT) TO authenticated;

-- ───────────────────────────────────────────────
-- 7. RPC: anular ticket regalo
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.anular_vale_regalo(p_vale_id UUID, p_motivo TEXT DEFAULT NULL)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_vale RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT * INTO v_vale FROM public.vales_regalo WHERE id = p_vale_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Ticket regalo no encontrado.';
  END IF;
  IF v_vale.estado = 'anulado' THEN
    RAISE EXCEPTION 'El ticket regalo ya está anulado.';
  END IF;
  IF v_vale.estado = 'canjeado' THEN
    RAISE EXCEPTION 'El ticket regalo ya está agotado y no puede anularse.';
  END IF;

  UPDATE public.vales_regalo
  SET estado = 'anulado',
      anulado_at = NOW(),
      anulado_por = v_uid,
      motivo_anulacion = coalesce(nullif(trim(coalesce(p_motivo, '')), ''), 'Anulado por el staff')
  WHERE id = p_vale_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.anular_vale_regalo(UUID, TEXT) TO authenticated;

-- ───────────────────────────────────────────────
-- 8. RPC: devolver cobro (efectivo o ticket regalo)
-- ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.devolver_cobro(
  p_cobro_id UUID,
  p_metodo_reembolso TEXT,
  p_motivo TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  v_metodo TEXT := lower(btrim(coalesce(p_metodo_reembolso, '')));
  v_motivo TEXT := nullif(btrim(coalesce(p_motivo, '')), '');
  v_total NUMERIC(12,2) := 0;
  v_perfil_id UUID;
  v_registrado_por UUID;
  v_factura RECORD;
  v_devolucion_id UUID;
  v_vale_id UUID;
  v_codigo TEXT;
  v_part TEXT;
  v_nota TEXT;
  r RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  IF v_metodo NOT IN ('efectivo', 'vale') THEN
    RAISE EXCEPTION 'Método de reembolso no válido (usa efectivo o vale).';
  END IF;
  IF p_cobro_id IS NULL THEN
    RAISE EXCEPTION 'Falta el identificador del cobro.';
  END IF;

  -- Serializa por cobro para evitar dobles devoluciones simultáneas.
  PERFORM pg_advisory_xact_lock(hashtext('nova_devolucion_' || p_cobro_id::text));

  IF EXISTS (SELECT 1 FROM public.devoluciones WHERE cobro_id = p_cobro_id) THEN
    RAISE EXCEPTION 'Este cobro ya fue devuelto.';
  END IF;

  SELECT COALESCE(SUM(importe), 0), MIN(perfil_id), MIN(registrado_por)
    INTO v_total, v_perfil_id, v_registrado_por
  FROM public.transacciones
  WHERE cobro_id = p_cobro_id
    AND tipo_movimiento = 'venta';

  IF v_total IS NULL OR v_total <= 0 THEN
    RAISE EXCEPTION 'Cobro no encontrado o sin importe que devolver.';
  END IF;

  IF v_rol = 'empleado' AND v_registrado_por IS DISTINCT FROM v_uid THEN
    RAISE EXCEPTION 'Solo puedes devolver cobros que registraste tú.';
  END IF;

  -- Bonos del cobro: sin sesiones usadas ni reservas activas; se desactivan.
  FOR r IN
    SELECT DISTINCT bono_activo_id
    FROM public.transacciones
    WHERE cobro_id = p_cobro_id
      AND bono_activo_id IS NOT NULL
  LOOP
    IF EXISTS (
      SELECT 1 FROM public.bonos_activos b
      WHERE b.id = r.bono_activo_id
        AND COALESCE(b.sesiones_usadas, 0) > 0
    ) THEN
      RAISE EXCEPTION 'No se puede devolver: el bono ya tiene sesiones usadas.';
    END IF;
    IF EXISTS (
      SELECT 1 FROM public.reservas z
      WHERE z.bono_activo_id = r.bono_activo_id
        AND z.estado IS DISTINCT FROM 'cancelada'
    ) THEN
      RAISE EXCEPTION 'No se puede devolver: hay reservas activas ligadas al bono.';
    END IF;
    UPDATE public.bonos_activos SET activo = FALSE WHERE id = r.bono_activo_id;
  END LOOP;

  -- La factura del cobro queda anulada automáticamente.
  SELECT * INTO v_factura
  FROM public.facturas
  WHERE cobro_id = p_cobro_id
    AND estado = 'emitida';
  IF FOUND THEN
    UPDATE public.facturas
    SET estado = 'anulada',
        motivo_anulacion = 'Factura anulada por devolución',
        anulada_por = v_uid,
        anulada_at = NOW()
    WHERE id = v_factura.id;
  END IF;

  v_nota := 'Devolución'
    || CASE WHEN v_motivo IS NOT NULL THEN ' · ' || v_motivo ELSE '' END;

  IF v_metodo = 'vale' THEN
    -- Código único legible: NV-XXXX-XXXX (sin caracteres ambiguos).
    LOOP
      v_part := (
        SELECT string_agg(substr('ABCDEFGHJKLMNPQRSTUVWXYZ23456789', floor(random() * 32)::int + 1, 1), '')
        FROM generate_series(1, 4)
      );
      v_codigo := 'NV-' || v_part || '-' || v_part;
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.vales_regalo WHERE codigo = v_codigo);
    END LOOP;

    INSERT INTO public.devoluciones (cobro_id, factura_id, importe_total, metodo_reembolso, motivo, registrado_por)
    VALUES (p_cobro_id, v_factura.id, v_total, 'vale', v_motivo, v_uid)
    RETURNING id INTO v_devolucion_id;

    INSERT INTO public.vales_regalo (
      codigo, importe_original, saldo, estado, cliente_id, emitido_por,
      devolucion_id, motivo, valido_hasta
    ) VALUES (
      v_codigo, v_total, v_total, 'activo', v_perfil_id, v_uid,
      v_devolucion_id, v_motivo, CURRENT_DATE + 180
    )
    RETURNING id INTO v_vale_id;

    UPDATE public.devoluciones SET vale_regalo_id = v_vale_id WHERE id = v_devolucion_id;

    INSERT INTO public.transacciones (
      perfil_id, importe, metodo_pago, nota, registrado_por,
      tipo_movimiento, devolucion_id
    ) VALUES (
      v_perfil_id, -v_total, 'vale',
      v_nota || ' · Ticket regalo ' || v_codigo,
      v_uid, 'reembolso', v_devolucion_id
    );

    RETURN jsonb_build_object(
      'ok', true,
      'devolucion_id', v_devolucion_id,
      'importe', v_total,
      'metodo', 'vale',
      'vale', jsonb_build_object(
        'id', v_vale_id,
        'codigo', v_codigo,
        'saldo', v_total,
        'valido_hasta', (CURRENT_DATE + 180)::text
      )
    );
  END IF;

  INSERT INTO public.devoluciones (cobro_id, factura_id, importe_total, metodo_reembolso, motivo, registrado_por)
  VALUES (p_cobro_id, v_factura.id, v_total, 'efectivo', v_motivo, v_uid)
  RETURNING id INTO v_devolucion_id;

  INSERT INTO public.transacciones (
    perfil_id, importe, metodo_pago, nota, registrado_por,
    tipo_movimiento, devolucion_id
  ) VALUES (
    v_perfil_id, -v_total, 'efectivo', v_nota, v_uid, 'reembolso', v_devolucion_id
  );

  RETURN jsonb_build_object(
    'ok', true,
    'devolucion_id', v_devolucion_id,
    'importe', v_total,
    'metodo', 'efectivo',
    'vale', null
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.devolver_cobro(UUID, TEXT, TEXT) TO authenticated;

-- ───────────────────────────────────────────────
-- 9. Guardas en facturar_cobro y anular_transaccion_tpv
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

  IF EXISTS (SELECT 1 FROM public.devoluciones WHERE cobro_id = p_cobro_id) THEN
    RAISE EXCEPTION 'No se puede facturar un cobro devuelto.';
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
      AND tipo_movimiento = 'venta'
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
      AND t.tipo_movimiento = 'venta'
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

  IF r.tipo_movimiento = 'reembolso' OR r.devolucion_id IS NOT NULL THEN
    RAISE EXCEPTION 'No se puede anular un reembolso.';
  END IF;

  IF r.cobro_id IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.devoluciones d WHERE d.cobro_id = r.cobro_id
  ) THEN
    RAISE EXCEPTION 'Este cobro ya fue devuelto; usa el registro de devoluciones.';
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
