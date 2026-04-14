-- =============================================
-- NŌVA PILATES STUDIO - FULL SETUP (UNIFICADO)
-- =============================================
-- Ejecuta este archivo en Supabase SQL Editor.
-- Incluye:
-- - extensiones, enums, tablas e índices
-- - triggers y funciones (auth/perfiles)
-- - RPC de reservas y asistencia
-- - función admin para crear usuarios
-- - RLS + policies
-- - vista de calendario
-- - seeds mínimos de catálogo

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ══════════════════════════════════════════════
-- ENUMS (idempotente y compatible)
-- ══════════════════════════════════════════════
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'rol_usuario') THEN
    CREATE TYPE rol_usuario AS ENUM ('cliente', 'empleado', 'admin');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_reserva') THEN
    CREATE TYPE estado_reserva AS ENUM ('confirmada', 'cancelada', 'asistida', 'no_asistio');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'estado_reserva' AND e.enumlabel = 'no_asistio'
  ) THEN
    ALTER TYPE estado_reserva ADD VALUE 'no_asistio';
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'periodicidad_bono') THEN
    CREATE TYPE periodicidad_bono AS ENUM ('semanal', 'mensual', 'trimestral', 'ilimitado');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_type t
    JOIN pg_enum e ON e.enumtypid = t.oid
    WHERE t.typname = 'periodicidad_bono' AND e.enumlabel = 'trimestral'
  ) THEN
    ALTER TYPE periodicidad_bono ADD VALUE 'trimestral';
  END IF;
END $$;

-- ══════════════════════════════════════════════
-- TABLAS
-- ══════════════════════════════════════════════
CREATE TABLE IF NOT EXISTS public.perfiles (
  id                UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rol               rol_usuario NOT NULL DEFAULT 'cliente',
  nombre            TEXT NOT NULL,
  apellidos         TEXT,
  email             TEXT UNIQUE NOT NULL,
  telefono          TEXT,
  fecha_nacimiento  DATE,
  avatar_url        TEXT,
  notas             TEXT,
  activo            BOOLEAN NOT NULL DEFAULT TRUE,
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  updated_at        TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.tipos_bono (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre          TEXT NOT NULL,
  descripcion     TEXT,
  sesiones        INTEGER,
  ilimitado       BOOLEAN NOT NULL DEFAULT FALSE,
  periodicidad    periodicidad_bono NOT NULL DEFAULT 'mensual',
  duracion_dias   INTEGER NOT NULL DEFAULT 30,
  precio          DECIMAL(8,2),
  activo          BOOLEAN NOT NULL DEFAULT TRUE,
  color_hex       TEXT DEFAULT '#c9a96e',
  orden           INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.bonos_activos (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id         UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  tipo_bono_id      UUID NOT NULL REFERENCES public.tipos_bono(id),
  sesiones_totales  INTEGER,
  sesiones_usadas   INTEGER NOT NULL DEFAULT 0,
  fecha_inicio      DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_fin         DATE NOT NULL,
  activo            BOOLEAN NOT NULL DEFAULT TRUE,
  notas             TEXT,
  asignado_por      UUID REFERENCES public.perfiles(id),
  created_at        TIMESTAMPTZ DEFAULT NOW(),
  CONSTRAINT sesiones_no_negativas CHECK (sesiones_usadas >= 0),
  CONSTRAINT sesiones_no_exceden CHECK (sesiones_totales IS NULL OR sesiones_usadas <= sesiones_totales)
);

CREATE TABLE IF NOT EXISTS public.disciplinas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  color_hex   TEXT DEFAULT '#c9a96e',
  icono       TEXT,
  activa      BOOLEAN NOT NULL DEFAULT TRUE,
  orden       INTEGER DEFAULT 0
);

CREATE TABLE IF NOT EXISTS public.salas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre      TEXT NOT NULL,
  capacidad   INTEGER NOT NULL DEFAULT 12,
  descripcion TEXT,
  activa      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS public.clases (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  disciplina_id    UUID NOT NULL REFERENCES public.disciplinas(id),
  sala_id          UUID REFERENCES public.salas(id),
  instructora_id   UUID REFERENCES public.perfiles(id),
  titulo           TEXT,
  fecha_hora       TIMESTAMPTZ NOT NULL,
  duracion_min     INTEGER NOT NULL DEFAULT 55,
  aforo_max        INTEGER NOT NULL DEFAULT 12,
  cancelada        BOOLEAN NOT NULL DEFAULT FALSE,
  nota_cancelacion TEXT,
  es_recurrente    BOOLEAN NOT NULL DEFAULT FALSE,
  recurrencia_id   UUID,
  created_by       UUID REFERENCES public.perfiles(id),
  created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.reservas (
  id                 UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id          UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  clase_id           UUID NOT NULL REFERENCES public.clases(id) ON DELETE CASCADE,
  bono_activo_id     UUID REFERENCES public.bonos_activos(id),
  estado             estado_reserva NOT NULL DEFAULT 'confirmada',
  fecha_reserva      TIMESTAMPTZ DEFAULT NOW(),
  fecha_cancelacion  TIMESTAMPTZ,
  motivo_cancelacion TEXT,
  lista_espera       BOOLEAN NOT NULL DEFAULT FALSE,
  posicion_espera    INTEGER,
  created_at         TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE (perfil_id, clase_id)
);

CREATE TABLE IF NOT EXISTS public.notificaciones (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id   UUID REFERENCES public.perfiles(id) ON DELETE CASCADE,
  titulo      TEXT NOT NULL,
  mensaje     TEXT NOT NULL,
  tipo        TEXT DEFAULT 'info',
  leida       BOOLEAN NOT NULL DEFAULT FALSE,
  enviada_por UUID REFERENCES public.perfiles(id),
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.transacciones (
  id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id      UUID NOT NULL REFERENCES public.perfiles(id),
  bono_activo_id UUID REFERENCES public.bonos_activos(id),
  tipo_bono_id   UUID REFERENCES public.tipos_bono(id),
  importe        DECIMAL(8,2) NOT NULL,
  metodo_pago    TEXT DEFAULT 'efectivo',
  nota           TEXT,
  registrado_por UUID REFERENCES public.perfiles(id),
  created_at     TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS public.ajustes_centro (
  id                       INTEGER PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  margen_reserva_dias      INTEGER NOT NULL DEFAULT 0 CHECK (margen_reserva_dias >= 0),
  margen_cancelacion_dias  INTEGER NOT NULL DEFAULT 0 CHECK (margen_cancelacion_dias >= 0),
  updated_by               UUID REFERENCES public.perfiles(id),
  updated_at               TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.ajustes_centro (id, margen_reserva_dias, margen_cancelacion_dias)
VALUES (1, 0, 0)
ON CONFLICT (id) DO NOTHING;

-- Índices
CREATE INDEX IF NOT EXISTS idx_bonos_activos_perfil ON public.bonos_activos(perfil_id);
CREATE INDEX IF NOT EXISTS idx_bonos_activos_activo ON public.bonos_activos(activo, fecha_fin);
CREATE INDEX IF NOT EXISTS idx_clases_fecha ON public.clases(fecha_hora);
CREATE INDEX IF NOT EXISTS idx_clases_disciplina ON public.clases(disciplina_id);
CREATE INDEX IF NOT EXISTS idx_reservas_perfil ON public.reservas(perfil_id);
CREATE INDEX IF NOT EXISTS idx_reservas_clase ON public.reservas(clase_id);
CREATE INDEX IF NOT EXISTS idx_reservas_estado ON public.reservas(estado);
CREATE INDEX IF NOT EXISTS idx_notif_perfil ON public.notificaciones(perfil_id, leida);
CREATE INDEX IF NOT EXISTS idx_transacciones_perfil ON public.transacciones(perfil_id);
CREATE INDEX IF NOT EXISTS idx_transacciones_fecha ON public.transacciones(created_at);

-- ══════════════════════════════════════════════
-- TRIGGERS / HELPERS AUTH
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS perfiles_updated_at ON public.perfiles;
CREATE TRIGGER perfiles_updated_at
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, email, nombre, rol)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'rol')::rol_usuario, 'cliente')
  )
  ON CONFLICT (id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT AS $$
  SELECT rol::TEXT FROM public.perfiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ══════════════════════════════════════════════
-- RPC / FUNCIONES DE NEGOCIO
-- ══════════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.marcar_asistencia(p_reserva_id UUID, p_asistio BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_estado estado_reserva;
BEGIN
  v_estado := CASE WHEN p_asistio THEN 'asistida'::estado_reserva ELSE 'no_asistio'::estado_reserva END;
  UPDATE public.reservas
  SET estado = v_estado
  WHERE id = p_reserva_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.crear_reserva_segura(p_clase_id UUID)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_clase RECORD;
  v_bono RECORD;
  v_reserva_id UUID;
  v_ocupacion INTEGER;
  v_margen_reserva_dias INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión.'; END IF;

  SELECT id, aforo_max, cancelada, fecha_hora
  INTO v_clase
  FROM public.clases
  WHERE id = p_clase_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'La clase no existe.'; END IF;
  IF v_clase.cancelada THEN RAISE EXCEPTION 'La clase está cancelada.'; END IF;
  IF v_clase.fecha_hora <= NOW() THEN RAISE EXCEPTION 'No se puede reservar una clase pasada.'; END IF;

  SELECT margen_reserva_dias INTO v_margen_reserva_dias FROM public.ajustes_centro WHERE id = 1;
  IF COALESCE(v_margen_reserva_dias, 0) > 0
     AND v_clase.fecha_hora < NOW() + make_interval(days => v_margen_reserva_dias) THEN
    RAISE EXCEPTION 'Debes reservar con al menos % días de antelación.', v_margen_reserva_dias;
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_ocupacion
  FROM public.reservas
  WHERE clase_id = p_clase_id
    AND estado IN ('confirmada', 'asistida');

  IF v_ocupacion >= v_clase.aforo_max THEN RAISE EXCEPTION 'No hay plazas disponibles.'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.reservas
    WHERE perfil_id = v_user_id
      AND clase_id = p_clase_id
      AND estado IN ('confirmada', 'asistida')
  ) THEN
    RAISE EXCEPTION 'Ya tienes una reserva activa para esta clase.';
  END IF;

  SELECT id, sesiones_totales, sesiones_usadas
  INTO v_bono
  FROM public.bonos_activos
  WHERE perfil_id = v_user_id
    AND activo = TRUE
    AND fecha_fin >= CURRENT_DATE
  ORDER BY fecha_inicio DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'No tienes bono activo.'; END IF;
  IF v_bono.sesiones_totales IS NOT NULL AND v_bono.sesiones_usadas >= v_bono.sesiones_totales THEN
    RAISE EXCEPTION 'No tienes sesiones disponibles en tu bono.';
  END IF;

  INSERT INTO public.reservas (perfil_id, clase_id, bono_activo_id, estado)
  VALUES (v_user_id, p_clase_id, v_bono.id, 'confirmada')
  RETURNING id INTO v_reserva_id;

  UPDATE public.bonos_activos
  SET sesiones_usadas = sesiones_usadas + 1
  WHERE id = v_bono.id;

  RETURN v_reserva_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.cancelar_reserva_segura(p_reserva_id UUID)
RETURNS VOID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_reserva RECORD;
  v_margen_cancelacion_dias INTEGER := 0;
BEGIN
  IF v_user_id IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión.'; END IF;

  SELECT r.id, r.estado, r.bono_activo_id, c.fecha_hora
  INTO v_reserva
  FROM public.reservas r
  JOIN public.clases c ON c.id = r.clase_id
  WHERE r.id = p_reserva_id
    AND r.perfil_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN RAISE EXCEPTION 'Reserva no encontrada.'; END IF;
  IF v_reserva.estado = 'cancelada' THEN RETURN; END IF;

  SELECT margen_cancelacion_dias INTO v_margen_cancelacion_dias FROM public.ajustes_centro WHERE id = 1;
  IF COALESCE(v_margen_cancelacion_dias, 0) > 0
     AND v_reserva.fecha_hora < NOW() + make_interval(days => v_margen_cancelacion_dias) THEN
    RAISE EXCEPTION 'No se puede cancelar con menos de % días de antelación.', v_margen_cancelacion_dias;
  END IF;

  UPDATE public.reservas
  SET estado = 'cancelada', fecha_cancelacion = NOW()
  WHERE id = p_reserva_id;

  IF v_reserva.bono_activo_id IS NOT NULL THEN
    UPDATE public.bonos_activos
    SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
    WHERE id = v_reserva.bono_activo_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.admin_crear_usuario(
  p_email TEXT,
  p_password TEXT,
  p_nombre TEXT,
  p_rol rol_usuario DEFAULT 'cliente'
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth
AS $$
DECLARE
  v_new_user_id UUID := gen_random_uuid();
  v_now TIMESTAMPTZ := NOW();
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Debes iniciar sesión.'; END IF;
  IF mi_rol() <> 'admin' THEN RAISE EXCEPTION 'Solo admin puede crear usuarios.'; END IF;
  IF p_email IS NULL OR btrim(p_email) = '' THEN RAISE EXCEPTION 'El email es obligatorio.'; END IF;
  IF p_password IS NULL OR length(p_password) < 6 THEN RAISE EXCEPTION 'La contraseña debe tener al menos 6 caracteres.'; END IF;
  IF p_nombre IS NULL OR btrim(p_nombre) = '' THEN RAISE EXCEPTION 'El nombre es obligatorio.'; END IF;
  IF EXISTS (SELECT 1 FROM auth.users WHERE email = lower(btrim(p_email))) THEN RAISE EXCEPTION 'Ya existe un usuario con ese email.'; END IF;

  INSERT INTO auth.users (
    id, instance_id, aud, role, email, encrypted_password, email_confirmed_at,
    raw_app_meta_data, raw_user_meta_data, created_at, updated_at
  ) VALUES (
    v_new_user_id, '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated',
    lower(btrim(p_email)), crypt(p_password, gen_salt('bf')), v_now,
    jsonb_build_object('provider', 'email', 'providers', ARRAY['email']),
    jsonb_build_object('nombre', p_nombre, 'rol', p_rol::text),
    v_now, v_now
  );

  INSERT INTO auth.identities (
    id, user_id, identity_data, provider, provider_id, created_at, updated_at
  ) VALUES (
    gen_random_uuid(), v_new_user_id,
    jsonb_build_object('sub', v_new_user_id::text, 'email', lower(btrim(p_email))),
    'email', v_new_user_id::text, v_now, v_now
  );

  INSERT INTO public.perfiles (id, email, nombre, rol, activo, created_at, updated_at)
  VALUES (v_new_user_id, lower(btrim(p_email)), p_nombre, p_rol, TRUE, v_now, v_now)
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      nombre = EXCLUDED.nombre,
      rol = EXCLUDED.rol,
      activo = TRUE,
      updated_at = v_now;

  RETURN v_new_user_id;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, rol_usuario) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.admin_crear_usuario(TEXT, TEXT, TEXT, rol_usuario) TO authenticated;

-- ══════════════════════════════════════════════
-- VISTA
-- ══════════════════════════════════════════════
CREATE OR REPLACE VIEW public.calendario_clases AS
SELECT
  c.id,
  c.fecha_hora,
  c.duracion_min,
  c.aforo_max,
  c.cancelada,
  d.nombre AS disciplina,
  d.color_hex AS disciplina_color,
  s.nombre AS sala,
  p.nombre AS instructora,
  COUNT(r.id) FILTER (WHERE r.estado != 'cancelada') AS reservas_activas,
  c.aforo_max - COUNT(r.id) FILTER (WHERE r.estado != 'cancelada') AS plazas_libres
FROM public.clases c
JOIN public.disciplinas d ON d.id = c.disciplina_id
LEFT JOIN public.salas s ON s.id = c.sala_id
LEFT JOIN public.perfiles p ON p.id = c.instructora_id
LEFT JOIN public.reservas r ON r.clase_id = c.id
WHERE c.fecha_hora >= NOW() - INTERVAL '1 day'
GROUP BY c.id, d.nombre, d.color_hex, s.nombre, p.nombre;

-- ══════════════════════════════════════════════
-- RLS + POLICIES (reset controlado)
-- ══════════════════════════════════════════════
ALTER TABLE public.perfiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_bono ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bonos_activos ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clases ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transacciones ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ajustes_centro ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Ver propio perfil" ON public.perfiles;
DROP POLICY IF EXISTS "Actualizar propio perfil" ON public.perfiles;
DROP POLICY IF EXISTS "Admin gestiona perfiles" ON public.perfiles;
CREATE POLICY "Ver propio perfil" ON public.perfiles FOR SELECT USING (id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Actualizar propio perfil" ON public.perfiles FOR UPDATE USING (id = auth.uid());
CREATE POLICY "Admin gestiona perfiles" ON public.perfiles FOR ALL USING (mi_rol() = 'admin');

DROP POLICY IF EXISTS "Leer tipos_bono" ON public.tipos_bono;
DROP POLICY IF EXISTS "Admin gestiona tipos_bono" ON public.tipos_bono;
CREATE POLICY "Leer tipos_bono" ON public.tipos_bono FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona tipos_bono" ON public.tipos_bono FOR ALL USING (mi_rol() = 'admin');

DROP POLICY IF EXISTS "Leer disciplinas" ON public.disciplinas;
DROP POLICY IF EXISTS "Admin gestiona disciplinas" ON public.disciplinas;
CREATE POLICY "Leer disciplinas" ON public.disciplinas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona disciplinas" ON public.disciplinas FOR ALL USING (mi_rol() = 'admin');

DROP POLICY IF EXISTS "Leer salas" ON public.salas;
DROP POLICY IF EXISTS "Admin gestiona salas" ON public.salas;
CREATE POLICY "Leer salas" ON public.salas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona salas" ON public.salas FOR ALL USING (mi_rol() = 'admin');

DROP POLICY IF EXISTS "Ver propio bono" ON public.bonos_activos;
DROP POLICY IF EXISTS "Empleado/admin gestiona bonos" ON public.bonos_activos;
CREATE POLICY "Ver propio bono" ON public.bonos_activos FOR SELECT USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Empleado/admin gestiona bonos" ON public.bonos_activos FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Todos ven clases" ON public.clases;
DROP POLICY IF EXISTS "Empleado/admin gestiona clases" ON public.clases;
CREATE POLICY "Todos ven clases" ON public.clases FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Empleado/admin gestiona clases" ON public.clases FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Ver propias reservas" ON public.reservas;
DROP POLICY IF EXISTS "Crear propia reserva" ON public.reservas;
DROP POLICY IF EXISTS "Cancelar propia reserva" ON public.reservas;
DROP POLICY IF EXISTS "Empleado/admin gestiona reservas" ON public.reservas;
CREATE POLICY "Ver propias reservas" ON public.reservas FOR SELECT USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Crear propia reserva" ON public.reservas FOR INSERT WITH CHECK (perfil_id = auth.uid());
CREATE POLICY "Cancelar propia reserva" ON public.reservas FOR UPDATE USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Empleado/admin gestiona reservas" ON public.reservas FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Ver propias notificaciones" ON public.notificaciones;
DROP POLICY IF EXISTS "Marcar leída" ON public.notificaciones;
DROP POLICY IF EXISTS "Empleado/admin envía notificaciones" ON public.notificaciones;
CREATE POLICY "Ver propias notificaciones" ON public.notificaciones FOR SELECT USING (perfil_id = auth.uid() OR perfil_id IS NULL);
CREATE POLICY "Marcar leída" ON public.notificaciones FOR UPDATE USING (perfil_id = auth.uid());
CREATE POLICY "Empleado/admin envía notificaciones" ON public.notificaciones FOR INSERT WITH CHECK (mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Admin ve todas las transacciones" ON public.transacciones;
DROP POLICY IF EXISTS "Empleado registra transacciones" ON public.transacciones;
CREATE POLICY "Admin ve todas las transacciones" ON public.transacciones FOR SELECT USING (mi_rol() = 'admin');
CREATE POLICY "Empleado registra transacciones" ON public.transacciones FOR INSERT WITH CHECK (mi_rol() IN ('empleado', 'admin'));

DROP POLICY IF EXISTS "Usuarios autenticados leen ajustes" ON public.ajustes_centro;
DROP POLICY IF EXISTS "Admin actualiza ajustes" ON public.ajustes_centro;
CREATE POLICY "Usuarios autenticados leen ajustes" ON public.ajustes_centro FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin actualiza ajustes" ON public.ajustes_centro FOR UPDATE USING (mi_rol() = 'admin');

-- ══════════════════════════════════════════════
-- SEEDS MINIMOS
-- ══════════════════════════════════════════════
INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden)
SELECT 'Bono 4 clases', 4, FALSE, 'mensual', 30, 60.00, 1
WHERE NOT EXISTS (SELECT 1 FROM public.tipos_bono WHERE nombre = 'Bono 4 clases');

INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden)
SELECT 'Bono 8 clases', 8, FALSE, 'mensual', 30, 110.00, 2
WHERE NOT EXISTS (SELECT 1 FROM public.tipos_bono WHERE nombre = 'Bono 8 clases');

INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden)
SELECT 'Mensualidad', NULL, TRUE, 'ilimitado', 30, 175.00, 4
WHERE NOT EXISTS (SELECT 1 FROM public.tipos_bono WHERE nombre = 'Mensualidad');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Reformer Pilates', 'Pilates en máquina reformer', 1
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Reformer Pilates');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Pilates Suelo', 'Pilates mat clásico', 2
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Pilates Suelo');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Yoga', 'Vinyasa y yoga restaurativo', 3
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Yoga');

INSERT INTO public.salas (nombre, capacidad)
SELECT 'Sala Reformer', 6
WHERE NOT EXISTS (SELECT 1 FROM public.salas WHERE nombre = 'Sala Reformer');

INSERT INTO public.salas (nombre, capacidad)
SELECT 'Sala Principal', 12
WHERE NOT EXISTS (SELECT 1 FROM public.salas WHERE nombre = 'Sala Principal');
