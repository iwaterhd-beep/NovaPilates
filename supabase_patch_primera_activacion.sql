-- Primera activación: el cliente entra solo con el email de la ficha y define su contraseña.
-- Ejecutar en Supabase (o aplicar vía migración).

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS debe_definir_password BOOLEAN NOT NULL DEFAULT FALSE;

COMMENT ON COLUMN public.perfiles.debe_definir_password IS
  'TRUE si el cliente aún no ha elegido contraseña (alta por staff/admin).';

-- Actualiza admin_crear_usuario: contraseña opcional → genera temporal + flag.
-- Importante: solo debe existir UNA firma (p_rol TEXT). Elimina la sobrecarga antigua.
DROP FUNCTION IF EXISTS public.admin_crear_usuario(TEXT, TEXT, TEXT, public.rol_usuario);
DROP FUNCTION IF EXISTS public.admin_crear_usuario(TEXT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION public.admin_crear_usuario(
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_rol TEXT DEFAULT 'cliente'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_new_user_id UUID := gen_random_uuid();
  v_now TIMESTAMPTZ := NOW();
  v_rol rol_usuario;
  v_password TEXT;
  v_debe_definir BOOLEAN := FALSE;
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
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN
    RAISE EXCEPTION 'El nombre es obligatorio.';
  END IF;

  IF p_rol IS NULL OR btrim(p_rol) = '' THEN
    p_rol := 'cliente';
  END IF;

  IF p_rol NOT IN ('cliente', 'empleado', 'admin') THEN
    RAISE EXCEPTION 'Rol no válido. Usa cliente, empleado o admin.';
  END IF;
  v_rol := p_rol::rol_usuario;

  IF p_password IS NULL OR btrim(p_password) = '' THEN
    IF v_rol <> 'cliente' THEN
      RAISE EXCEPTION 'Empleado/admin necesitan contraseña (mínimo 6 caracteres).';
    END IF;
    v_password := encode(gen_random_bytes(24), 'hex');
    v_debe_definir := TRUE;
  ELSE
    IF length(p_password) < 6 THEN
      RAISE EXCEPTION 'La contraseña debe tener al menos 6 caracteres.';
    END IF;
    v_password := p_password;
    v_debe_definir := FALSE;
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
    confirmation_token,
    recovery_token,
    email_change_token_new,
    email_change,
    phone,
    phone_change,
    phone_change_token,
    email_change_token_current,
    reauthentication_token,
    raw_app_meta_data,
    raw_user_meta_data,
    is_sso_user,
    is_anonymous,
    created_at,
    updated_at
  ) VALUES (
    v_new_user_id,
    '00000000-0000-0000-0000-000000000000',
    'authenticated',
    'authenticated',
    lower(btrim(p_email)),
    crypt(v_password, gen_salt('bf')),
    v_now,
    '',
    '',
    '',
    '',
    NULL,
    '',
    '',
    '',
    '',
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email'], 'rol', v_rol::text),
    jsonb_build_object('nombre', p_nombre),
    FALSE,
    FALSE,
    v_now,
    v_now
  );

  INSERT INTO auth.identities (
    id,
    user_id,
    identity_data,
    provider,
    provider_id,
    last_sign_in_at,
    created_at,
    updated_at
  ) VALUES (
    gen_random_uuid(),
    v_new_user_id,
    jsonb_build_object(
      'sub', v_new_user_id::text,
      'email', lower(btrim(p_email)),
      'email_verified', true,
      'phone_verified', false
    ),
    'email',
    lower(btrim(p_email)),
    v_now,
    v_now,
    v_now
  );

  INSERT INTO public.perfiles (id, email, nombre, rol, activo, debe_definir_password, created_at, updated_at)
  VALUES (v_new_user_id, lower(btrim(p_email)), p_nombre, v_rol, TRUE, v_debe_definir, v_now, v_now)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      nombre = EXCLUDED.nombre,
      rol = EXCLUDED.rol,
      activo = TRUE,
      debe_definir_password = EXCLUDED.debe_definir_password,
      updated_at = v_now;

  RETURN v_new_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, TEXT) TO authenticated;

-- Si el admin fija contraseña manualmente, ya no es primera activación.
CREATE OR REPLACE FUNCTION public.admin_actualizar_password_usuario(
  p_email TEXT,
  p_new_password TEXT
)
RETURNS VOID
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
  SET encrypted_password = crypt(p_new_password, gen_salt('bf')),
      updated_at = NOW()
  WHERE email = lower(btrim(p_email));

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No existe cuenta de acceso con ese email.';
  END IF;

  UPDATE public.perfiles
  SET debe_definir_password = FALSE,
      updated_at = NOW()
  WHERE email = lower(btrim(p_email));
END;
$$;

REVOKE ALL ON FUNCTION public.admin_actualizar_password_usuario(TEXT, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_actualizar_password_usuario(TEXT, TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.cliente_iniciar_primera_vez(p_email TEXT)
RETURNS TEXT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
BEGIN
  RAISE EXCEPTION 'La primera activación por correo directo está deshabilitada. Usa recuperación por email.';
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_iniciar_primera_vez(TEXT) FROM PUBLIC;

CREATE OR REPLACE FUNCTION public.cliente_marcar_password_definida()
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  UPDATE public.perfiles
  SET debe_definir_password = FALSE,
      updated_at = NOW()
  WHERE id = auth.uid();
END;
$$;

REVOKE ALL ON FUNCTION public.cliente_marcar_password_definida() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.cliente_marcar_password_definida() TO authenticated;
