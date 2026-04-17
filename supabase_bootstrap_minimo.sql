-- NOVA PILATES - BOOTSTRAP MINIMO
-- Ejecuta este script si el schema completo no se ha aplicado.
-- Crea tipos, tablas y datos base imprescindibles para el seed demo.

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'periodicidad_bono') THEN
    CREATE TYPE periodicidad_bono AS ENUM ('semanal', 'mensual', 'trimestral', 'ilimitado');
  END IF;
END $$;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'estado_reserva') THEN
    CREATE TYPE estado_reserva AS ENUM ('confirmada', 'cancelada', 'asistida', 'no_asistio');
  END IF;
END $$;

ALTER TABLE IF EXISTS public.perfiles
  ADD COLUMN IF NOT EXISTS direccion TEXT,
  ADD COLUMN IF NOT EXISTS ciudad TEXT,
  ADD COLUMN IF NOT EXISTS cp TEXT,
  ADD COLUMN IF NOT EXISTS dni TEXT,
  ADD COLUMN IF NOT EXISTS telefono_emergencia TEXT;

CREATE TABLE IF NOT EXISTS public.tipos_bono (
  id            UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  nombre        TEXT NOT NULL,
  descripcion   TEXT,
  sesiones      INTEGER,
  ilimitado     BOOLEAN NOT NULL DEFAULT FALSE,
  periodicidad  periodicidad_bono NOT NULL DEFAULT 'mensual',
  duracion_dias INTEGER NOT NULL DEFAULT 30,
  precio        DECIMAL(8,2),
  activo        BOOLEAN NOT NULL DEFAULT TRUE,
  color_hex     TEXT DEFAULT '#c9a96e',
  orden         INTEGER DEFAULT 0,
  created_at    TIMESTAMPTZ DEFAULT NOW()
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

CREATE TABLE IF NOT EXISTS public.bonos_activos (
  id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  perfil_id        UUID NOT NULL REFERENCES public.perfiles(id) ON DELETE CASCADE,
  tipo_bono_id     UUID NOT NULL REFERENCES public.tipos_bono(id),
  sesiones_totales INTEGER,
  sesiones_usadas  INTEGER NOT NULL DEFAULT 0,
  fecha_inicio     DATE NOT NULL DEFAULT CURRENT_DATE,
  fecha_fin        DATE NOT NULL,
  activo           BOOLEAN NOT NULL DEFAULT TRUE,
  notas            TEXT,
  asignado_por     UUID REFERENCES public.perfiles(id),
  created_at       TIMESTAMPTZ DEFAULT NOW()
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

INSERT INTO public.tipos_bono (nombre, sesiones, ilimitado, periodicidad, duracion_dias, precio, orden)
SELECT 'Bono 8 clases', 8, FALSE, 'mensual', 30, 110.00, 2
WHERE NOT EXISTS (SELECT 1 FROM public.tipos_bono WHERE nombre = 'Bono 8 clases');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Reformer Pilates', 'Pilates en máquina reformer', 1
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Reformer Pilates');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Yoga', 'Vinyasa y yoga restaurativo', 3
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Yoga');

INSERT INTO public.disciplinas (nombre, descripcion, orden)
SELECT 'Barre', 'Inspirado en el ballet', 4
WHERE NOT EXISTS (SELECT 1 FROM public.disciplinas WHERE nombre = 'Barre');

INSERT INTO public.salas (nombre, capacidad)
SELECT 'Sala Reformer', 6
WHERE NOT EXISTS (SELECT 1 FROM public.salas WHERE nombre = 'Sala Reformer');

INSERT INTO public.salas (nombre, capacidad)
SELECT 'Sala Principal', 12
WHERE NOT EXISTS (SELECT 1 FROM public.salas WHERE nombre = 'Sala Principal');
