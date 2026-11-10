-- Deja el estudio sin historial. Conserva staff, las 3 membresías, salas, disciplinas, productos y facturación.

DELETE FROM public.vales_regalo_uso;
DELETE FROM public.vales_regalo;
DELETE FROM public.devoluciones;
DELETE FROM public.facturas;
DELETE FROM public.transacciones;
DELETE FROM public.reservas;
DELETE FROM public.bonos_activos;
DELETE FROM public.caja_diaria;
DELETE FROM public.notificaciones;
DELETE FROM public.clases;

UPDATE public.tipos_bono
SET activo = false, visible_web = false
WHERE nombre NOT IN ('NŌVA MORNING', 'NŌVA ESSENTIAL', 'PRIORITY MEMBERSHIP');

UPDATE public.tipos_bono SET orden = 10, activo = true, visible_web = true WHERE nombre = 'NŌVA MORNING';
UPDATE public.tipos_bono SET orden = 20, activo = true, visible_web = true WHERE nombre = 'NŌVA ESSENTIAL';
UPDATE public.tipos_bono SET orden = 30, activo = true, visible_web = true WHERE nombre = 'PRIORITY MEMBERSHIP';

DELETE FROM public.perfiles WHERE rol = 'cliente';
DELETE FROM auth.identities i
WHERE NOT EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = i.user_id);
DELETE FROM auth.users u
WHERE NOT EXISTS (SELECT 1 FROM public.perfiles p WHERE p.id = u.id);
