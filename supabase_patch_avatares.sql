-- Foto de perfil: bucket + el cliente puede actualizar su avatar_url.

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS avatar_url TEXT;

INSERT INTO storage.buckets (id, name, public)
VALUES ('avatares', 'avatares', true)
ON CONFLICT (id) DO UPDATE SET public = true;

DROP POLICY IF EXISTS "Avatar lectura publica" ON storage.objects;
CREATE POLICY "Avatar lectura publica" ON storage.objects
  FOR SELECT
  USING (bucket_id = 'avatares');

DROP POLICY IF EXISTS "Avatar sube propio o staff" ON storage.objects;
CREATE POLICY "Avatar sube propio o staff" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'avatares'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.mi_rol() IN ('empleado', 'admin')
    )
  );

DROP POLICY IF EXISTS "Avatar actualiza propio o staff" ON storage.objects;
CREATE POLICY "Avatar actualiza propio o staff" ON storage.objects
  FOR UPDATE TO authenticated
  USING (
    bucket_id = 'avatares'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.mi_rol() IN ('empleado', 'admin')
    )
  )
  WITH CHECK (
    bucket_id = 'avatares'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.mi_rol() IN ('empleado', 'admin')
    )
  );

DROP POLICY IF EXISTS "Avatar borra propio o staff" ON storage.objects;
CREATE POLICY "Avatar borra propio o staff" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'avatares'
    AND (
      (storage.foldername(name))[1] = auth.uid()::text
      OR public.mi_rol() IN ('empleado', 'admin')
    )
  );

CREATE OR REPLACE FUNCTION public.guard_perfiles_sensitive_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  IF public.mi_rol() <> 'admin' AND NEW.id = auth.uid() THEN
    NEW.rol := OLD.rol;
    NEW.activo := OLD.activo;
    NEW.notas := OLD.notas;
  END IF;

  RETURN NEW;
END;
$$;
