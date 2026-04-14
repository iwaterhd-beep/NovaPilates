-- PARCHE: caja diaria (apertura/cierre)
-- Ejecutar en Supabase SQL Editor.

CREATE TABLE IF NOT EXISTS public.caja_diaria (
  id                         UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  fecha                      DATE NOT NULL UNIQUE,
  estado                     TEXT NOT NULL DEFAULT 'abierta' CHECK (estado IN ('abierta', 'cerrada')),
  fondo_inicial              DECIMAL(10,2) NOT NULL DEFAULT 0,
  abierta_por                UUID NOT NULL REFERENCES public.perfiles(id),
  abierta_at                 TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  cerrada_por                UUID REFERENCES public.perfiles(id),
  cerrada_at                 TIMESTAMPTZ,
  cierre_efectivo_declarado  DECIMAL(10,2),
  cierre_efectivo_sistema    DECIMAL(10,2),
  diferencia_efectivo        DECIMAL(10,2),
  notas_apertura             TEXT,
  notas_cierre               TEXT
);

ALTER TABLE public.caja_diaria ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Staff ve caja diaria" ON public.caja_diaria;
CREATE POLICY "Staff ve caja diaria" ON public.caja_diaria
  FOR SELECT USING (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff inserta caja diaria" ON public.caja_diaria;
CREATE POLICY "Staff inserta caja diaria" ON public.caja_diaria
  FOR INSERT WITH CHECK (public.mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Staff actualiza caja diaria" ON public.caja_diaria;
CREATE POLICY "Staff actualiza caja diaria" ON public.caja_diaria
  FOR UPDATE USING (public.mi_rol() IN ('empleado', 'admin'));

CREATE OR REPLACE FUNCTION public.abrir_caja_diaria(
  p_fondo_inicial DECIMAL DEFAULT 0,
  p_notas TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_hoy DATE := CURRENT_DATE;
  v_id UUID;
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.caja_diaria WHERE fecha = v_hoy) THEN
    RAISE EXCEPTION 'La caja de hoy ya está abierta o cerrada.';
  END IF;

  INSERT INTO public.caja_diaria (fecha, estado, fondo_inicial, abierta_por, notas_apertura)
  VALUES (v_hoy, 'abierta', COALESCE(p_fondo_inicial, 0), v_user, p_notas)
  RETURNING id INTO v_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.cerrar_caja_diaria(
  p_efectivo_declarado DECIMAL,
  p_notas TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user UUID := auth.uid();
  v_hoy DATE := CURRENT_DATE;
  v_caja RECORD;
  v_efectivo_sistema DECIMAL(10,2);
BEGIN
  IF v_user IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;
  IF public.mi_rol() NOT IN ('empleado', 'admin') THEN
    RAISE EXCEPTION 'No autorizado.';
  END IF;

  SELECT * INTO v_caja
  FROM public.caja_diaria
  WHERE fecha = v_hoy
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No hay caja abierta para hoy.';
  END IF;
  IF v_caja.estado = 'cerrada' THEN
    RAISE EXCEPTION 'La caja de hoy ya está cerrada.';
  END IF;

  SELECT COALESCE(SUM(importe), 0)
  INTO v_efectivo_sistema
  FROM public.transacciones
  WHERE created_at >= date_trunc('day', NOW())
    AND metodo_pago = 'efectivo';

  v_efectivo_sistema := v_efectivo_sistema + COALESCE(v_caja.fondo_inicial, 0);

  UPDATE public.caja_diaria
  SET estado = 'cerrada',
      cerrada_por = v_user,
      cerrada_at = NOW(),
      cierre_efectivo_declarado = p_efectivo_declarado,
      cierre_efectivo_sistema = v_efectivo_sistema,
      diferencia_efectivo = COALESCE(p_efectivo_declarado, 0) - COALESCE(v_efectivo_sistema, 0),
      notas_cierre = p_notas
  WHERE id = v_caja.id;
END;
$$;
