-- Añade fecha de nacimiento a perfiles (error: column perfiles.fecha_nacimiento does not exist)
-- Ejecutar en Supabase → SQL Editor.

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS fecha_nacimiento DATE;
