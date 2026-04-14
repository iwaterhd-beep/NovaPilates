-- PARCHE: marcar_asistencia compatible con enum no_asistio/no_asistida
-- Ejecuta este script en Supabase SQL Editor.

CREATE OR REPLACE FUNCTION public.marcar_asistencia(p_reserva_id UUID, p_asistio BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_estado estado_reserva;
BEGIN
  IF p_asistio THEN
    v_estado := 'asistida'::estado_reserva;
  ELSE
    IF EXISTS (
      SELECT 1
      FROM pg_type t
      JOIN pg_enum e ON e.enumtypid = t.oid
      WHERE t.typname = 'estado_reserva'
        AND e.enumlabel = 'no_asistio'
    ) THEN
      v_estado := 'no_asistio'::estado_reserva;
    ELSE
      v_estado := 'no_asistida'::estado_reserva;
    END IF;
  END IF;

  UPDATE public.reservas
  SET estado = v_estado
  WHERE id = p_reserva_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
