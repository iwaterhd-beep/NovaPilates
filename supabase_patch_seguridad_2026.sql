-- PARCHE DE SEGURIDAD (sep 2026)
-- Cierra atajos de API: reservas, asistencia, sesiones de bono, notificaciones y tablas de dinero.
-- Idempotente. Ejecutar en Supabase → SQL Editor (o vía MCP).
-- El TPV, reservas seguras y facturación siguen funcionando porque usan SECURITY DEFINER.

-- ── Rol helper ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT rol::TEXT FROM public.perfiles WHERE id = auth.uid();
$$;

-- ── Reservas: solo RPC para el cliente ─────────────────────────
DROP POLICY IF EXISTS "Crear propia reserva" ON public.reservas;
DROP POLICY IF EXISTS "Cancelar propia reserva" ON public.reservas;

-- Staff sigue pudiendo confirmar asistencia / lista de espera desde el panel.
DROP POLICY IF EXISTS "Empleado/admin gestiona reservas" ON public.reservas;
CREATE POLICY "Empleado/admin gestiona reservas" ON public.reservas
  FOR ALL
  USING (public.mi_rol() IN ('empleado', 'admin'))
  WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP TRIGGER IF EXISTS reservas_cuenta_activa ON public.reservas;
CREATE OR REPLACE FUNCTION public.guard_reserva_cuenta_activa()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.perfiles p
    WHERE p.id = NEW.perfil_id AND p.activo IS FALSE
  ) THEN
    RAISE EXCEPTION 'La cuenta no está activa.';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER reservas_cuenta_activa
  BEFORE INSERT ON public.reservas
  FOR EACH ROW EXECUTE FUNCTION public.guard_reserva_cuenta_activa();

GRANT EXECUTE ON FUNCTION public.crear_reserva_segura(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancelar_reserva_segura(UUID) TO authenticated;
REVOKE ALL ON FUNCTION public.crear_reserva_segura(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.crear_reserva_segura(UUID) FROM anon;
REVOKE ALL ON FUNCTION public.cancelar_reserva_segura(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.cancelar_reserva_segura(UUID) FROM anon;

-- ── Asistencia: solo staff ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.marcar_asistencia(p_reserva_id UUID, p_asistio BOOLEAN)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_estado estado_reserva;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No tienes permiso para marcar asistencia.';
  END IF;

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
$$;

REVOKE ALL ON FUNCTION public.marcar_asistencia(UUID, BOOLEAN) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.marcar_asistencia(UUID, BOOLEAN) FROM anon;
GRANT EXECUTE ON FUNCTION public.marcar_asistencia(UUID, BOOLEAN) TO authenticated;

-- ── Sesiones de bono: no invocables por API ───────────────────
CREATE OR REPLACE FUNCTION public.descontar_sesion(p_bono_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No tienes permiso.';
  END IF;
  UPDATE public.bonos_activos
  SET sesiones_usadas = sesiones_usadas + 1
  WHERE id = p_bono_id
    AND (sesiones_totales IS NULL OR sesiones_usadas < sesiones_totales);
END;
$$;

CREATE OR REPLACE FUNCTION public.devolver_sesion(p_bono_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL OR public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No tienes permiso.';
  END IF;
  UPDATE public.bonos_activos
  SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
  WHERE id = p_bono_id;
END;
$$;

REVOKE ALL ON FUNCTION public.descontar_sesion(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.descontar_sesion(UUID) FROM anon;
REVOKE ALL ON FUNCTION public.descontar_sesion(UUID) FROM authenticated;
REVOKE ALL ON FUNCTION public.devolver_sesion(UUID) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.devolver_sesion(UUID) FROM anon;
REVOKE ALL ON FUNCTION public.devolver_sesion(UUID) FROM authenticated;

-- ── Notificaciones: el cliente solo puede marcar leída ────────
DROP TRIGGER IF EXISTS notificaciones_solo_leida ON public.notificaciones;
CREATE OR REPLACE FUNCTION public.guard_notificaciones_cliente()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  IF public.mi_rol() IN ('empleado', 'admin') THEN
    RETURN NEW;
  END IF;
  NEW.titulo := OLD.titulo;
  NEW.mensaje := OLD.mensaje;
  NEW.tipo := OLD.tipo;
  NEW.perfil_id := OLD.perfil_id;
  NEW.enviada_por := OLD.enviada_por;
  NEW.created_at := OLD.created_at;
  RETURN NEW;
END;
$$;

CREATE TRIGGER notificaciones_solo_leida
  BEFORE UPDATE ON public.notificaciones
  FOR EACH ROW EXECUTE FUNCTION public.guard_notificaciones_cliente();

-- ── Tablas de dinero: lectura staff, escritura solo por RPC ───
DROP POLICY IF EXISTS "Empleado registra transacciones" ON public.transacciones;

DO $$
BEGIN
  IF to_regclass('public.facturas') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "Staff inserta facturas" ON public.facturas';
    EXECUTE 'DROP POLICY IF EXISTS "Staff actualiza facturas" ON public.facturas';
  END IF;
  IF to_regclass('public.vales_regalo') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "Staff inserta vales regalo" ON public.vales_regalo';
    EXECUTE 'DROP POLICY IF EXISTS "Staff actualiza vales regalo" ON public.vales_regalo';
  END IF;
  IF to_regclass('public.caja_diaria') IS NOT NULL THEN
    EXECUTE 'DROP POLICY IF EXISTS "Staff inserta caja diaria" ON public.caja_diaria';
    EXECUTE 'DROP POLICY IF EXISTS "Staff actualiza caja diaria" ON public.caja_diaria';
  END IF;
END $$;
