-- Bucket público para fotos de productos del TPV (admin sube, todos leen)

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'tienda',
  'tienda',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/jpg', 'image/png', 'image/webp', 'image/gif']::text[]
)
ON CONFLICT (id) DO UPDATE SET
  public = EXCLUDED.public,
  file_size_limit = EXCLUDED.file_size_limit,
  allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Lectura pública tienda" ON storage.objects;
CREATE POLICY "Lectura pública tienda"
  ON storage.objects FOR SELECT
  TO public
  USING (bucket_id = 'tienda');

DROP POLICY IF EXISTS "Admin sube tienda" ON storage.objects;
CREATE POLICY "Admin sube tienda"
  ON storage.objects FOR INSERT
  TO authenticated
  WITH CHECK (bucket_id = 'tienda' AND public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Admin actualiza tienda" ON storage.objects;
CREATE POLICY "Admin actualiza tienda"
  ON storage.objects FOR UPDATE
  TO authenticated
  USING (bucket_id = 'tienda' AND public.mi_rol() = 'admin')
  WITH CHECK (bucket_id = 'tienda' AND public.mi_rol() = 'admin');

DROP POLICY IF EXISTS "Admin borra tienda" ON storage.objects;
CREATE POLICY "Admin borra tienda"
  ON storage.objects FOR DELETE
  TO authenticated
  USING (bucket_id = 'tienda' AND public.mi_rol() = 'admin');
