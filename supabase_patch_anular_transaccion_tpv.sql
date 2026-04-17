-- Anular venta TPV / cobro erróneo (Finanzas).
-- - Elimina el registro en transacciones.
-- - Si era venta de bono: desactiva el bono (solo si no hay sesiones usadas ni reservas no canceladas).
-- - Admin puede anular cualquier venta; empleado solo las que él registró (registrado_por).
-- Ejecutar en Supabase → SQL Editor.

CREATE OR REPLACE FUNCTION public.anular_transaccion_tpv(p_transaccion_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_rol TEXT;
  r RECORD;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  v_rol := public.mi_rol();
  IF v_rol IS NULL OR v_rol NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT t.* INTO r FROM public.transacciones t WHERE t.id = p_transaccion_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Transacción no encontrada.';
  END IF;

  IF v_rol = 'empleado' AND (r.registrado_por IS DISTINCT FROM v_uid) THEN
    RAISE EXCEPTION 'Solo puedes anular ventas que registraste tú.';
  END IF;

  IF r.bono_activo_id IS NOT NULL THEN
    IF EXISTS (
      SELECT 1 FROM public.reservas z
      WHERE z.bono_activo_id = r.bono_activo_id
        AND z.estado IS DISTINCT FROM 'cancelada'
    ) THEN
      RAISE EXCEPTION 'No se puede anular: hay reservas activas ligadas a este bono.';
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.bonos_activos b
      WHERE b.id = r.bono_activo_id
        AND COALESCE(b.sesiones_usadas, 0) > 0
    ) THEN
      RAISE EXCEPTION 'No se puede anular: el bono ya tiene sesiones usadas.';
    END IF;

    UPDATE public.bonos_activos SET activo = FALSE WHERE id = r.bono_activo_id;
  END IF;

  DELETE FROM public.transacciones WHERE id = p_transaccion_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.anular_transaccion_tpv(UUID) TO authenticated;

-- Empleados ven solo sus cobros (para listado y anulación); admin ya tenía SELECT global.
DROP POLICY IF EXISTS "Empleado ve sus transacciones registradas" ON public.transacciones;
CREATE POLICY "Empleado ve sus transacciones registradas" ON public.transacciones
  FOR SELECT USING (
    public.mi_rol() = 'empleado' AND registrado_por = auth.uid()
  );
