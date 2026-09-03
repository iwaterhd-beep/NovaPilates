-- ==========================================================
-- NŌVA PILATES STUDIO — Membresías oficiales (septiembre 2026)
-- Ejecutar en Supabase → SQL Editor
-- ==========================================================

CREATE UNIQUE INDEX IF NOT EXISTS tipos_bono_nombre_key ON public.tipos_bono (nombre);

-- Ocultar planes anteriores de la web
UPDATE public.tipos_bono
SET visible_web = false, activo = false
WHERE nombre IN (
  'CLASE DE PRUEBA',
  'NOVA FLOW',
  'NOVA BALANCE',
  'NOVA SIGNATURE',
  'NŌVA MOVE',
  'NŌVA ACTIVE',
  'PRIORITY MEMBER'
);

INSERT INTO public.tipos_bono (
  nombre, descripcion, sesiones, ilimitado, periodicidad, duracion_dias, precio,
  activo, orden, color_hex, visible_web, web_tag, web_meta
)
VALUES
  (
    'NŌVA ESSENTIAL',
    '2 días a la semana en horario limitado. Incluye Yoga, Pilates suelo, Barre y Sculpt. No incluye Reformer. Vigencia 28 días. Sin contrato anual.',
    8,
    false,
    'mensual'::public.periodicidad_bono,
    28,
    70.00,
    true,
    10,
    '#A3968D',
    true,
    '2 DÍAS · HORARIO LIMITADO',
    '2 días / semana · Suelo, Yoga, Barre, Sculpt · Sin Reformer'
  ),
  (
    'NŌVA BALANCE',
    '2 días a la semana en horario completo. Acceso a todas las disciplinas, incluido Reformer. Vigencia 28 días. Sin contrato anual.',
    8,
    false,
    'mensual'::public.periodicidad_bono,
    28,
    130.00,
    true,
    20,
    '#4D403A',
    true,
    '2 DÍAS · HORARIO COMPLETO',
    '2 días / semana · Todas las disciplinas incl. Reformer'
  ),
  (
    'NŌVA MOVE',
    '3 días a la semana en horario completo. Acceso a todas las disciplinas. Vigencia 28 días. Sin contrato anual.',
    12,
    false,
    'mensual'::public.periodicidad_bono,
    28,
    160.00,
    true,
    30,
    '#4D403A',
    true,
    '3 DÍAS · HORARIO COMPLETO',
    '3 días / semana · Todas las disciplinas incl. Reformer'
  ),
  (
    'PRIORITY MEMBERSHIP',
    'Contrato anual. Hasta 5 días a la semana, todas las disciplinas, prioridad de reserva, nutricionista, Starter Bag y talleres incluidos.',
    20,
    false,
    'mensual'::public.periodicidad_bono,
    28,
    170.00,
    true,
    40,
    '#262626',
    true,
    'HASTA 5 DÍAS · CONTRATO ANUAL',
    'Hasta 5 días / semana · Prioridad · Contrato anual'
  )
ON CONFLICT (nombre) DO UPDATE SET
  descripcion = EXCLUDED.descripcion,
  sesiones = EXCLUDED.sesiones,
  duracion_dias = EXCLUDED.duracion_dias,
  precio = EXCLUDED.precio,
  activo = EXCLUDED.activo,
  orden = EXCLUDED.orden,
  color_hex = EXCLUDED.color_hex,
  visible_web = EXCLUDED.visible_web,
  web_tag = EXCLUDED.web_tag,
  web_meta = EXCLUDED.web_meta;
