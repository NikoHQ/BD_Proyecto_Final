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

CREATE INDEX idx_instalacion_recinto ON instalacion (id_recinto);
CREATE INDEX idx_horario_instalacion ON horario (id_instalacion);
CREATE INDEX idx_tarifa_busqueda     ON tarifa (id_instalacion, id_modalidad, dia_semana);
CREATE INDEX idx_bloqueo_instalacion ON bloqueo_instalacion (id_instalacion, fecha_desde);