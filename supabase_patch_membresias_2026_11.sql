-- Catálogo TPV alineado con Morning / Essential / Priority (nov 2026).

UPDATE public.tipos_bono
SET visible_web = false
WHERE nombre IN (
  'Clase de prueba',
  'NŌVA BALANCE',
  'NŌVA FLOW',
  'NŌVA MOVE',
  'NŌVA SIGNATURE',
  'CLASE DE PRUEBA'
);

INSERT INTO public.tipos_bono (
  nombre, descripcion, sesiones, ilimitado, periodicidad, duracion_dias, precio,
  activo, orden, color_hex, visible_web, web_tag, web_meta
)
VALUES (
  'NŌVA MORNING',
  '20 clases por ciclo (hasta 5 por semana). Horario de mañana de 8:00 a 12:00 h. Última clase a las 11:00 h. Vigencia 28 días. Sin permanencia.',
  20, false, 'mensual', 28, 84.00, true, 10, '#A3968D', true,
  'HORARIO DE MAÑANA', '20 clases · hasta 5/semana · 8:00–11:00'
)
ON CONFLICT (nombre) DO UPDATE SET
  descripcion = EXCLUDED.descripcion,
  sesiones = EXCLUDED.sesiones,
  ilimitado = false,
  duracion_dias = 28,
  precio = 84.00,
  activo = true,
  orden = 10,
  visible_web = true,
  web_tag = EXCLUDED.web_tag,
  web_meta = EXCLUDED.web_meta;

UPDATE public.tipos_bono SET
  descripcion = '8 clases por ciclo (2 por semana). Sin restricción de horarios. Acceso a las diferentes disciplinas. Vigencia 28 días. Sin permanencia.',
  sesiones = 8,
  ilimitado = false,
  duracion_dias = 28,
  precio = 99.00,
  activo = true,
  orden = 20,
  visible_web = true,
  web_tag = '8 CLASES',
  web_meta = '8 clases · 2/semana · todo el horario'
WHERE nombre = 'NŌVA ESSENTIAL';

UPDATE public.tipos_bono SET
  descripcion = '20 clases por ciclo (hasta 5 por semana). Sin restricción de horarios. Acceso a todas las disciplinas. Experiencia NŌVA completa. Vigencia 28 días. Sin permanencia.',
  sesiones = 20,
  ilimitado = false,
  duracion_dias = 28,
  precio = 147.00,
  activo = true,
  orden = 30,
  visible_web = true,
  web_tag = 'EXPERIENCIA COMPLETA',
  web_meta = '20 clases · hasta 5/semana · beneficios exclusivos'
WHERE nombre ILIKE '%priority%';
