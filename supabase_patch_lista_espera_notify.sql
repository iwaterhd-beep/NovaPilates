-- PARCHE: refuerzo de notificación al promover desde lista de espera
-- Idempotente: redefine cancelar_reserva_segura con notificación clara al usuario promovido.
-- Ejecutar en Supabase SQL Editor después de supabase_patch_lista_espera.sql (o junto a él).

CREATE OR REPLACE FUNCTION public.cancelar_reserva_segura(p_reserva_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reserva RECORD;
  v_margen_cancelacion_dias INTEGER := 0;
  v_wait RECORD;
  v_bono_wait RECORD;
  v_clase_titulo TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT r.id, r.estado, r.bono_activo_id, r.lista_espera, r.clase_id, c.fecha_hora, c.titulo
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

  -- Si se libera una plaza (cancelación de reserva sentada), promover al primero en espera
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

        v_clase_titulo := COALESCE(NULLIF(v_reserva.titulo, ''), 'tu clase');

        INSERT INTO public.notificaciones (perfil_id, titulo, mensaje, tipo)
        VALUES (
          v_wait.perfil_id,
          'Plaza confirmada',
          'Se ha liberado una plaza en ' || v_clase_titulo ||
          '. Tu reserva en lista de espera ya está confirmada. ¡Te esperamos!',
          'success'
        );

        -- Reordenar posiciones de quien sigue en espera
        WITH ordered AS (
          SELECT id, ROW_NUMBER() OVER (ORDER BY posicion_espera ASC NULLS LAST, fecha_reserva ASC) AS new_pos
          FROM public.reservas
          WHERE clase_id = v_reserva.clase_id
            AND estado = 'confirmada'
            AND COALESCE(lista_espera, FALSE) = TRUE
        )
        UPDATE public.reservas r
        SET posicion_espera = ordered.new_pos
        FROM ordered
        WHERE r.id = ordered.id;
      END IF;
    END IF;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
