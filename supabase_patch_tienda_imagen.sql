-- Catálogo tienda: columna imagen + productos físicos con foto
-- (ya aplicado en remoto; archivo de referencia)

ALTER TABLE public.productos_tienda
  ADD COLUMN IF NOT EXISTS imagen_url TEXT;

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Botella NŌVA', 28.00, 'accesorio', '/assets/shop/botella-nova.jpg?v=2', 1, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Botella NŌVA');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Tote Studio', 32.00, 'accesorio', '/assets/shop/tote-studio.jpg?v=2', 2, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Tote Studio');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Camiseta técnica', 38.00, 'accesorio', '/assets/shop/camiseta-tecnica.jpg?v=2', 3, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Camiseta técnica');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Banda de resistencia', 18.00, 'accesorio', '/assets/shop/banda-resistencia.jpg?v=2', 4, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Banda de resistencia');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Café', 1.50, 'bebida', '/assets/shop/cafe.jpg', 20, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Café');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Agua', 1.00, 'bebida', '/assets/shop/agua.jpg', 21, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Agua');

INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, imagen_url, orden, activo)
SELECT 'Té o infusión', 1.80, 'bebida', '/assets/shop/te-infusion.jpg', 22, true
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Té o infusión');

UPDATE public.productos_tienda SET imagen_url = '/assets/shop/cafe.jpg' WHERE nombre = 'Café';
UPDATE public.productos_tienda SET imagen_url = '/assets/shop/agua.jpg' WHERE nombre = 'Agua';
UPDATE public.productos_tienda SET imagen_url = '/assets/shop/te-infusion.jpg' WHERE nombre = 'Té o infusión';

UPDATE public.productos_tienda
SET imagen_url = '/assets/shop/botella-nova.jpg?v=2', precio_referencia = 28.00, categoria = 'accesorio', activo = true, orden = 1
WHERE nombre = 'Botella NŌVA';

UPDATE public.productos_tienda
SET imagen_url = '/assets/shop/tote-studio.jpg?v=2', precio_referencia = 32.00, categoria = 'accesorio', activo = true, orden = 2
WHERE nombre = 'Tote Studio';

UPDATE public.productos_tienda
SET imagen_url = '/assets/shop/camiseta-tecnica.jpg?v=2', precio_referencia = 38.00, categoria = 'accesorio', activo = true, orden = 3
WHERE nombre = 'Camiseta técnica';

UPDATE public.productos_tienda
SET imagen_url = '/assets/shop/banda-resistencia.jpg?v=2', precio_referencia = 18.00, categoria = 'accesorio', activo = true, orden = 4
WHERE nombre IN ('Banda de resistencia', 'Banda elástica');
