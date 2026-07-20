-- Cobro TPV atómico (todo el ticket o nada).
-- - Valida staff (empleado/admin) y cliente.
-- - Como máximo 1 bono por ticket; desactiva bonos activos previos al asignar el nuevo.
-- - Precios desde catálogo (tipos_bono / productos_tienda), no confía en el cliente.
-- Ejecutar en Supabase → SQL Editor.

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
  v_fecha_inicio DATE := CURRENT_DATE;
  v_fecha_fin DATE;
  v_dias INT;
  v_nota_linea TEXT;
  v_nota_global TEXT := nullif(trim(coalesce(p_nota, '')), '');
  v_total NUMERIC(10,2) := 0;
  v_resumen TEXT[] := ARRAY[]::TEXT[];
  v_line_label TEXT;
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

  -- Pre-chequeo: máximo un bono
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

      INSERT INTO public.transacciones (
        perfil_id, bono_activo_id, tipo_bono_id, importe, metodo_pago, nota, registrado_por
      ) VALUES (
        p_cliente_id, NULL, NULL, v_importe, v_metodo, v_nota_linea, v_uid
      );

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

      INSERT INTO public.transacciones (
        perfil_id, bono_activo_id, tipo_bono_id, importe, metodo_pago, nota, registrado_por
      ) VALUES (
        p_cliente_id, v_bono_id, v_tipo.id, v_importe, v_metodo, v_nota_global, v_uid
      );

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
    'total', v_total,
    'metodo_pago', v_metodo,
    'lineas', to_jsonb(v_resumen),
    'num_lineas', jsonb_array_length(p_lineas)
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.tpv_cobrar_ticket(UUID, TEXT, TEXT, JSONB) TO authenticated;
