-- Endurecer privilegios, perfiles, avatares y registro.
-- Idempotente.

-- 1) Nadie autenticado puede TRUNCATE (TRUNCATE ignora RLS).
DO $$
DECLARE r RECORD;
BEGIN
  FOR r IN
    SELECT c.relname
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public' AND c.relkind IN ('r', 'p')
  LOOP
    EXECUTE format('REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.%I FROM PUBLIC, anon, authenticated', r.relname);
    EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', r.relname);
    EXECUTE format('ALTER TABLE public.%I FORCE ROW LEVEL SECURITY', r.relname);
  END LOOP;
END $$;

-- 2) Tablas de dinero: escritura solo por SECURITY DEFINER (RPC).
REVOKE INSERT, UPDATE, DELETE ON public.transacciones FROM anon, authenticated, PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.facturas FROM anon, authenticated, PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.vales_regalo FROM anon, authenticated, PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.caja_diaria FROM anon, authenticated, PUBLIC;
GRANT SELECT ON public.transacciones TO authenticated;
GRANT SELECT ON public.facturas TO authenticated;
GRANT SELECT ON public.vales_regalo TO authenticated;
GRANT SELECT ON public.caja_diaria TO authenticated;

-- 3) Perfil: el cliente no puede tocar rol / activo / notas / email / flag de password.
CREATE OR REPLACE FUNCTION public.guard_perfiles_sensitive_fields()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  IF public.mi_rol() <> 'admin' THEN
    NEW.rol := OLD.rol;
    NEW.activo := OLD.activo;
    NEW.notas := OLD.notas;
    NEW.email := OLD.email;
    NEW.debe_definir_password := OLD.debe_definir_password;
    NEW.id := OLD.id;
  END IF;

  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.guard_perfiles_sensitive_fields() FROM PUBLIC, anon, authenticated;

DROP POLICY IF EXISTS "Actualizar propio perfil" ON public.perfiles;
CREATE POLICY "Actualizar propio perfil" ON public.perfiles
  FOR UPDATE
  USING ((id = (SELECT auth.uid())) OR (public.mi_rol() = 'admin'))
  WITH CHECK ((id = (SELECT auth.uid())) OR (public.mi_rol() = 'admin'));

-- 4) Altas públicas: siempre cliente. Nadie se autoasigna admin.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.perfiles (id, email, nombre, rol)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)),
    'cliente'
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$;

-- 5) Avatares: tamaño y tipo.
UPDATE storage.buckets
SET file_size_limit = 2097152,
    allowed_mime_types = ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp']
WHERE name = 'avatares';
