-- Permite al admin actualizar la contraseña de un usuario existente (mismo email en alta / TPV).
-- Ejecutar en Supabase → SQL Editor después de tener pgcrypto (mismo esquema que admin_crear_usuario).

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.admin_actualizar_password_usuario(
  p_email TEXT,
  p_new_password TEXT
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() <> 'admin' THEN
    RAISE EXCEPTION 'Solo admin puede actualizar contraseñas.';
  END IF;
  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RAISE EXCEPTION 'El email es obligatorio.';
  END IF;
  IF p_new_password IS NULL OR length(p_new_password) < 6 THEN
    RAISE EXCEPTION 'La contraseña debe tener al menos 6 caracteres.';
  END IF;

  UPDATE auth.users
  SET
    encrypted_password = crypt(p_new_password, gen_salt('bf')),
    updated_at = now()
  WHERE email = lower(btrim(p_email));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No existe cuenta de acceso con ese email.';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_actualizar_password_usuario(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_actualizar_password_usuario(TEXT, TEXT) TO authenticated;
