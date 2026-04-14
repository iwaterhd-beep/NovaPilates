-- PARCHE: crear usuarios desde panel admin
-- Ejecuta este script en Supabase SQL Editor.

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT AS $$
  SELECT rol::TEXT FROM public.perfiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

CREATE OR REPLACE FUNCTION public.admin_crear_usuario(
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_rol rol_usuario DEFAULT 'cliente'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_new_user_id UUID := gen_random_uuid();
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  IF mi_rol() <> 'admin' THEN
    RAISE EXCEPTION 'Solo admin puede crear usuarios.';
  END IF;

  IF p_email IS NULL OR btrim(p_email) = '' THEN
    RAISE EXCEPTION 'El email es obligatorio.';
  END IF;
  IF p_password IS NULL OR length(p_password) < 6 THEN
    RAISE EXCEPTION 'La contraseña debe tener al menos 6 caracteres.';
  END IF;
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'El nombre es obligatorio.';
  END IF;

  IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(btrim(p_email))) THEN
    RAISE EXCEPTION 'Ya existe un usuario con ese email.';
  END IF;

  INSERT INTO auth.users (
    id,
    instance_id,
    aud,
    role,
    email,
    encrypted_password,
    email_confirmed_at,
    raw_app_meta_data,
    raw_user_meta_data,
    created_at,
    updated_at
  ) VALUES (
    v_new_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    lower(btrim(p_email)),
    crypt(p_password, gen_salt('bf')),
    v_now,
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('nombre', p_nombre, 'rol', p_rol::text),
    v_now,
    v_now
  );

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_new_user_id,
    jsonb_build_object('sub', v_new_user_id::text, 'email', lower(btrim(p_email))),
    'email',
    v_new_user_id::text,
    v_now,
    v_now
  );

  INSERT INTO public.perfiles (id, email, nombre, rol, activo, created_at, updated_at)
  VALUES (v_new_user_id, lower(btrim(p_email)), p_nombre, p_rol, TRUE, v_now, v_now)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      nombre = EXCLUDED.nombre,
      rol = EXCLUDED.rol,
      activo = TRUE,
      updated_at = v_now;

  RETURN v_new_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, rol_usuario) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, rol_usuario) TO authenticated;
