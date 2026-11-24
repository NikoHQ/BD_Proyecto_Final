-- Aplicar en el esquema SGCD después de instalar Oracle v3.
-- La columna queda NULL en torneos existentes hasta revisar su configuración.
-- El tamaño incluye al capitán. Una inscripción individual tiene tamaño 1.

WHENEVER SQLERROR EXIT FAILURE ROLLBACK

ALTER TABLE SGCD_TORNEOS ADD (
    JUGADORES_POR_EQUIPO_TORNEO NUMBER
        CONSTRAINT CK_SGCD_TORNEO_TAMANO_EQUIPO CHECK (
            JUGADORES_POR_EQUIPO_TORNEO BETWEEN 1 AND 50
            AND JUGADORES_POR_EQUIPO_TORNEO = TRUNC(JUGADORES_POR_EQUIPO_TORNEO)
        )
);

WHENEVER SQLERROR CONTINUE NONE
