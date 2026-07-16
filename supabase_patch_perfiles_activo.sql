-- Parche: columna activo en public.perfiles
-- Error típico: column "activo" of relation "perfiles" does not exist
-- Ejecuta en Supabase → SQL Editor (una vez).

ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS activo BOOLEAN NOT NULL DEFAULT TRUE;

UPDATE public.perfiles SET activo = TRUE WHERE activo IS NULL;

COMMENT ON COLUMN public.perfiles.activo IS 'Cuenta/cliente habilitado (staff puede desactivar).';
