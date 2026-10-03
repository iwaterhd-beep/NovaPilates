-- Auditoría DB Oct 2026: cierra grants a anon, vista occupancy, índices FK y RLS.

-- ── Vista: no bypasear RLS ni permitir DML a anon ─────────────
DROP VIEW IF EXISTS public.calendario_clases;
CREATE VIEW public.calendario_clases
WITH (security_invoker = true) AS
 SELECT c.id,
    c.fecha_hora,
    c.duracion_min,
    c.aforo_max,
    c.cancelada,
    d.nombre AS disciplina,
    d.color_hex AS disciplina_color,
    s.nombre AS sala,
    p.nombre AS instructora,
    count(r.id) FILTER (WHERE r.estado <> 'cancelada'::estado_reserva) AS reservas_activas,
    c.aforo_max - count(r.id) FILTER (WHERE r.estado <> 'cancelada'::estado_reserva) AS plazas_libres
   FROM clases c
     JOIN disciplinas d ON d.id = c.disciplina_id
     LEFT JOIN salas s ON s.id = c.sala_id
     LEFT JOIN perfiles p ON p.id = c.instructora_id
     LEFT JOIN reservas r ON r.clase_id = c.id
  WHERE c.fecha_hora >= (now() - '1 day'::interval)
  GROUP BY c.id, d.nombre, d.color_hex, s.nombre, p.nombre;

REVOKE ALL ON public.calendario_clases FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.calendario_clases TO authenticated;

-- ── Anon no toca el resto de tablas; la web solo lee planes ───
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM anon;
GRANT SELECT ON public.tipos_bono TO anon;

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON FUNCTIONS FROM PUBLIC;

-- ── Funciones: nadie anónimo; triggers fuera de la API ────────
DO $$
DECLARE r record;
BEGIN
  FOR r IN
    SELECT p.oid::regprocedure AS sig
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon', r.sig);
  END LOOP;
END $$;

REVOKE ALL ON FUNCTION public.update_updated_at() FROM authenticated;
REVOKE ALL ON FUNCTION public.guard_notificaciones_cliente() FROM authenticated;
REVOKE ALL ON FUNCTION public.guard_reserva_cuenta_activa() FROM authenticated;
REVOKE ALL ON FUNCTION public.guard_perfiles_sensitive_fields() FROM authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM authenticated;

GRANT EXECUTE ON FUNCTION public.abrir_caja_diaria(numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_actualizar_password_usuario(text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_crear_usuario(text, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_eliminar_cliente(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_factura(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_transaccion_tpv(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.anular_vale_regalo(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_reserva_segura(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_caja_diaria(numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cerrar_caja_diaria(numeric, text, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cliente_marcar_password_definida() TO authenticated;
GRANT EXECUTE ON FUNCTION public.consultar_vale_regalo(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.crear_reserva_segura(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.devolver_cobro(uuid, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.facturar_cobro(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.guardar_facturacion_config(text, text, text, text, text, text, text, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.marcar_asistencia(uuid, boolean) TO authenticated;
GRANT EXECUTE ON FUNCTION public.mi_rol() TO authenticated;
GRANT EXECUTE ON FUNCTION public.obtener_facturacion_config() TO authenticated;
GRANT EXECUTE ON FUNCTION public.ocupacion_clases(uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_cancelar_reserva_espera(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_promover_reserva_espera(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_reordenar_lista_espera(uuid, uuid[]) TO authenticated;
GRANT EXECUTE ON FUNCTION public.tpv_cobrar_ticket(uuid, text, text, jsonb, text) TO authenticated;

-- ── RLS: solo authenticated + auth.uid() cacheado ─────────────
DROP POLICY IF EXISTS "Usuarios autenticados leen ajustes" ON public.ajustes_centro;
CREATE POLICY "Usuarios autenticados leen ajustes" ON public.ajustes_centro
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admin actualiza ajustes" ON public.ajustes_centro;
CREATE POLICY "Admin actualiza ajustes" ON public.ajustes_centro
  FOR UPDATE TO authenticated
  USING (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Ver propio bono" ON public.bonos_activos;
CREATE POLICY "Ver propio bono" ON public.bonos_activos
  FOR SELECT TO authenticated
  USING (perfil_id = (SELECT auth.uid()) OR public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Empleado/admin gestiona bonos" ON public.bonos_activos;
CREATE POLICY "Empleado/admin gestiona bonos" ON public.bonos_activos
  FOR ALL TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'))
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff ve caja diaria" ON public.caja_diaria;
CREATE POLICY "Staff ve caja diaria" ON public.caja_diaria
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Todos ven clases" ON public.clases;
CREATE POLICY "Todos ven clases" ON public.clases
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Empleado/admin gestiona clases" ON public.clases;
CREATE POLICY "Empleado/admin gestiona clases" ON public.clases
  FOR ALL TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'))
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff ve devoluciones" ON public.devoluciones;
CREATE POLICY "Staff ve devoluciones" ON public.devoluciones
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta devoluciones" ON public.devoluciones;
CREATE POLICY "Staff inserta devoluciones" ON public.devoluciones
  FOR INSERT TO authenticated
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff actualiza devoluciones" ON public.devoluciones;
CREATE POLICY "Staff actualiza devoluciones" ON public.devoluciones
  FOR UPDATE TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Leer disciplinas" ON public.disciplinas;
CREATE POLICY "Leer disciplinas" ON public.disciplinas
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admin gestiona disciplinas" ON public.disciplinas;
CREATE POLICY "Admin gestiona disciplinas" ON public.disciplinas
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Staff ve configuracion facturacion" ON public.facturacion_config;
CREATE POLICY "Staff ve configuracion facturacion" ON public.facturacion_config
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Admin gestiona configuracion facturacion" ON public.facturacion_config;
CREATE POLICY "Admin gestiona configuracion facturacion" ON public.facturacion_config
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Staff ve facturas" ON public.facturas;
CREATE POLICY "Staff ve facturas" ON public.facturas
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Ver propias notificaciones" ON public.notificaciones;
CREATE POLICY "Ver propias notificaciones" ON public.notificaciones
  FOR SELECT TO authenticated
  USING (
    perfil_id = (SELECT auth.uid())
    OR perfil_id IS NULL
    OR public.mi_rol() IN ('empleado', 'admin')
  );

DROP POLICY IF EXISTS "Marcar leída" ON public.notificaciones;
CREATE POLICY "Marcar leída" ON public.notificaciones
  FOR UPDATE TO authenticated
  USING (perfil_id = (SELECT auth.uid()) OR public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Empleado/admin envía notificaciones" ON public.notificaciones;
CREATE POLICY "Empleado/admin envía notificaciones" ON public.notificaciones
  FOR INSERT TO authenticated
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Ver propio perfil" ON public.perfiles;
CREATE POLICY "Ver propio perfil" ON public.perfiles
  FOR SELECT TO authenticated
  USING (id = (SELECT auth.uid()) OR public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Actualizar propio perfil" ON public.perfiles;
CREATE POLICY "Actualizar propio perfil" ON public.perfiles
  FOR UPDATE TO authenticated
  USING (id = (SELECT auth.uid()) OR public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Admin gestiona perfiles" ON public.perfiles;
CREATE POLICY "Admin gestiona perfiles" ON public.perfiles
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Leer salas" ON public.salas;
CREATE POLICY "Leer salas" ON public.salas
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admin gestiona salas" ON public.salas;
CREATE POLICY "Admin gestiona salas" ON public.salas
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Leer tipos_bono" ON public.tipos_bono;
CREATE POLICY "Leer tipos_bono" ON public.tipos_bono
  FOR SELECT TO authenticated
  USING ((SELECT auth.uid()) IS NOT NULL);

DROP POLICY IF EXISTS "Admin gestiona tipos_bono" ON public.tipos_bono;
CREATE POLICY "Admin gestiona tipos_bono" ON public.tipos_bono
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Ver propias reservas" ON public.reservas;
CREATE POLICY "Ver propias reservas" ON public.reservas
  FOR SELECT TO authenticated
  USING (perfil_id = (SELECT auth.uid()) OR public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Empleado/admin gestiona reservas" ON public.reservas;
CREATE POLICY "Empleado/admin gestiona reservas" ON public.reservas
  FOR ALL TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'))
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Admin ve todas las transacciones" ON public.transacciones;
DROP POLICY IF EXISTS "Empleado ve sus transacciones registradas" ON public.transacciones;
CREATE POLICY "Staff ve transacciones" ON public.transacciones
  FOR SELECT TO authenticated
  USING (
    public.mi_rol() = 'admin'
    OR (public.mi_rol() = 'empleado' AND registrado_por = (SELECT auth.uid()))
  );

DROP POLICY IF EXISTS "Staff ve vales regalo" ON public.vales_regalo;
CREATE POLICY "Staff ve vales regalo" ON public.vales_regalo
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff ve usos de vales" ON public.vales_regalo_uso;
CREATE POLICY "Staff ve usos de vales" ON public.vales_regalo_uso
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta usos de vales" ON public.vales_regalo_uso;
CREATE POLICY "Staff inserta usos de vales" ON public.vales_regalo_uso
  FOR INSERT TO authenticated
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

-- ── Índices de FKs que faltaban ───────────────────────────────
CREATE INDEX IF NOT EXISTS idx_ajustes_centro_updated_by ON public.ajustes_centro (updated_by);
CREATE INDEX IF NOT EXISTS idx_bonos_activos_asignado_por ON public.bonos_activos (asignado_por);
CREATE INDEX IF NOT EXISTS idx_bonos_activos_tipo ON public.bonos_activos (tipo_bono_id);
CREATE INDEX IF NOT EXISTS idx_caja_diaria_abierta_por ON public.caja_diaria (abierta_por);
CREATE INDEX IF NOT EXISTS idx_caja_diaria_cerrada_por ON public.caja_diaria (cerrada_por);
CREATE INDEX IF NOT EXISTS idx_clases_created_by ON public.clases (created_by);
CREATE INDEX IF NOT EXISTS idx_clases_instructora ON public.clases (instructora_id);
CREATE INDEX IF NOT EXISTS idx_clases_sala ON public.clases (sala_id);
CREATE INDEX IF NOT EXISTS idx_devoluciones_factura ON public.devoluciones (factura_id);
CREATE INDEX IF NOT EXISTS idx_devoluciones_vale ON public.devoluciones (vale_regalo_id);
CREATE INDEX IF NOT EXISTS idx_facturacion_config_updated_by ON public.facturacion_config (updated_by);
CREATE INDEX IF NOT EXISTS idx_facturas_anulada_por ON public.facturas (anulada_por);
CREATE INDEX IF NOT EXISTS idx_facturas_emitida_por ON public.facturas (emitida_por);
CREATE INDEX IF NOT EXISTS idx_notif_enviada_por ON public.notificaciones (enviada_por);
CREATE INDEX IF NOT EXISTS idx_reservas_bono ON public.reservas (bono_activo_id);
CREATE INDEX IF NOT EXISTS idx_tx_bono_activo ON public.transacciones (bono_activo_id);
CREATE INDEX IF NOT EXISTS idx_tx_devolucion ON public.transacciones (devolucion_id);
CREATE INDEX IF NOT EXISTS idx_tx_registrado_por ON public.transacciones (registrado_por);
CREATE INDEX IF NOT EXISTS idx_tx_tipo_bono ON public.transacciones (tipo_bono_id);
CREATE INDEX IF NOT EXISTS idx_tx_vale ON public.transacciones (vale_regalo_id);
CREATE INDEX IF NOT EXISTS idx_vales_anulado_por ON public.vales_regalo (anulado_por);
CREATE INDEX IF NOT EXISTS idx_vales_emitido_por ON public.vales_regalo (emitido_por);
CREATE INDEX IF NOT EXISTS idx_vales_uso_registrado ON public.vales_regalo_uso (registrado_por);
CREATE INDEX IF NOT EXISTS idx_vales_uso_usado_en ON public.vales_regalo_uso (usado_en);
