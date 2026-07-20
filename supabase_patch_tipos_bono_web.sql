-- Bonos visibles en la web + planes NŌVA FLOW en TPV.
-- Ejecutar en Supabase → SQL Editor.

ALTER TABLE public.tipos_bono
  ADD COLUMN IF NOT EXISTS visible_web BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN IF NOT EXISTS web_tag TEXT,
  ADD COLUMN IF NOT EXISTS web_meta TEXT;

COMMENT ON COLUMN public.tipos_bono.visible_web IS 'Si true, se muestra en la sección Planes de la página principal.';
COMMENT ON COLUMN public.tipos_bono.web_tag IS 'Etiqueta corta en portada (ej. FLOW 01, Primera experiencia).';
COMMENT ON COLUMN public.tipos_bono.web_meta IS 'Línea meta en portada (ej. 2 días / semana).';

DROP POLICY IF EXISTS "Publico lee bonos web" ON public.tipos_bono;
CREATE POLICY "Publico lee bonos web" ON public.tipos_bono
  FOR SELECT
  TO anon, authenticated
  USING (visible_web = TRUE AND activo = TRUE);

-- Actualiza si ya existen por nombre
UPDATE public.tipos_bono SET
  descripcion = 'Descubre la experiencia NŌVA antes de elegir tu plan. Disponible una única vez por persona.',
  sesiones = 1, ilimitado = FALSE, periodicidad = 'mensual', duracion_dias = 14, precio = 25.00,
  activo = TRUE, orden = 10, visible_web = TRUE, web_tag = 'Primera experiencia', web_meta = NULL
WHERE nombre = 'Clase de prueba';

UPDATE public.tipos_bono SET
  descripcion = 'Ideal para comenzar y crear una rutina constante con la flexibilidad que necesitas.',
  sesiones = 8, ilimitado = FALSE, periodicidad = 'mensual', duracion_dias = 30, precio = 145.00,
  activo = TRUE, orden = 20, visible_web = TRUE, web_tag = 'Flow 01', web_meta = '2 días / semana'
WHERE nombre = 'NŌVA FLOW';

UPDATE public.tipos_bono SET
  descripcion = 'El equilibrio perfecto entre compromiso, progreso y tiempo para ti.',
  sesiones = 12, ilimitado = FALSE, periodicidad = 'mensual', duracion_dias = 30, precio = 185.00,
  activo = TRUE, orden = 30, visible_web = TRUE, web_tag = 'Flow 02', web_meta = '3 días / semana'
WHERE nombre = 'NŌVA BALANCE';

UPDATE public.tipos_bono SET
  descripcion = 'La experiencia más completa para integrar el movimiento en tu estilo de vida.',
  sesiones = 20, ilimitado = FALSE, periodicidad = 'mensual', duracion_dias = 30, precio = 225.00,
  activo = TRUE, orden = 40, visible_web = TRUE, web_tag = 'Flow 03', web_meta = '5 días / semana'
WHERE nombre = 'NŌVA SIGNATURE';

-- Inserta solo si no existe ese nombre
INSERT INTO public.tipos_bono (
  nombre, descripcion, sesiones, ilimitado, periodicidad, duracion_dias, precio,
  activo, orden, color_hex, visible_web, web_tag, web_meta
)
SELECT
  v.nombre, v.descripcion, v.sesiones, v.ilimitado, v.periodicidad::public.periodicidad_bono,
  v.duracion_dias, v.precio, v.activo, v.orden, v.color_hex, v.visible_web, v.web_tag, v.web_meta
FROM (VALUES
  ('Clase de prueba'::text, 'Descubre la experiencia NŌVA antes de elegir tu plan. Disponible una única vez por persona.'::text, 1, false, 'mensual'::text, 14, 25.00::numeric, true, 10, '#c9a96e'::text, true, 'Primera experiencia'::text, NULL::text),
  ('NŌVA FLOW', 'Ideal para comenzar y crear una rutina constante con la flexibilidad que necesitas.', 8, false, 'mensual', 30, 145.00, true, 20, '#8a9a8c', true, 'Flow 01', '2 días / semana'),
  ('NŌVA BALANCE', 'El equilibrio perfecto entre compromiso, progreso y tiempo para ti.', 12, false, 'mensual', 30, 185.00, true, 30, '#8a9a8c', true, 'Flow 02', '3 días / semana'),
  ('NŌVA SIGNATURE', 'La experiencia más completa para integrar el movimiento en tu estilo de vida.', 20, false, 'mensual', 30, 225.00, true, 40, '#6f7e70', true, 'Flow 03', '5 días / semana')
) AS v(nombre, descripcion, sesiones, ilimitado, periodicidad, duracion_dias, precio, activo, orden, color_hex, visible_web, web_tag, web_meta)
WHERE NOT EXISTS (
  SELECT 1 FROM public.tipos_bono t WHERE t.nombre = v.nombre
);
