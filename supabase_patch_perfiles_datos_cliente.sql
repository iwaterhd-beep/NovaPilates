-- NOVA PILATES - PATCH PROFIL CLIENT DATA
-- Add dedicated fields for detailed client profile info.

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS direccion TEXT,
  ADD COLUMN IF NOT EXISTS ciudad TEXT,
  ADD COLUMN IF NOT EXISTS cp TEXT,
  ADD COLUMN IF NOT EXISTS dni TEXT,
  ADD COLUMN IF NOT EXISTS telefono_emergencia TEXT;

-- Optional helper index for DNI lookups from staff tools.
CREATE INDEX IF NOT EXISTS idx_perfiles_dni ON public.perfiles(dni);
