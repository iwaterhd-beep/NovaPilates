-- =============================================
--  NŌVA PILATES STUDIO — Supabase SQL Schema
--  Ejecuta este archivo en el SQL Editor de
--  tu proyecto en supabase.com
-- =============================================


-- ══════════════════════════════════════════════
--  EXTENSIONES
-- ══════════════════════════════════════════════
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";


-- ══════════════════════════════════════════════
--  ENUM TYPES
-- ══════════════════════════════════════════════
CREATE TYPE rol_usuario AS ENUM ('cliente', 'empleado', 'admin');
CREATE TYPE estado_reserva AS ENUM ('confirmada', 'cancelada', 'asistida', 'no_asistida');
CREATE TYPE periodicidad_bono AS ENUM ('semanal', 'mensual', 'ilimitado');


-- ══════════════════════════════════════════════
--  TABLA: perfiles
--  Extiende auth.users de Supabase.
--  Se crea automáticamente al registrar usuario.
-- ══════════════════════════════════════════════
CREATE TABLE public.perfiles (
  id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rol           rol_usuario NOT NULL DEFAULT 'cliente',
  nombre        TEXT NOT NULL,
  apellidos     TEXT,
  email         TEXT UNIQUE NOT NULL,
  telefono      TEXT,
  fecha_nacimiento DATE,
  avatar_url    TEXT,
  notas         TEXT,             -- notas internas (visible solo para empleado/admin)
  activo        BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW(),
  updated_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Trigger: actualizar updated_at automáticamente
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER perfiles_updated_at
  BEFORE UPDATE ON public.perfiles
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- Trigger: crear perfil automáticamente al registrarse en Auth
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.perfiles (id, email, nombre, rol)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'nombre', split_part(NEW.email, '@', 1)),
    COALESCE((NEW.raw_user_meta_data->>'rol')::rol_usuario, 'cliente')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- ══════════════════════════════════════════════
--  TABLA: tipos_bono
--  Catálogo de bonos disponibles (configurable)
-- ══════════════════════════════════════════════
CREATE TABLE public.tipos_bono (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre          TEXT NOT NULL,              -- "Bono 4 clases", "Mensualidad", etc.
  descripcion     TEXT,
  sesiones        INTEGER,                    -- NULL si es ilimitado
  ilimitado       BOOLEAN NOT NULL DEFAULT FALSE,
  periodicidad    periodicidad_bono NOT NULL,
  duracion_dias   INTEGER NOT NULL DEFAULT 30, -- validez del bono
  precio          DECIMAL(8,2),               -- informativo (venta presencial)
  activo          BOOLEAN NOT NULL DEFAULT TRUE,
  color_hex       TEXT DEFAULT '#c9a96e',      -- color en UI
  orden           INTEGER DEFAULT 0,
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

-- Datos iniciales
INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden) VALUES
  ('Bono 4 clases',    4,    FALSE, 'mensual',    30,  60.00, 1),
  ('Bono 8 clases',    8,    FALSE, 'mensual',    30, 110.00, 2),
  ('Bono 12 clases',   12,   FALSE, 'mensual',    30, 155.00, 3),
  ('Mensualidad',      NULL, TRUE,  'ilimitado',  30, 175.00, 4),
  ('Bono 1 clase',     1,    FALSE, 'mensual',    30,  18.00, 0);


-- ══════════════════════════════════════════════
--  TABLA: bonos_activos
--  Bono asignado a un cliente específico
-- ══════════════════════════════════════════════
CREATE TABLE public.bonos_activos (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id         UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  tipo_bono_id      UUID NOT NULL REFERENCES public.tipos_bono(id),
  sesiones_totales  INTEGER,      -- copia del tipo_bono en el momento de asignación
  sesiones_usadas   INTEGER NOT NULL DEFAULT 0,
  fecha_inicio      DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_fin         DATE NOT NULL,
  activo            BOOLEAN NOT NULL DEFAULT TRUE,
  notas             TEXT,
  asignado_por      UUID REFERENCES public.perfiles(id), -- empleado/admin que lo asignó
  created_at        TIMESTAMPTZ DEFAULT NOW(),

  CONSTRAINT sesiones_no_negativas CHECK (sesiones_usadas >= 0),
  CONSTRAINT sesiones_no_exceden CHECK (sesiones_totales IS NULL OR sesiones_usadas <= sesiones_totales)
);

-- Índices
CREATE INDEX idx_bonos_activos_perfil ON public.bonos_activos(perfil_id);
CREATE INDEX idx_bonos_activos_activo ON public.bonos_activos(activo, fecha_fin);


-- ══════════════════════════════════════════════
--  TABLA: disciplinas
--  Reformer, Yoga, Barre, etc.
-- ══════════════════════════════════════════════
CREATE TABLE public.disciplinas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre      TEXT NOT NULL UNIQUE,
  descripcion TEXT,
  color_hex   TEXT DEFAULT '#c9a96e',
  icono       TEXT,
  activa      BOOLEAN NOT NULL DEFAULT TRUE,
  orden       INTEGER DEFAULT 0
);

INSERT INTO public.disciplinas (nombre, descripcion, orden) VALUES
  ('Reformer Pilates', 'Pilates en máquina reformer', 1),
  ('Pilates Suelo',    'Pilates mat clásico', 2),
  ('Yoga',             'Vinyasa y yoga restaurativo', 3),
  ('Barre',            'Inspirado en el ballet', 4),
  ('Sculpt',           'Pilates con carga adicional', 5),
  ('Movilidad',        'Recuperación activa', 6);


-- ══════════════════════════════════════════════
--  TABLA: salas
-- ══════════════════════════════════════════════
CREATE TABLE public.salas (
  id          UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre      TEXT NOT NULL,
  capacidad   INTEGER NOT NULL DEFAULT 12,
  descripcion TEXT,
  activa      BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO public.salas (nombre, capacidad) VALUES
  ('Sala Reformer', 6),
  ('Sala Principal', 12);


-- ══════════════════════════════════════════════
--  TABLA: clases
--  Cada sesión concreta en el calendario
-- ══════════════════════════════════════════════
CREATE TABLE public.clases (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  disciplina_id   UUID NOT NULL REFERENCES public.disciplinas(id),
  sala_id         UUID REFERENCES public.salas(id),
  instructora_id  UUID REFERENCES public.perfiles(id),
  titulo          TEXT,               -- opcional, si quieres nombre personalizado
  fecha_hora      TIMESTAMPTZ NOT NULL,
  duracion_min    INTEGER NOT NULL DEFAULT 55,
  aforo_max       INTEGER NOT NULL DEFAULT 12,
  cancelada       BOOLEAN NOT NULL DEFAULT FALSE,
  nota_cancelacion TEXT,
  es_recurrente   BOOLEAN NOT NULL DEFAULT FALSE,
  recurrencia_id  UUID,               -- agrupa clases de una misma serie
  created_by      UUID REFERENCES public.perfiles(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_clases_fecha ON public.clases(fecha_hora);
CREATE INDEX idx_clases_disciplina ON public.clases(disciplina_id);


-- ══════════════════════════════════════════════
--  TABLA: reservas
-- ══════════════════════════════════════════════
CREATE TABLE public.reservas (
  id                UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id         UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  clase_id          UUID NOT NULL REFERENCES public.clases(id) ON DELETE CASCADE,
  bono_activo_id    UUID REFERENCES public.bonos_activos(id),
  estado            estado_reserva NOT NULL DEFAULT 'confirmada',
  fecha_reserva     TIMESTAMPTZ DEFAULT NOW(),
  fecha_cancelacion TIMESTAMPTZ,
  motivo_cancelacion TEXT,
  lista_espera      BOOLEAN NOT NULL DEFAULT FALSE,
  posicion_espera   INTEGER,
  created_at        TIMESTAMPTZ DEFAULT NOW(),

  UNIQUE (perfil_id, clase_id)  -- una reserva por usuario por clase
);

CREATE INDEX idx_reservas_perfil ON public.reservas(perfil_id);
CREATE INDEX idx_reservas_clase ON public.reservas(clase_id);
CREATE INDEX idx_reservas_estado ON public.reservas(estado);


-- ══════════════════════════════════════════════
--  TABLA: notificaciones
-- ══════════════════════════════════════════════
CREATE TABLE public.notificaciones (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id     UUID REFERENCES public.perfiles(id) ON DELETE CASCADE,  -- NULL = todos
  titulo        TEXT NOT NULL,
  mensaje       TEXT NOT NULL,
  tipo          TEXT DEFAULT 'info',   -- 'info', 'aviso', 'recordatorio', 'promo'
  leida         BOOLEAN NOT NULL DEFAULT FALSE,
  enviada_por   UUID REFERENCES public.perfiles(id),
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_notif_perfil ON public.notificaciones(perfil_id, leida);


-- ══════════════════════════════════════════════
--  TABLA: transacciones (finanzas)
--  Registro de bonos vendidos (presencial)
-- ══════════════════════════════════════════════
CREATE TABLE public.transacciones (
  id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id       UUID NOT NULL REFERENCES public.perfiles(id),
  bono_activo_id  UUID REFERENCES public.bonos_activos(id),
  tipo_bono_id    UUID REFERENCES public.tipos_bono(id),
  importe         DECIMAL(8,2) NOT NULL,
  metodo_pago     TEXT DEFAULT 'efectivo',  -- 'efectivo', 'tarjeta', 'transferencia'
  nota            TEXT,
  registrado_por  UUID REFERENCES public.perfiles(id),
  created_at      TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_transacciones_perfil ON public.transacciones(perfil_id);
CREATE INDEX idx_transacciones_fecha ON public.transacciones(created_at);


-- ══════════════════════════════════════════════
--  FUNCIONES RPC (lógica de negocio en DB)
-- ══════════════════════════════════════════════

-- Descontar sesión de un bono (usado al confirmar reserva)
CREATE OR REPLACE FUNCTION public.descontar_sesion(p_bono_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.bonos_activos
  SET sesiones_usadas = sesiones_usadas + 1
  WHERE id = p_bono_id
    AND (sesiones_totales IS NULL OR sesiones_usadas < sesiones_totales);
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Devolver sesión al bono (usado al cancelar reserva)
CREATE OR REPLACE FUNCTION public.devolver_sesion(p_bono_id UUID)
RETURNS VOID AS $$
BEGIN
  UPDATE public.bonos_activos
  SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
  WHERE id = p_bono_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Marcar asistencia y descontar bono si no se hizo al reservar
CREATE OR REPLACE FUNCTION public.marcar_asistencia(p_reserva_id UUID, p_asistio BOOLEAN)
RETURNS VOID AS $$
DECLARE
  v_estado estado_reserva;
BEGIN
  v_estado := CASE WHEN p_asistio THEN 'asistida'::estado_reserva ELSE 'no_asistida'::estado_reserva END;
  UPDATE public.reservas SET estado = v_estado WHERE id = p_reserva_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Stats: ocupación media de una disciplina (últimos N días)
CREATE OR REPLACE FUNCTION public.stats_ocupacion(p_dias INTEGER DEFAULT 30)
RETURNS TABLE(disciplina TEXT, clases_totales BIGINT, reservas_totales BIGINT, ocupacion_pct NUMERIC) AS $$
BEGIN
  RETURN QUERY
  SELECT
    d.nombre,
    COUNT(DISTINCT c.id),
    COUNT(r.id),
    ROUND(COUNT(r.id)::NUMERIC / NULLIF(COUNT(DISTINCT c.id) * c.aforo_max, 0) * 100, 1)
  FROM public.clases c
  JOIN public.disciplinas d ON d.id = c.disciplina_id
  LEFT JOIN public.reservas r ON r.clase_id = c.id AND r.estado != 'cancelada'
  WHERE c.fecha_hora >= NOW() - (p_dias || ' days')::INTERVAL
    AND c.cancelada = FALSE
  GROUP BY d.nombre, c.aforo_max;
END;
$$ LANGUAGE plpgsql;


-- ══════════════════════════════════════════════
--  ROW LEVEL SECURITY (RLS)
-- ══════════════════════════════════════════════

ALTER TABLE public.perfiles         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bonos_activos    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.clases           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reservas         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notificaciones   ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.transacciones    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tipos_bono       ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.disciplinas      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.salas            ENABLE ROW LEVEL SECURITY;

-- Helper: obtener rol del usuario autenticado
CREATE OR REPLACE FUNCTION public.mi_rol()
RETURNS TEXT AS $$
  SELECT rol::TEXT FROM public.perfiles WHERE id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ── perfiles ──
CREATE POLICY "Ver propio perfil" ON public.perfiles
  FOR SELECT USING (id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Actualizar propio perfil" ON public.perfiles
  FOR UPDATE USING (id = auth.uid());
CREATE POLICY "Admin gestiona perfiles" ON public.perfiles
  FOR ALL USING (mi_rol() = 'admin');

-- ── tipos_bono y disciplinas (lectura pública autenticada) ──
CREATE POLICY "Leer tipos_bono" ON public.tipos_bono FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona tipos_bono" ON public.tipos_bono FOR ALL USING (mi_rol() = 'admin');
CREATE POLICY "Leer disciplinas" ON public.disciplinas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona disciplinas" ON public.disciplinas FOR ALL USING (mi_rol() = 'admin');
CREATE POLICY "Leer salas" ON public.salas FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Admin gestiona salas" ON public.salas FOR ALL USING (mi_rol() = 'admin');

-- ── bonos_activos ──
CREATE POLICY "Ver propio bono" ON public.bonos_activos
  FOR SELECT USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Empleado/admin gestiona bonos" ON public.bonos_activos
  FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

-- ── clases ──
CREATE POLICY "Todos ven clases" ON public.clases FOR SELECT USING (auth.uid() IS NOT NULL);
CREATE POLICY "Empleado/admin gestiona clases" ON public.clases
  FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

-- ── reservas ──
CREATE POLICY "Ver propias reservas" ON public.reservas
  FOR SELECT USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Crear propia reserva" ON public.reservas
  FOR INSERT WITH CHECK (perfil_id = auth.uid());
CREATE POLICY "Cancelar propia reserva" ON public.reservas
  FOR UPDATE USING (perfil_id = auth.uid() OR mi_rol() IN ('empleado', 'admin'));
CREATE POLICY "Empleado/admin gestiona reservas" ON public.reservas
  FOR ALL USING (mi_rol() IN ('empleado', 'admin'));

-- ── notificaciones ──
CREATE POLICY "Ver propias notificaciones" ON public.notificaciones
  FOR SELECT USING (perfil_id = auth.uid() OR perfil_id IS NULL);
CREATE POLICY "Marcar leída" ON public.notificaciones
  FOR UPDATE USING (perfil_id = auth.uid());
CREATE POLICY "Empleado/admin envía notificaciones" ON public.notificaciones
  FOR INSERT WITH CHECK (mi_rol() IN ('empleado', 'admin'));

-- ── transacciones ──
CREATE POLICY "Admin ve todas las transacciones" ON public.transacciones
  FOR SELECT USING (mi_rol() = 'admin');
CREATE POLICY "Empleado registra transacciones" ON public.transacciones
  FOR INSERT WITH CHECK (mi_rol() IN ('empleado', 'admin'));


-- ══════════════════════════════════════════════
--  VISTA: calendario_semanal
--  Útil para el cliente: clases + estado reserva
-- ══════════════════════════════════════════════
CREATE OR REPLACE VIEW public.calendario_clases AS
SELECT
  c.id,
  c.fecha_hora,
  c.duracion_min,
  c.aforo_max,
  c.cancelada,
  d.nombre       AS disciplina,
  d.color_hex    AS disciplina_color,
  s.nombre       AS sala,
  p.nombre       AS instructora,
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
--  RPC CRITICAS DE RESERVA (ATOMICAS)
-- ══════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.crear_reserva_segura(p_clase_id UUID)
RETURNS UUID AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_clase RECORD;
  v_bono RECORD;
  v_reserva_id UUID;
  v_ocupacion INTEGER;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT id, aforo_max, cancelada, fecha_hora
  INTO v_clase
  FROM public.clases
  WHERE id = p_clase_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'La clase no existe.';
  END IF;
  IF v_clase.cancelada THEN
    RAISE EXCEPTION 'La clase está cancelada.';
  END IF;
  IF v_clase.fecha_hora <= NOW() THEN
    RAISE EXCEPTION 'No se puede reservar una clase pasada.';
  END IF;

  SELECT COUNT(*)::INTEGER
  INTO v_ocupacion
  FROM public.reservas
  WHERE clase_id = p_clase_id
    AND estado IN ('confirmada', 'asistida');

  IF v_ocupacion >= v_clase.aforo_max THEN
    RAISE EXCEPTION 'No hay plazas disponibles.';
  END IF;

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

  IF NOT FOUND THEN
    RAISE EXCEPTION 'No tienes bono activo.';
  END IF;

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
  v_horas_restantes NUMERIC;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Debes iniciar sesión.';
  END IF;

  SELECT r.id, r.estado, r.bono_activo_id, c.fecha_hora
  INTO v_reserva
  FROM public.reservas r
  JOIN public.clases c ON c.id = r.clase_id
  WHERE r.id = p_reserva_id
    AND r.perfil_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Reserva no encontrada.';
  END IF;

  IF v_reserva.estado = 'cancelada' THEN
    RETURN;
  END IF;

  v_horas_restantes := EXTRACT(EPOCH FROM (v_reserva.fecha_hora - NOW())) / 3600.0;
  IF v_horas_restantes < 2 THEN
    RAISE EXCEPTION 'No se puede cancelar con menos de 2 horas de antelación.';
  END IF;

  UPDATE public.reservas
  SET estado = 'cancelada',
      fecha_cancelacion = NOW()
  WHERE id = p_reserva_id;

  IF v_reserva.bono_activo_id IS NOT NULL THEN
    UPDATE public.bonos_activos
    SET sesiones_usadas = GREATEST(sesiones_usadas - 1, 0)
    WHERE id = v_reserva.bono_activo_id;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
