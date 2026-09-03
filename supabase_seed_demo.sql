-- NOVA PILATES - DATOS DEMO FUNCIONALES
-- Ejecuta este script en Supabase SQL Editor.
-- Requiere que ya existan usuarios:
--   admin@prueba.com, empleado@prueba.com, cliente@prueba.com

DO $$
DECLARE
  v_admin_id UUID;
  v_empleado_id UUID;
  v_cliente_id UUID;
  v_tipo_bono_id UUID;
  v_bono_id UUID;
  v_reformer_id UUID;
  v_yoga_id UUID;
  v_barre_id UUID;
  v_sala_reformer_id UUID;
  v_sala_principal_id UUID;
  v_clase_1 UUID;
  v_clase_2 UUID;
  v_clase_3 UUID;
BEGIN
  SELECT id INTO v_admin_id FROM public.perfiles WHERE email = 'admin@prueba.com' LIMIT 1;
  SELECT id INTO v_empleado_id FROM public.perfiles WHERE email = 'empleado@prueba.com' LIMIT 1;
  SELECT id INTO v_cliente_id FROM public.perfiles WHERE email = 'cliente@prueba.com' LIMIT 1;

  IF v_cliente_id IS NULL THEN
    RAISE EXCEPTION 'No existe cliente@prueba.com en public.perfiles';
  END IF;

  SELECT id INTO v_tipo_bono_id
  FROM public.tipos_bono
  WHERE nombre = 'Bono 8 clases'
  LIMIT 1;

  IF v_tipo_bono_id IS NULL THEN
    INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden)
    VALUES ('Bono 8 clases', 8, FALSE, 'mensual', 30, 110.00, 2)
    RETURNING id INTO v_tipo_bono_id;
  END IF;

  -- Deja un solo bono activo para el cliente demo.
  UPDATE public.bonos_activos
  SET activo = FALSE
  WHERE perfil_id = v_cliente_id AND activo = TRUE;

  INSERT INTO public.bonos_activos (
    perfil_id,
    tipo_bono_id,
    sesiones_totales,
    sesiones_usadas,
    fecha_inicio,
    fecha_fin,
    activo,
    notas,
    asignado_por
  )
  VALUES (
    v_cliente_id,
    v_tipo_bono_id,
    8,
    2,
    CURRENT_DATE,
    CURRENT_DATE + INTERVAL '30 days',
    TRUE,
    'Bono demo para testing UI/flujo',
    COALESCE(v_admin_id, v_empleado_id)
  )
  RETURNING id INTO v_bono_id;

  SELECT id INTO v_reformer_id FROM public.disciplinas WHERE nombre = 'Reformer Pilates' LIMIT 1;
  SELECT id INTO v_yoga_id FROM public.disciplinas WHERE nombre = 'Yoga' LIMIT 1;
  SELECT id INTO v_barre_id FROM public.disciplinas WHERE nombre = 'Barre' LIMIT 1;

  SELECT id INTO v_sala_reformer_id FROM public.salas WHERE nombre = 'Sala Reformer' LIMIT 1;
  SELECT id INTO v_sala_principal_id FROM public.salas WHERE nombre = 'Sala Principal' LIMIT 1;

  -- Crea clases próximas (2, 4 y 6 días hacia delante)
  INSERT INTO public.clases (disciplina_id, sala_id, instructora_id, titulo, fecha_hora, duracion_min, aforo_max, created_by)
  VALUES (
    COALESCE(v_reformer_id, v_yoga_id, v_barre_id),
    COALESCE(v_sala_reformer_id, v_sala_principal_id),
    v_empleado_id,
    'Reformer Flow',
    date_trunc('day', now()) + INTERVAL '2 days' + INTERVAL '10 hours',
    55,
    10,
    COALESCE(v_admin_id, v_empleado_id)
  )
  RETURNING id INTO v_clase_1;

  INSERT INTO public.clases (disciplina_id, sala_id, instructora_id, titulo, fecha_hora, duracion_min, aforo_max, created_by)
  VALUES (
    COALESCE(v_yoga_id, v_reformer_id, v_barre_id),
    COALESCE(v_sala_principal_id, v_sala_reformer_id),
    v_empleado_id,
    'Yoga Restore',
    date_trunc('day', now()) + INTERVAL '4 days' + INTERVAL '18 hours',
    55,
    12,
    COALESCE(v_admin_id, v_empleado_id)
  )
  RETURNING id INTO v_clase_2;

  INSERT INTO public.clases (disciplina_id, sala_id, instructora_id, titulo, fecha_hora, duracion_min, aforo_max, created_by)
  VALUES (
    COALESCE(v_barre_id, v_reformer_id, v_yoga_id),
    COALESCE(v_sala_principal_id, v_sala_reformer_id),
    v_empleado_id,
    'Barre Sculpt',
    date_trunc('day', now()) + INTERVAL '6 days' + INTERVAL '9 hours',
    50,
    12,
    COALESCE(v_admin_id, v_empleado_id)
  )
  RETURNING id INTO v_clase_3;

  -- Reserva dos clases para cliente (confirmadas)
  INSERT INTO public.reservas (perfil_id, clase_id, bono_activo_id, estado)
  VALUES
    (v_cliente_id, v_clase_1, v_bono_id, 'confirmada'),
    (v_cliente_id, v_clase_2, v_bono_id, 'confirmada')
  ON CONFLICT (perfil_id, clase_id) DO NOTHING;

  -- Añade historial (asistida) en una clase pasada
  INSERT INTO public.clases (disciplina_id, sala_id, instructora_id, titulo, fecha_hora, duracion_min, aforo_max, created_by)
  VALUES (
    COALESCE(v_reformer_id, v_yoga_id, v_barre_id),
    COALESCE(v_sala_reformer_id, v_sala_principal_id),
    v_empleado_id,
    'Reformer Base',
    date_trunc('day', now()) - INTERVAL '3 days' + INTERVAL '10 hours',
    55,
    10,
    COALESCE(v_admin_id, v_empleado_id)
  )
  RETURNING id INTO v_clase_3;

  INSERT INTO public.reservas (perfil_id, clase_id, bono_activo_id, estado)
  VALUES (v_cliente_id, v_clase_3, v_bono_id, 'asistida')
  ON CONFLICT (perfil_id, clase_id) DO UPDATE SET estado = 'asistida';

  -- Notificaciones demo
  INSERT INTO public.notificaciones (perfil_id, titulo, mensaje, tipo, leida, enviada_por)
  VALUES
    (v_cliente_id, 'Recordatorio de clase', 'Tienes Reformer Flow en 48h.', 'recordatorio', FALSE, COALESCE(v_empleado_id, v_admin_id)),
    (v_cliente_id, 'Cambio de horario', 'La clase de Yoga Restore se mueve 30 minutos.', 'aviso', FALSE, COALESCE(v_empleado_id, v_admin_id)),
    (NULL, 'Promoción de abril', 'Nueva promo de bonos en recepción.', 'promo', FALSE, COALESCE(v_admin_id, v_empleado_id));

  -- Transacción demo (finanzas)
  INSERT INTO public.transacciones (perfil_id, bono_activo_id, tipo_bono_id, importe, metodo_pago, nota, registrado_por)
  VALUES (
    v_cliente_id,
    v_bono_id,
    v_tipo_bono_id,
    110.00,
    'tarjeta',
    'Venta presencial demo',
    COALESCE(v_admin_id, v_empleado_id)
  );
END $$;
