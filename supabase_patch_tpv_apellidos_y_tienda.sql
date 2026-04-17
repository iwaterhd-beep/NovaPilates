-- TPV / perfiles: apellidos + catálogo tienda (accesorios, café, etc.)
-- Ejecutar en Supabase → SQL Editor.

-- 1) Apellidos (error: column perfiles.apellidos does not exist)
ALTER TABLE public.perfiles
  ADD COLUMN IF NOT EXISTS apellidos TEXT;

-- 2) Catálogo de productos para ventas sin bono
CREATE TABLE IF NOT EXISTS public.productos_tienda (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nombre TEXT NOT NULL,
  precio_referencia DECIMAL(8,2) NOT NULL DEFAULT 0,
  categoria TEXT NOT NULL DEFAULT 'otro',
  activo BOOLEAN NOT NULL DEFAULT TRUE,
  orden INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_productos_tienda_activo ON public.productos_tienda(activo, orden);

ALTER TABLE public.productos_tienda ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff lee catálogo tienda" ON public.productos_tienda;
CREATE POLICY "Staff lee catálogo tienda" ON public.productos_tienda
  FOR SELECT TO authenticated
  USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Admin gestiona catálogo tienda" ON public.productos_tienda;
CREATE POLICY "Admin gestiona catálogo tienda" ON public.productos_tienda
  FOR ALL TO authenticated
  USING (public.mi_rol() = 'admin')
  WITH CHECK (public.mi_rol() = 'admin');

-- 3) Semilla suave (solo si la tabla está vacía)
INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, orden)
SELECT 'Café', 1.50, 'bebida', 1
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Café');
INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, orden)
SELECT 'Agua', 1.00, 'bebida', 2
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Agua');
INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, orden)
SELECT 'Té o infusión', 1.80, 'bebida', 3
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Té o infusión');
INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, orden)
SELECT 'Banda elástica', 12.00, 'accesorio', 10
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Banda elástica');
INSERT INTO public.productos_tienda (nombre, precio_referencia, categoria, orden)
SELECT 'Medias antideslizantes', 8.00, 'accesorio', 11
WHERE NOT EXISTS (SELECT 1 FROM public.productos_tienda WHERE nombre = 'Medias antideslizantes');
