-- =====================================================================
-- Sistema de Gestion de Recintos Deportivos - INF324 / ES3
-- Bloque A: recintos, instalaciones, horarios, deportes y tarifas.
--
-- Prototipo SQLite. Equivalencias para el script Oracle:
--   TEXT        -> VARCHAR2(n)
--   NUMERIC     -> NUMBER(p,s)
--   INTEGER PK  -> NUMBER(10) + SEQ_<tabla>.NEXTVAL
--   datetime()  -> SYSTIMESTAMP
--   CHECK/GLOB  -> CHECK con REGEXP_LIKE
--
-- dia_semana: 1 = lunes ... 7 = domingo (ISO-8601).
-- =====================================================================

PRAGMA foreign_keys = ON;
PRAGMA journal_mode = WAL;

CREATE TABLE recinto (
    id_recinto  INTEGER PRIMARY KEY,
    nombre      TEXT NOT NULL,
    direccion   TEXT NOT NULL,
    comuna      TEXT NOT NULL,
    telefono    TEXT,
    estado      TEXT NOT NULL DEFAULT 'ACTIVO'
                CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    creado_en   TEXT NOT NULL DEFAULT (datetime('now', 'localtime')),
    CONSTRAINT uq_recinto_nombre UNIQUE (nombre, comuna)
);

CREATE TABLE instalacion (
    id_instalacion INTEGER PRIMARY KEY,
    id_recinto     INTEGER NOT NULL REFERENCES recinto (id_recinto),
    nombre         TEXT NOT NULL,
    tipo           TEXT NOT NULL
                   CHECK (tipo IN ('CANCHA', 'GIMNASIO', 'SALA', 'PISCINA')),
    superficie_m2  NUMERIC(8,2) CHECK (superficie_m2 > 0),
    estado         TEXT NOT NULL DEFAULT 'DISPONIBLE'
                   CHECK (estado IN ('DISPONIBLE', 'MANTENCION', 'INACTIVA')),
    CONSTRAINT uq_instalacion_nombre UNIQUE (id_recinto, nombre)
);

CREATE TABLE horario (
    id_horario     INTEGER PRIMARY KEY,
    id_instalacion INTEGER NOT NULL
                   REFERENCES instalacion (id_instalacion) ON DELETE CASCADE,
    dia_semana     INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_apertura  TEXT NOT NULL CHECK (hora_apertura GLOB '[0-2][0-9]:[0-5][0-9]'),
    hora_cierre    TEXT NOT NULL CHECK (hora_cierre   GLOB '[0-2][0-9]:[0-5][0-9]'),
    CONSTRAINT uq_horario_inst_dia UNIQUE (id_instalacion, dia_semana),
    CONSTRAINT ck_horario_rango CHECK (hora_apertura < hora_cierre)
);

CREATE TABLE deporte (
    id_deporte INTEGER PRIMARY KEY,
    nombre     TEXT NOT NULL,
    estado     TEXT NOT NULL DEFAULT 'ACTIVO'
               CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT uq_deporte_nombre UNIQUE (nombre)
);

CREATE TABLE modalidad (
    id_modalidad INTEGER PRIMARY KEY,
    id_deporte   INTEGER NOT NULL REFERENCES deporte (id_deporte),
    nombre       TEXT NOT NULL,
    estado       TEXT NOT NULL DEFAULT 'ACTIVO'
                 CHECK (estado IN ('ACTIVO', 'INACTIVO')),
    CONSTRAINT uq_modalidad_nombre UNIQUE (id_deporte, nombre)
);

CREATE TABLE instalacion_modalidad (
    id_instalacion INTEGER NOT NULL
                   REFERENCES instalacion (id_instalacion) ON DELETE CASCADE,
    id_modalidad   INTEGER NOT NULL REFERENCES modalidad (id_modalidad),
    PRIMARY KEY (id_instalacion, id_modalidad)
);

CREATE TABLE tarifa (
    id_tarifa      INTEGER PRIMARY KEY,
    id_instalacion INTEGER NOT NULL,
    id_modalidad   INTEGER NOT NULL,
    dia_semana     INTEGER NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_desde     TEXT NOT NULL CHECK (hora_desde GLOB '[0-2][0-9]:[0-5][0-9]'),
    hora_hasta     TEXT NOT NULL CHECK (hora_hasta GLOB '[0-2][0-9]:[0-5][0-9]'),
    vigente_desde  TEXT NOT NULL CHECK (length(vigente_desde) = 10),
    vigente_hasta  TEXT CHECK (vigente_hasta IS NULL OR length(vigente_hasta) = 10),
    valor_hora     NUMERIC(12,2) NOT NULL CHECK (valor_hora > 0),
    estado         TEXT NOT NULL DEFAULT 'ACTIVA'
                   CHECK (estado IN ('ACTIVA', 'INACTIVA')),
    CONSTRAINT fk_tarifa_instalacion_modalidad
        FOREIGN KEY (id_instalacion, id_modalidad)
        REFERENCES instalacion_modalidad (id_instalacion, id_modalidad),
    CONSTRAINT uq_tarifa_banda
        UNIQUE (id_instalacion, id_modalidad, dia_semana, hora_desde, vigente_desde),
    CONSTRAINT ck_tarifa_horas  CHECK (hora_desde < hora_hasta),
    CONSTRAINT ck_tarifa_vigencia
        CHECK (vigente_hasta IS NULL OR vigente_hasta >= vigente_desde)
);

CREATE TABLE bloqueo_instalacion (
    id_bloqueo     INTEGER PRIMARY KEY,
    id_instalacion INTEGER NOT NULL
                   REFERENCES instalacion (id_instalacion) ON DELETE CASCADE,
    fecha_desde    TEXT NOT NULL CHECK (length(fecha_desde) = 10),
    fecha_hasta    TEXT NOT NULL CHECK (length(fecha_hasta) = 10),
    hora_desde     TEXT CHECK (hora_desde GLOB '[0-2][0-9]:[0-5][0-9]'),
    hora_hasta     TEXT CHECK (hora_hasta GLOB '[0-2][0-9]:[0-5][0-9]'),
    motivo         TEXT NOT NULL,
    tipo           TEXT NOT NULL
                   CHECK (tipo IN ('MANTENCION', 'FERIADO', 'EVENTO', 'CIERRE')),
    CONSTRAINT ck_bloqueo_fechas CHECK (fecha_hasta >= fecha_desde),
    CONSTRAINT ck_bloqueo_horas
        CHECK (
            (hora_desde IS NULL AND hora_hasta IS NULL)
            OR (hora_desde IS NOT NULL AND hora_hasta IS NOT NULL
                AND hora_desde < hora_hasta)
        )
);

CREATE INDEX idx_instalacion_recinto  ON instalacion (id_recinto);
CREATE INDEX idx_horario_instalacion  ON horario (id_instalacion);
CREATE INDEX idx_tarifa_busqueda      ON tarifa (id_instalacion, id_modalidad, dia_semana);
CREATE INDEX idx_bloqueo_instalacion  ON bloqueo_instalacion (id_instalacion, fecha_desde);

-- =====================================================================
-- Datos de prueba (recintos ficticios de Talca)
-- =====================================================================

INSERT INTO recinto (id_recinto, nombre, direccion, comuna, telefono) VALUES
    (1, 'Complejo Deportivo Las Rastras', 'Av. San Miguel 1234', 'Talca', '+56712334455'),
    (2, 'Club Deportivo La Florida',      '4 Norte 567',         'Talca', '+56712334466');

INSERT INTO instalacion (id_instalacion, id_recinto, nombre, tipo, superficie_m2) VALUES
    (1, 1, 'Cancha Futbol 7',      'CANCHA',   1200.00),
    (2, 1, 'Cancha Futbol 5',      'CANCHA',    800.00),
    (3, 1, 'Cancha Padel 1',       'CANCHA',    200.00),
    (4, 1, 'Gimnasio Multiuso',    'GIMNASIO',  600.00),
    (5, 2, 'Cancha Basquetbol',    'CANCHA',    420.00),
    (6, 2, 'Cancha Voleibol',      'CANCHA',    360.00),
    (7, 2, 'Sala de Entrenamiento','SALA',      120.00);

INSERT INTO deporte (id_deporte, nombre) VALUES
    (1, 'Futbol'),
    (2, 'Padel'),
    (3, 'Basquetbol'),
    (4, 'Voleibol'),
    (5, 'Acondicionamiento fisico');

INSERT INTO modalidad (id_modalidad, id_deporte, nombre) VALUES
    (1, 1, 'Futbol 5'),
    (2, 1, 'Futbol 7'),
    (3, 2, 'Padel dobles'),
    (4, 3, 'Basquetbol 5x5'),
    (5, 4, 'Voleibol 6x6'),
    (6, 5, 'Entrenamiento funcional');

INSERT INTO instalacion_modalidad (id_instalacion, id_modalidad) VALUES
    (1, 2),
    (2, 1),
    (3, 3),
    (4, 1), (4, 4), (4, 5), (4, 6),
    (5, 4),
    (6, 5),
    (7, 6);

INSERT INTO horario (id_instalacion, dia_semana, hora_apertura, hora_cierre)
WITH dias (d) AS (VALUES (1), (2), (3), (4), (5), (6), (7))
SELECT i.id_instalacion,
       d.d,
       CASE WHEN d.d BETWEEN 6 AND 7 THEN '09:00' ELSE '08:00' END,
       CASE WHEN d.d BETWEEN 6 AND 7 THEN '20:00' ELSE '23:00' END
FROM instalacion i
CROSS JOIN dias d;

INSERT INTO tarifa (id_instalacion, id_modalidad, dia_semana,
                    hora_desde, hora_hasta, vigente_desde, valor_hora)
WITH bandas (id_instalacion, id_modalidad, dia_desde, dia_hasta,
             hora_desde, hora_hasta, valor) AS (
    VALUES
        (1, 2, 1, 5, '08:00', '18:00', 18000),
        (1, 2, 1, 5, '18:00', '23:00', 25000),
        (1, 2, 6, 7, '09:00', '20:00', 28000),
        (2, 1, 1, 5, '08:00', '18:00', 15000),
        (2, 1, 1, 5, '18:00', '23:00', 20000),
        (2, 1, 6, 7, '09:00', '20:00', 23000),
        (3, 3, 1, 5, '08:00', '23:00', 12000),
        (3, 3, 6, 7, '09:00', '20:00', 15000),
        (4, 1, 1, 5, '08:00', '23:00', 20000),
        (4, 4, 1, 5, '08:00', '23:00', 20000),
        (4, 4, 6, 7, '09:00', '20:00', 22000),
        (4, 5, 1, 5, '08:00', '23:00', 18000),
        (4, 5, 6, 7, '09:00', '20:00', 20000),
        (4, 6, 1, 5, '07:00', '22:00',  6000),
        (4, 6, 6, 7, '09:00', '14:00',  6000),
        (5, 4, 1, 5, '08:00', '22:00', 16000),
        (5, 4, 6, 7, '09:00', '20:00', 18000),
        (6, 5, 1, 5, '08:00', '22:00', 14000),
        (6, 5, 6, 7, '09:00', '20:00', 16000),
        (7, 6, 1, 5, '07:00', '22:00',  8000),
        (7, 6, 6, 7, '09:00', '14:00',  8000)
),
dias (d) AS (VALUES (1), (2), (3), (4), (5), (6), (7))
SELECT b.id_instalacion,
       b.id_modalidad,
       d.d,
       b.hora_desde,
       b.hora_hasta,
       '2026-01-01',
       b.valor
FROM bandas b
JOIN dias d ON d.d BETWEEN b.dia_desde AND b.dia_hasta;

INSERT INTO bloqueo_instalacion
    (id_instalacion, fecha_desde, fecha_hasta, hora_desde, hora_hasta, motivo, tipo)
VALUES
    (4, '2026-11-20', '2026-11-20', '08:00', '12:00',
     'Mantencion de piso y tableros', 'MANTENCION');
