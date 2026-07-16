-- Teléfono en ficha cliente (error: Could not find the 'telefono' column of 'perfiles')
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS telefono TEXT;
