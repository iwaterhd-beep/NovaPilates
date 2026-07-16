-- Columna notas en perfiles (notas internas / observaciones cliente)
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS notas TEXT;
