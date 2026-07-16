-- PARCHE: margen de días para reservar/cancelar
-- Ejecuta este archivo en Supabase SQL Editor (una sola vez).

CREATE TABLE IF NOT EXISTS public.ajustes_centro (
  id                       INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  margen_reserva_dias      INTEGER NOT NULL DEFAULT 0 CHECK (margen_reserva_dias >= 0),
  margen_cancelacion_dias  INTEGER NOT NULL DEFAULT 0 CHECK (margen_cancelacion_dias >= 0),
  updated_by               UUID REFERENCES public.perfiles(id),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.ajustes_centro (id, margen_reserva_dias, margen_cancelacion_dias)
VALUES (1, 0, 0)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE public.ajustes_centro ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT AS $$
  SELECT rol::TEXT FROM public.perfiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

DROP POLICY IF EXISTS "Usuarios autenticados leen ajustes" ON public.ajustes_centro;
CREATE POLICY "Usuarios autenticados leen ajustes" ON public.ajustes_centro
  FOR SELECT USING (auth.uid() IS NOT NULL);

DROP POLICY IF EXISTS "Admin actualiza ajustes" ON public.ajustes_centro;
CREATE POLICY "Admin actualiza ajustes" ON public.ajustes_centro
  FOR UPDATE USING (mi_rol() = 'admin');

CREATE OR REPLACE FUNCTION public.crear_reserva_segura(p_clase_id UUID)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_clase RECORD;
  v_bono RECORD;
  v_reserva_id UUID;
  v_ocupacion INTEGER;
  v_margen_reserva_dias INTEGER := 0;
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

  SELECT COUNT(*)::INTEGER
  INTO v_ocupacion
  FROM public.reservas
  WHERE clase_id = p_clase_id
    AND estado IN ('confirmada', 'asistida');

  IF v_ocupacion >= v_clase.aforo_max THEN
    RAISE EXCEPTION 'No hay plazas disponibles.';
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.reservas
    WHERE perfil_id = v_user_id
      AND clase_id = p_clase_id
      AND estado IN ('confirmada', 'asistida')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una reserva activa para esta clase.';
  END IF;

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

  INSERT INTO public.reservas (perfil_id, clase_id, bono_activo_id, estado)
  VALUES (v_user_id, p_clase_id, v_bono.id, 'confirmada')
  RETURNING id INTO v_reserva_id;

  UPDATE public.bonos_activos
  SET sesiones_usadas = sesiones_usadas + 1
  WHERE id = v_bono.id;

  RETURN v_reserva_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancelar_reserva_segura(p_reserva_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reserva RECORD;
  v_margen_cancelacion_dias INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT r.id, r.estado, r.bono_activo_id, c.fecha_hora
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

  SELECT margen_cancelacion_dias
  INTO v_margen_cancelacion_dias
  FROM public.ajustes_centro
  WHERE id = 1;

  IF COALESCE(v_margen_cancelacion_dias, 0) > 0
    AND v_reserva.fecha_hora < NOW() + make_interval(days => v_margen_cancelacion_dias) THEN
    RAISE EXCEPTION 'No se puede cancelar con menos de % días de antelación.', v_margen_cancelacion_dias;
  END IF;

  UPDATE public.reservas
  SET estado = 'cancelada',
      fecha_cancelacion = NOW()
  WHERE id = p_reserva_id;

  IF v_reserva.bono_activo_id IS NOT NULL THEN
    UPDATE public.bonos_activos
    SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
    WHERE id = v_reserva.bono_activo_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
