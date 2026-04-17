-- Eliminar cliente (rol cliente): borra reservas, bonos, transacciones, notificaciones y la cuenta en Auth.
-- Solo administradores. No permite eliminar empleados/admin ni tu propia sesión.
-- Ejecutar en Supabase → SQL Editor.

CREATE OR REPLACE FUNCTION public.admin_eliminar_cliente(p_perfil_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_target_rol TEXT;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() <> 'admin' THEN
    RAISE EXCEPTION 'Solo admin puede eliminar clientes.';
  END IF;
  IF p_perfil_id = auth.uid() THEN
    RAISE EXCEPTION 'No puedes eliminar tu propia cuenta.';
  END IF;

  SELECT rol::TEXT INTO v_target_rol FROM public.perfiles WHERE id = p_perfil_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION 'Usuario no encontrado.';
  END IF;
  IF v_target_rol IS DISTINCT FROM 'cliente' THEN
    RAISE EXCEPTION 'Solo se pueden eliminar usuarios con rol cliente.';
  END IF;

  DELETE FROM public.transacciones WHERE perfil_id = p_perfil_id;
  DELETE FROM public.reservas WHERE perfil_id = p_perfil_id;
  DELETE FROM public.bonos_activos WHERE perfil_id = p_perfil_id;
  DELETE FROM public.notificaciones WHERE perfil_id = p_perfil_id;

  UPDATE public.notificaciones SET enviada_por = NULL WHERE enviada_por = p_perfil_id;
  UPDATE public.transacciones SET registrado_por = NULL WHERE registrado_por = p_perfil_id;
  UPDATE public.bonos_activos SET asignado_por = NULL WHERE asignado_por = p_perfil_id;
  UPDATE public.clases SET instructora_id = NULL WHERE instructora_id = p_perfil_id;
  UPDATE public.clases SET created_by = NULL WHERE created_by = p_perfil_id;
  UPDATE public.ajustes_centro SET updated_by = NULL WHERE updated_by = p_perfil_id;

  DELETE FROM auth.identities WHERE user_id = p_perfil_id;
  DELETE FROM auth.users WHERE id = p_perfil_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_eliminar_cliente(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_eliminar_cliente(UUID) TO authenticated;
