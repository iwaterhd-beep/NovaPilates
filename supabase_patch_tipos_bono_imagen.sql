-- Logo por defecto en tipos de bono (TPV)

ALTER TABLE public.tipos_bono
  ADD COLUMN IF NOT EXISTS imagen_url TEXT;

UPDATE public.tipos_bono
SET imagen_url = '/assets/branding/logo-bono-tile.jpg?v=4'
WHERE imagen_url IS NULL OR imagen_url = '';

ALTER TABLE public.tipos_bono
  ALTER COLUMN imagen_url SET DEFAULT '/assets/branding/logo-bono-tile.jpg?v=4';
