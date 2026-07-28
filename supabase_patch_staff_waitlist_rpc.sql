-- PARCHE: centraliza en SQL la gestión staff de la lista de espera
-- Ejecutar después de supabase_patch_lista_espera.sql

CREATE OR REPLACE FUNCTION public.staff_reordenar_lista_espera(
  p_clase_id UUID,
  p_reserva_ids UUID[]
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'Solo staff puede reordenar la lista de espera.';
  END IF;
  IF p_clase_id IS NULL OR p_reserva_ids IS NULL OR COALESCE(array_length(p_reserva_ids, 1), 0) = 0 THEN
    RAISE EXCEPTION 'Datos de lista de espera no válidos.';
  END IF;

  IF (
    SELECT COUNT(*)
    FROM public.reservas
    WHERE clase_id = p_clase_id
      AND estado = 'confirmada'
      AND COALESCE(lista_espera, FALSE) = TRUE
  ) <> array_length(p_reserva_ids, 1) THEN
    RAISE EXCEPTION 'La lista de espera ha cambiado. Recarga antes de guardar el nuevo orden.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM unnest(p_reserva_ids) AS x(id)
    LEFT JOIN public.reservas r ON r.id = x.id
    WHERE r.id IS NULL
       OR r.clase_id <> p_clase_id
       OR r.estado <> 'confirmada'
       OR COALESCE(r.lista_espera, FALSE) <> TRUE
  ) THEN
    RAISE EXCEPTION 'El orden incluye reservas no válidas para esta clase.';
  END IF;

  WITH ordered AS (
    SELECT id, ord::INTEGER AS new_pos
    FROM unnest(p_reserva_ids) WITH ORDINALITY AS u(id, ord)
  )
  UPDATE public.reservas r
  SET posicion_espera = ordered.new_pos
  FROM ordered
  WHERE r.id = ordered.id;
END;
$$;

REVOKE ALL ON FUNCTION public.staff_reordenar_lista_espera(UUID, UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_reordenar_lista_espera(UUID, UUID[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.staff_reordenar_lista_espera(UUID, UUID[]) TO authenticated;

CREATE OR REPLACE FUNCTION public.staff_promover_reserva_espera(p_reserva_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_reserva RECORD;
  v_bono RECORD;
  v_ocupacion INTEGER;
  v_titulo TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'Solo staff puede promover reservas.';
  END IF;

  SELECT r.id, r.perfil_id, r.clase_id, r.estado, r.lista_espera, c.aforo_max, c.titulo
  INTO v_reserva
  FROM public.reservas r
  JOIN public.clases c ON c.id = r.clase_id
  WHERE r.id = p_reserva_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva no encontrada.';
  END IF;
  IF v_reserva.estado <> 'confirmada' OR COALESCE(v_reserva.lista_espera, FALSE) <> TRUE THEN
    RAISE EXCEPTION 'La reserva ya no está en lista de espera.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_ocupacion
  FROM public.reservas
  WHERE clase_id = v_reserva.clase_id
    AND estado IN ('confirmada', 'asistida')
    AND COALESCE(lista_espera, FALSE) = FALSE;

  IF v_ocupacion >= COALESCE(v_reserva.aforo_max, 0) THEN
    RAISE EXCEPTION 'No hay plaza libre para promover ahora.';
  END IF;

  SELECT id, sesiones_totales, sesiones_usadas
  INTO v_bono
  FROM public.bonos_activos
  WHERE perfil_id = v_reserva.perfil_id
    AND activo = TRUE
    AND fecha_fin >= CURRENT_DATE
  ORDER BY fecha_inicio DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'El cliente no tiene bono activo.';
  END IF;
  IF v_bono.sesiones_totales IS NOT NULL AND v_bono.sesiones_usadas >= v_bono.sesiones_totales THEN
    RAISE EXCEPTION 'El cliente no tiene sesiones disponibles.';
  END IF;

  UPDATE public.reservas
  SET lista_espera = FALSE,
      posicion_espera = NULL,
      bono_activo_id = v_bono.id
  WHERE id = p_reserva_id;

  UPDATE public.bonos_activos
  SET sesiones_usadas = sesiones_usadas + 1
  WHERE id = v_bono.id;

  v_titulo := COALESCE(NULLIF(v_reserva.titulo, ''), 'tu clase');

  INSERT INTO public.notificaciones (perfil_id, titulo, mensaje, tipo, enviada_por)
  VALUES (
    v_reserva.perfil_id,
    'Plaza confirmada',
    'Se ha liberado una plaza en ' || v_titulo || '. Tu reserva en lista de espera ya está confirmada.',
    'success',
    auth.uid()
  );

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
END;
$$;

REVOKE ALL ON FUNCTION public.staff_promover_reserva_espera(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_promover_reserva_espera(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.staff_promover_reserva_espera(UUID) TO authenticated;

CREATE OR REPLACE FUNCTION public.staff_cancelar_reserva_espera(p_reserva_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_clase_id UUID;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'Solo staff puede quitar reservas en espera.';
  END IF;

  SELECT clase_id
  INTO v_clase_id
  FROM public.reservas
  WHERE id = p_reserva_id
    AND estado = 'confirmada'
    AND COALESCE(lista_espera, FALSE) = TRUE
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La reserva ya no está en lista de espera.';
  END IF;

  UPDATE public.reservas
  SET estado = 'cancelada',
      fecha_cancelacion = NOW()
  WHERE id = p_reserva_id;

  WITH ordered AS (
    SELECT id, ROW_NUMBER() OVER (ORDER BY posicion_espera ASC NULLS LAST, fecha_reserva ASC) AS new_pos
    FROM public.reservas
    WHERE clase_id = v_clase_id
      AND estado = 'confirmada'
      AND COALESCE(lista_espera, FALSE) = TRUE
  )
  UPDATE public.reservas r
  SET posicion_espera = ordered.new_pos
  FROM ordered
  WHERE r.id = ordered.id;
END;
$$;

REVOKE ALL ON FUNCTION public.staff_cancelar_reserva_espera(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.staff_cancelar_reserva_espera(UUID) FROM anon;
GRANT EXECUTE ON FUNCTION public.staff_cancelar_reserva_espera(UUID) TO authenticated;
