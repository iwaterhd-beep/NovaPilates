-- PARCHE: lista de espera con promoción automática
-- Ejecutar en Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.crear_reserva_segura(p_clase_id UUID)
RETURNS JSONB AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_clase RECORD;
  v_bono RECORD;
  v_reserva_id UUID;
  v_ocupacion INTEGER;
  v_margen_reserva_dias INTEGER := 0;
  v_pos_espera INTEGER := 0;
  v_en_espera BOOLEAN := FALSE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT id, aforo_max, cancelada, fecha_hora
  INTO v_clase
  FROM public.clases
  WHERE id = p_clase_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La clase no existe.';
  END IF;
  IF v_clase.cancelada THEN
    RAISE EXCEPTION 'La clase está cancelada.';
  END IF;
  IF v_clase.fecha_hora <= NOW() THEN
    RAISE EXCEPTION 'No se puede reservar una clase pasada.';
  END IF;

  SELECT margen_reserva_dias
  INTO v_margen_reserva_dias
  FROM public.ajustes_centro
  WHERE id = 1;

  IF COALESCE(v_margen_reserva_dias, 0) > 0
    AND v_clase.fecha_hora < NOW() + make_interval(days => v_margen_reserva_dias) THEN
    RAISE EXCEPTION 'Debes reservar con al menos % días de antelación.', v_margen_reserva_dias;
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.reservas
    WHERE perfil_id = v_user_id
      AND clase_id = p_clase_id
      AND estado IN ('confirmada', 'asistida')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una reserva activa para esta clase.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_ocupacion
  FROM public.reservas
  WHERE clase_id = p_clase_id
    AND estado IN ('confirmada', 'asistida')
    AND COALESCE(lista_espera, FALSE) = FALSE;

  IF v_ocupacion >= v_clase.aforo_max THEN
    SELECT COALESCE(MAX(posicion_espera), 0) + 1
    INTO v_pos_espera
    FROM public.reservas
    WHERE clase_id = p_clase_id
      AND estado = 'confirmada'
      AND COALESCE(lista_espera, FALSE) = TRUE;

    INSERT INTO public.reservas (perfil_id, clase_id, estado, lista_espera, posicion_espera)
    VALUES (v_user_id, p_clase_id, 'confirmada', TRUE, v_pos_espera)
    RETURNING id INTO v_reserva_id;

    v_en_espera := TRUE;
  ELSE
    SELECT id, sesiones_totales, sesiones_usadas
    INTO v_bono
    FROM public.bonos_activos
    WHERE perfil_id = v_user_id
      AND activo = TRUE
      AND fecha_fin >= CURRENT_DATE
    ORDER BY fecha_inicio DESC
    LIMIT 1
    FOR UPDATE;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'No tienes bono activo.';
    END IF;
    IF v_bono.sesiones_totales IS NOT NULL AND v_bono.sesiones_usadas >= v_bono.sesiones_totales THEN
      RAISE EXCEPTION 'No tienes sesiones disponibles en tu bono.';
    END IF;

    INSERT INTO public.reservas (perfil_id, clase_id, bono_activo_id, estado, lista_espera, posicion_espera)
    VALUES (v_user_id, p_clase_id, v_bono.id, 'confirmada', FALSE, NULL)
    RETURNING id INTO v_reserva_id;

    UPDATE public.bonos_activos
    SET sesiones_usadas = sesiones_usadas + 1
    WHERE id = v_bono.id;
  END IF;

  RETURN jsonb_build_object(
    'reserva_id', v_reserva_id,
    'en_espera', v_en_espera,
    'posicion_espera', CASE WHEN v_en_espera THEN v_pos_espera ELSE NULL END
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancelar_reserva_segura(p_reserva_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reserva RECORD;
  v_margen_cancelacion_dias INTEGER := 0;
  v_wait RECORD;
  v_bono_wait RECORD;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT r.id, r.estado, r.bono_activo_id, r.lista_espera, r.clase_id, c.fecha_hora
  INTO v_reserva
  FROM public.reservas r
  JOIN public.clases c ON c.id = r.clase_id
  WHERE r.id = p_reserva_id
    AND r.perfil_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva no encontrada.';
  END IF;

  IF v_reserva.estado = 'cancelada' THEN
    RETURN;
  END IF;

  IF COALESCE(v_reserva.lista_espera, FALSE) = FALSE THEN
    SELECT margen_cancelacion_dias
    INTO v_margen_cancelacion_dias
    FROM public.ajustes_centro
    WHERE id = 1;

    IF COALESCE(v_margen_cancelacion_dias, 0) > 0
      AND v_reserva.fecha_hora < NOW() + make_interval(days => v_margen_cancelacion_dias) THEN
      RAISE EXCEPTION 'No se puede cancelar con menos de % días de antelación.', v_margen_cancelacion_dias;
    END IF;
  END IF;

  UPDATE public.reservas
  SET estado = 'cancelada',
      fecha_cancelacion = NOW()
  WHERE id = p_reserva_id;

  IF COALESCE(v_reserva.lista_espera, FALSE) = FALSE AND v_reserva.bono_activo_id IS NOT NULL THEN
    UPDATE public.bonos_activos
    SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
    WHERE id = v_reserva.bono_activo_id;
  END IF;

  IF COALESCE(v_reserva.lista_espera, FALSE) = FALSE THEN
    SELECT *
    INTO v_wait
    FROM public.reservas
    WHERE clase_id = v_reserva.clase_id
      AND estado = 'confirmada'
      AND COALESCE(lista_espera, FALSE) = TRUE
    ORDER BY posicion_espera ASC NULLS LAST, fecha_reserva ASC
    LIMIT 1
    FOR UPDATE;

    IF FOUND THEN
      SELECT id, sesiones_totales, sesiones_usadas
      INTO v_bono_wait
      FROM public.bonos_activos
      WHERE perfil_id = v_wait.perfil_id
        AND activo = TRUE
        AND fecha_fin >= CURRENT_DATE
      ORDER BY fecha_inicio DESC
      LIMIT 1
      FOR UPDATE;

      IF FOUND AND (v_bono_wait.sesiones_totales IS NULL OR v_bono_wait.sesiones_usadas < v_bono_wait.sesiones_totales) THEN
        UPDATE public.reservas
        SET lista_espera = FALSE,
            posicion_espera = NULL,
            bono_activo_id = v_bono_wait.id
        WHERE id = v_wait.id;

        UPDATE public.bonos_activos
        SET sesiones_usadas = sesiones_usadas + 1
        WHERE id = v_bono_wait.id;

        INSERT INTO public.notificaciones (perfil_id, titulo, mensaje, tipo)
        VALUES (
          v_wait.perfil_id,
          '¡Tienes plaza confirmada!',
          'Se ha liberado una plaza y tu reserva en lista de espera ha pasado a confirmada.',
          'aviso'
        );
      END IF;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
