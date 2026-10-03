-- Cuenta plazas ocupadas por clase para el cliente (sin exponer quién está apuntado).
-- Ejecutar en Supabase → SQL Editor.

CREATE OR REPLACE FUNCTION public.ocupacion_clases(p_clase_ids UUID[])
RETURNS TABLE(clase_id UUID, ocupadas INTEGER)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT r.clase_id, COUNT(*)::INTEGER AS ocupadas
  FROM public.reservas r
  WHERE p_clase_ids IS NOT NULL
    AND r.clase_id = ANY (p_clase_ids)
    AND r.estado IN ('confirmada', 'asistida')
    AND COALESCE(r.lista_espera, FALSE) = FALSE
  GROUP BY r.clase_id;
$$;

REVOKE ALL ON FUNCTION public.ocupacion_clases(UUID[]) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.ocupacion_clases(UUID[]) FROM anon;
GRANT EXECUTE ON FUNCTION public.ocupacion_clases(UUID[]) TO authenticated;
