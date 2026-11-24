-- =====================================================================
-- SGCD_PKG_TORNEOS - torneos, inscripciones con nomina y programacion
-- Requiere: 10_ddl_sgcd_19.sql, 12b_pkg_clientes.sql y 12g_pkg_reservas.sql
--
-- Reglas:
--  * El torneo nace PLANIFICADO y solo en ese estado admite inscripciones.
--    Cada inscripcion INSCRITO ocupa un cupo; retirarla lo libera junto con
--    los RUT de su plantilla.
--  * La plantilla va de 1 jugador (el capitan) al maximo del torneo, que se
--    copia de la modalidad al crear y se puede ajustar por torneo.
--  * Un RUT no puede estar en dos equipos activos del mismo torneo, ni dos
--    veces en el mismo equipo. En el catalogo de jugadores se reutiliza la
--    fila por RUT y DV, y se vincula a la ficha de cliente si existe.
--  * CANTIDAD_JUGADORES se recalcula desde los vinculos, nunca se escribe a
--    mano.
--  * La programacion se divide en bloques de una hora y cada bloque es una
--    reserva de torneo: entra por SGCD_PKG_RESERVAS.crear_reserva_torneo, que
--    aplica el mismo candado y la misma regla de solape que el mostrador.
--    Este paquete no inserta en SGCD_RESERVAS.
--
-- Codigos: -20060 datos de torneo invalidos, -20061 el torneo no existe,
-- -20062 el estado no admite la operacion, -20063 no quedan cupos, -20064
-- plantilla fuera del maximo, -20065 el jugador ya esta en el equipo, -20066
-- el jugador ya juega en otro equipo del torneo, -20067 el cliente no esta
-- habilitado, -20068 la inscripcion no existe o no esta vigente, -20069 el
-- nombre de equipo ya existe en el torneo, -20070 rango de programacion
-- invalido. Los errores de calendario (-20041..-20044) vienen de reservas.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_TORNEOS AS
    PROCEDURE crear_torneo(
        p_id_modalidad  NUMBER,
        p_nombre        VARCHAR2,
        p_fecha_inicio  DATE,
        p_fecha_termino DATE,
        p_cupos         NUMBER,
        p_max_jugadores NUMBER DEFAULT NULL,
        p_id_torneo     OUT NUMBER);
    PROCEDURE inscribir_equipo(
        p_id_torneo     NUMBER,
        p_id_cliente    NUMBER,
        p_nombre_equipo VARCHAR2,
        p_id_inscripcion OUT NUMBER);
    PROCEDURE agregar_jugador(
        p_id_inscripcion NUMBER,
        p_rut            NUMBER,
        p_dv             VARCHAR2,
        p_nombre         VARCHAR2);
    PROCEDURE retirar_equipo(p_id_inscripcion NUMBER);
    PROCEDURE ajustar_maximo(p_id_torneo NUMBER, p_max_jugadores NUMBER);
    PROCEDURE programar_torneo(
        p_id_torneo  NUMBER,
        p_id_cancha  NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_hora_hasta VARCHAR2);
    PROCEDURE listar_torneos(
        p_id_modalidad NUMBER DEFAULT NULL,
        p_estado       VARCHAR2 DEFAULT NULL,
        p_id_cliente   NUMBER DEFAULT NULL,
        p_cursor       OUT SYS_REFCURSOR);
    PROCEDURE listar_inscripciones(
        p_id_torneo  NUMBER DEFAULT NULL,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR);
    PROCEDURE inscripcion(
        p_id_inscripcion NUMBER,
        p_cursor         OUT SYS_REFCURSOR);
    PROCEDURE jugadores_inscripcion(
        p_id_inscripcion NUMBER,
        p_cursor         OUT SYS_REFCURSOR);
END SGCD_PKG_TORNEOS;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_TORNEOS AS

    PROCEDURE validar_torneo_datos(
        p_nombre        VARCHAR2,
        p_fecha_inicio  DATE,
        p_fecha_termino DATE,
        p_cupos         NUMBER) IS
    BEGIN
        IF p_nombre IS NULL OR TRIM(p_nombre) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20060, 'El torneo necesita nombre');
        END IF;
        IF p_fecha_inicio IS NULL OR p_fecha_termino IS NULL THEN
            RAISE_APPLICATION_ERROR(-20060, 'El torneo necesita fecha de inicio y de termino');
        END IF;
        IF TRUNC(p_fecha_termino) < TRUNC(p_fecha_inicio) THEN
            RAISE_APPLICATION_ERROR(-20060, 'El termino no puede ser anterior al inicio');
        END IF;
        IF TRUNC(p_fecha_inicio) < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20060, 'El torneo no puede empezar en el pasado');
        END IF;
        IF p_cupos IS NULL OR p_cupos < 1 OR p_cupos > 128 OR p_cupos <> TRUNC(p_cupos) THEN
            RAISE_APPLICATION_ERROR(-20060, 'Los cupos deben ser un entero entre 1 y 128');
        END IF;
    END validar_torneo_datos;

    FUNCTION obtener_jugador(
        p_rut    NUMBER,
        p_dv     CHAR,
        p_nombre VARCHAR2) RETURN NUMBER IS
        v_id_jugador NUMBER;
        v_id_cliente NUMBER;
        v_nombre     VARCHAR2(100) := TRIM(p_nombre);
    BEGIN
        BEGIN
            SELECT c.ID_CLIENTE, c.NOMBRE_CLIENTE INTO v_id_cliente, v_nombre
            FROM   SGCD_CLIENTES c
            WHERE  c.RUT_CLIENTE = p_rut AND c.DV_CLIENTE = p_dv;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_id_cliente := NULL;
        END;

        BEGIN
            SELECT j.ID_JUGADOR INTO v_id_jugador
            FROM   SGCD_JUGADORES j
            WHERE  j.RUT_JUGADOR = p_rut AND j.DV_JUGADOR = p_dv;
            UPDATE SGCD_JUGADORES
            SET    ID_CLIENTE = v_id_cliente,
                   NOMBRE_JUGADOR = v_nombre
            WHERE  ID_JUGADOR = v_id_jugador
              AND  (ID_CLIENTE IS NULL AND v_id_cliente IS NOT NULL);
            RETURN v_id_jugador;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                NULL;
        END;

        INSERT INTO SGCD_JUGADORES (RUT_JUGADOR, DV_JUGADOR, NOMBRE_JUGADOR, ID_CLIENTE)
        VALUES (p_rut, p_dv, v_nombre, v_id_cliente)
        RETURNING ID_JUGADOR INTO v_id_jugador;
        RETURN v_id_jugador;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            SELECT j.ID_JUGADOR INTO v_id_jugador
            FROM   SGCD_JUGADORES j
            WHERE  j.RUT_JUGADOR = p_rut AND j.DV_JUGADOR = p_dv;
            RETURN v_id_jugador;
    END obtener_jugador;

    FUNCTION jugador_en_equipo(p_id_inscripcion NUMBER, p_id_jugador NUMBER) RETURN NUMBER IS
        v_n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_EQUIPOS_JUGADORES ej
        WHERE  ej.ID_INSCRIPCION = p_id_inscripcion
          AND  ej.ID_JUGADOR = p_id_jugador;
        RETURN v_n;
    END jugador_en_equipo;

    FUNCTION jugador_en_torneo(p_id_torneo NUMBER, p_id_jugador NUMBER) RETURN NUMBER IS
        v_n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_EQUIPOS_JUGADORES ej
        JOIN   SGCD_INSCRIPCIONES_TORNEO i ON i.ID_INSCRIPCION = ej.ID_INSCRIPCION
        WHERE  i.ID_TORNEO = p_id_torneo
          AND  i.ESTADO_INSCRIPCION = 'INSCRITO'
          AND  ej.ID_JUGADOR = p_id_jugador;
        RETURN v_n;
    END jugador_en_torneo;

    PROCEDURE recalcular_plantilla(p_id_inscripcion NUMBER) IS
        v_n NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_EQUIPOS_JUGADORES ej
        WHERE  ej.ID_INSCRIPCION = p_id_inscripcion;
        UPDATE SGCD_INSCRIPCIONES_TORNEO
        SET    CANTIDAD_JUGADORES = v_n
        WHERE  ID_INSCRIPCION = p_id_inscripcion;
    END recalcular_plantilla;

    PROCEDURE crear_torneo(
        p_id_modalidad  NUMBER,
        p_nombre        VARCHAR2,
        p_fecha_inicio  DATE,
        p_fecha_termino DATE,
        p_cupos         NUMBER,
        p_max_jugadores NUMBER DEFAULT NULL,
        p_id_torneo     OUT NUMBER) IS
        v_max NUMBER;
    BEGIN
        validar_torneo_datos(p_nombre, p_fecha_inicio, p_fecha_termino, p_cupos);
        BEGIN
            SELECT m.MAX_JUGADORES_POR_EQUIPO INTO v_max
            FROM   SGCD_MODALIDADES m
            WHERE  m.ID_MODALIDAD = p_id_modalidad;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20060, 'La modalidad no existe');
        END;
        IF p_max_jugadores IS NOT NULL THEN
            v_max := p_max_jugadores;
        END IF;
        IF v_max IS NULL OR v_max < 1 OR v_max > 50 OR v_max <> TRUNC(v_max) THEN
            RAISE_APPLICATION_ERROR(-20060, 'El maximo de jugadores debe estar entre 1 y 50');
        END IF;

        INSERT INTO SGCD_TORNEOS (ID_MODALIDAD, NOMBRE_TORNEO, FECHA_INICIO, FECHA_TERMINO,
                                  CUPOS_TORNEO, MAX_JUGADORES_POR_EQUIPO, ESTADO_TORNEO)
        VALUES (p_id_modalidad, TRIM(p_nombre), TRUNC(p_fecha_inicio), TRUNC(p_fecha_termino),
                p_cupos, v_max, 'PLANIFICADO')
        RETURNING ID_TORNEO INTO p_id_torneo;
    END crear_torneo;

    PROCEDURE inscribir_equipo(
        p_id_torneo      NUMBER,
        p_id_cliente     NUMBER,
        p_nombre_equipo  VARCHAR2,
        p_id_inscripcion OUT NUMBER) IS
        v_estado      VARCHAR2(15);
        v_cupos       NUMBER;
        v_max         NUMBER;
        v_inscritos   NUMBER;
        v_rut         NUMBER;
        v_dv          CHAR(1);
        v_nombre      VARCHAR2(100);
        v_id_jugador  NUMBER;
    BEGIN
        IF p_id_torneo IS NULL THEN
            RAISE_APPLICATION_ERROR(-20061, 'Falta el torneo');
        END IF;
        BEGIN
            SELECT t.ESTADO_TORNEO, t.CUPOS_TORNEO, t.MAX_JUGADORES_POR_EQUIPO
            INTO   v_estado, v_cupos, v_max
            FROM   SGCD_TORNEOS t
            WHERE  t.ID_TORNEO = p_id_torneo
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20061, 'El torneo no existe');
        END;
        IF v_estado <> 'PLANIFICADO' THEN
            RAISE_APPLICATION_ERROR(-20062,
                'El torneo esta ' || v_estado || ' y no admite inscripciones');
        END IF;
        IF p_nombre_equipo IS NULL OR TRIM(p_nombre_equipo) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20060, 'La inscripcion necesita nombre de equipo');
        END IF;

        SELECT COUNT(*) INTO v_inscritos
        FROM   SGCD_INSCRIPCIONES_TORNEO i
        WHERE  i.ID_TORNEO = p_id_torneo
          AND  i.ESTADO_INSCRIPCION = 'INSCRITO';
        IF v_inscritos >= v_cupos THEN
            RAISE_APPLICATION_ERROR(-20063,
                'No quedan cupos: ' || v_inscritos || '/' || v_cupos);
        END IF;
        BEGIN
            SELECT COUNT(*) INTO v_inscritos
            FROM   SGCD_INSCRIPCIONES_TORNEO i
            WHERE  i.ID_TORNEO = p_id_torneo
              AND  i.NOMBRE_EQUIPO = TRIM(p_nombre_equipo);
            IF v_inscritos > 0 THEN
                RAISE_APPLICATION_ERROR(-20069, 'Ya hay un equipo con ese nombre en el torneo');
            END IF;
        END;

        BEGIN
            SELECT c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE
            INTO   v_rut, v_dv, v_nombre
            FROM   SGCD_CLIENTES c
            WHERE  c.ID_CLIENTE = p_id_cliente
              AND  c.ESTADO_CLIENTE = 'ACTIVO';
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20067, 'El capitan no existe o esta inactivo');
        END;

        v_id_jugador := obtener_jugador(v_rut, v_dv, v_nombre);
        IF jugador_en_torneo(p_id_torneo, v_id_jugador) > 0 THEN
            RAISE_APPLICATION_ERROR(-20066,
                'El capitan ya juega en otro equipo de este torneo');
        END IF;

        INSERT INTO SGCD_INSCRIPCIONES_TORNEO (ID_TORNEO, ID_CLIENTE, NOMBRE_EQUIPO,
                                               CANTIDAD_JUGADORES, ESTADO_INSCRIPCION)
        VALUES (p_id_torneo, p_id_cliente, TRIM(p_nombre_equipo), 1, 'INSCRITO')
        RETURNING ID_INSCRIPCION INTO p_id_inscripcion;
        INSERT INTO SGCD_EQUIPOS_JUGADORES (ID_INSCRIPCION, ID_JUGADOR)
        VALUES (p_id_inscripcion, v_id_jugador);
    END inscribir_equipo;

    PROCEDURE agregar_jugador(
        p_id_inscripcion NUMBER,
        p_rut            NUMBER,
        p_dv             VARCHAR2,
        p_nombre         VARCHAR2) IS
        v_id_torneo   NUMBER;
        v_estado_insc VARCHAR2(15);
        v_estado_torn VARCHAR2(15);
        v_max         NUMBER;
        v_cantidad    NUMBER;
        v_dv          CHAR(1);
        v_id_jugador  NUMBER;
    BEGIN
        IF p_id_inscripcion IS NULL THEN
            RAISE_APPLICATION_ERROR(-20068, 'Falta la inscripcion');
        END IF;
        BEGIN
            SELECT i.ID_TORNEO, i.ESTADO_INSCRIPCION
            INTO   v_id_torneo, v_estado_insc
            FROM   SGCD_INSCRIPCIONES_TORNEO i
            WHERE  i.ID_INSCRIPCION = p_id_inscripcion;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20068, 'La inscripcion no existe');
        END;
        SELECT t.ESTADO_TORNEO, t.MAX_JUGADORES_POR_EQUIPO
        INTO   v_estado_torn, v_max
        FROM   SGCD_TORNEOS t
        WHERE  t.ID_TORNEO = v_id_torneo
        FOR UPDATE;
        SELECT i.ESTADO_INSCRIPCION INTO v_estado_insc
        FROM   SGCD_INSCRIPCIONES_TORNEO i
        WHERE  i.ID_INSCRIPCION = p_id_inscripcion
        FOR UPDATE;
        IF v_estado_insc <> 'INSCRITO' THEN
            RAISE_APPLICATION_ERROR(-20068, 'La inscripcion esta ' || v_estado_insc);
        END IF;
        IF v_estado_torn <> 'PLANIFICADO' THEN
            RAISE_APPLICATION_ERROR(-20062,
                'El torneo esta ' || v_estado_torn || ' y no admite cambios de plantilla');
        END IF;

        SELECT COUNT(*) INTO v_cantidad
        FROM   SGCD_EQUIPOS_JUGADORES ej
        WHERE  ej.ID_INSCRIPCION = p_id_inscripcion;
        IF v_cantidad >= v_max THEN
            RAISE_APPLICATION_ERROR(-20064,
                'La plantilla ya tiene el maximo de ' || v_max || ' jugadores');
        END IF;

        v_dv := SGCD_PKG_CLIENTES.normalizar_dv(p_dv);
        IF NOT SGCD_PKG_CLIENTES.rut_valido(p_rut, v_dv) THEN
            RAISE_APPLICATION_ERROR(-20060, 'RUT de jugador invalido: ' || p_rut || '-' || v_dv);
        END IF;
        IF p_nombre IS NULL OR TRIM(p_nombre) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20060, 'El jugador necesita nombre');
        END IF;

        v_id_jugador := obtener_jugador(p_rut, v_dv, p_nombre);
        IF jugador_en_equipo(p_id_inscripcion, v_id_jugador) > 0 THEN
            RAISE_APPLICATION_ERROR(-20065, 'El jugador ya esta en este equipo');
        END IF;
        IF jugador_en_torneo(v_id_torneo, v_id_jugador) > 0 THEN
            RAISE_APPLICATION_ERROR(-20066,
                'El jugador ya juega en otro equipo de este torneo');
        END IF;

        INSERT INTO SGCD_EQUIPOS_JUGADORES (ID_INSCRIPCION, ID_JUGADOR)
        VALUES (p_id_inscripcion, v_id_jugador);
        recalcular_plantilla(p_id_inscripcion);
    END agregar_jugador;

    PROCEDURE retirar_equipo(p_id_inscripcion NUMBER) IS
        v_estado      VARCHAR2(15);
        v_id_torneo   NUMBER;
        v_estado_torn VARCHAR2(15);
    BEGIN
        IF p_id_inscripcion IS NULL THEN
            RAISE_APPLICATION_ERROR(-20068, 'Falta la inscripcion');
        END IF;
        BEGIN
            SELECT i.ESTADO_INSCRIPCION, i.ID_TORNEO
            INTO   v_estado, v_id_torneo
            FROM   SGCD_INSCRIPCIONES_TORNEO i
            WHERE  i.ID_INSCRIPCION = p_id_inscripcion
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20068, 'La inscripcion no existe');
        END;
        SELECT t.ESTADO_TORNEO INTO v_estado_torn
        FROM   SGCD_TORNEOS t
        WHERE  t.ID_TORNEO = v_id_torneo;
        IF v_estado = 'RETIRADO' THEN
            RETURN;
        END IF;
        IF v_estado_torn IN ('FINALIZADO', 'CANCELADO') THEN
            RAISE_APPLICATION_ERROR(-20062,
                'El torneo esta ' || v_estado_torn || ' y no admite retiros');
        END IF;
        UPDATE SGCD_INSCRIPCIONES_TORNEO
        SET    ESTADO_INSCRIPCION = 'RETIRADO'
        WHERE  ID_INSCRIPCION = p_id_inscripcion;
    END retirar_equipo;

    PROCEDURE ajustar_maximo(p_id_torneo NUMBER, p_max_jugadores NUMBER) IS
        v_id   NUMBER;
        v_mayor NUMBER;
    BEGIN
        IF p_max_jugadores IS NULL OR p_max_jugadores < 1 OR p_max_jugadores > 50
           OR p_max_jugadores <> TRUNC(p_max_jugadores) THEN
            RAISE_APPLICATION_ERROR(-20060, 'El maximo de jugadores debe estar entre 1 y 50');
        END IF;
        BEGIN
            SELECT t.ID_TORNEO INTO v_id
            FROM   SGCD_TORNEOS t
            WHERE  t.ID_TORNEO = p_id_torneo
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20061, 'El torneo no existe');
        END;
        SELECT NVL(MAX(i.CANTIDAD_JUGADORES), 0) INTO v_mayor
        FROM   SGCD_INSCRIPCIONES_TORNEO i
        WHERE  i.ID_TORNEO = p_id_torneo
          AND  i.ESTADO_INSCRIPCION = 'INSCRITO';
        IF p_max_jugadores < v_mayor THEN
            RAISE_APPLICATION_ERROR(-20064,
                'Hay un equipo activo con ' || v_mayor || ' jugadores');
        END IF;
        UPDATE SGCD_TORNEOS
        SET    MAX_JUGADORES_POR_EQUIPO = p_max_jugadores
        WHERE  ID_TORNEO = p_id_torneo;
    END ajustar_maximo;

    PROCEDURE programar_torneo(
        p_id_torneo  NUMBER,
        p_id_cancha  NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_hora_hasta VARCHAR2) IS
        v_desde  DATE;
        v_hasta  DATE;
        v_bloques NUMBER;
        v_id_reserva NUMBER;
    BEGIN
        IF p_hora_desde IS NULL OR p_hora_hasta IS NULL
           OR NOT REGEXP_LIKE(TRIM(p_hora_desde), '^([01][0-9]|2[0-3]):[0-5][0-9]$')
           OR NOT REGEXP_LIKE(TRIM(p_hora_hasta), '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
            RAISE_APPLICATION_ERROR(-20070, 'Las horas deben venir en formato HH:MI');
        END IF;
        v_desde := TO_DATE(TRIM(p_hora_desde), 'HH24:MI');
        v_hasta := TO_DATE(TRIM(p_hora_hasta), 'HH24:MI');
        v_bloques := (v_hasta - v_desde) * 24;
        IF SUBSTR(TRIM(p_hora_desde), 4, 2) <> '00'
           OR SUBSTR(TRIM(p_hora_hasta), 4, 2) <> '00'
           OR v_bloques < 1 OR v_bloques <> TRUNC(v_bloques) THEN
            RAISE_APPLICATION_ERROR(-20070,
                'El rango debe cubrir bloques completos de una hora');
        END IF;

        SAVEPOINT antes_de_programar;
        BEGIN
            FOR i IN 0 .. v_bloques - 1 LOOP
                SGCD_PKG_RESERVAS.crear_reserva_torneo(
                    p_id_torneo  => p_id_torneo,
                    p_id_cancha  => p_id_cancha,
                    p_fecha      => p_fecha,
                    p_hora_desde => TO_CHAR(v_desde + i / 24, 'HH24:MI'),
                    p_bloques    => 1,
                    p_id_reserva => v_id_reserva);
            END LOOP;
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK TO antes_de_programar;
                RAISE;
        END;
    END programar_torneo;


    PROCEDURE listar_torneos(
        p_id_modalidad NUMBER DEFAULT NULL,
        p_estado       VARCHAR2 DEFAULT NULL,
        p_id_cliente   NUMBER DEFAULT NULL,
        p_cursor       OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT t.ID_TORNEO, t.NOMBRE_TORNEO,
                   t.ID_MODALIDAD, m.NOMBRE_MODALIDAD,
                   t.FECHA_INICIO, t.FECHA_TERMINO,
                   t.CUPOS_TORNEO,
                   (SELECT COUNT(*) FROM SGCD_INSCRIPCIONES_TORNEO i
                    WHERE i.ID_TORNEO = t.ID_TORNEO
                      AND i.ESTADO_INSCRIPCION = 'INSCRITO') AS INSCRITOS,
                   t.MAX_JUGADORES_POR_EQUIPO, t.ESTADO_TORNEO,
                   (SELECT MAX(i.ID_INSCRIPCION) FROM SGCD_INSCRIPCIONES_TORNEO i
                    WHERE i.ID_TORNEO = t.ID_TORNEO
                      AND i.ESTADO_INSCRIPCION = 'INSCRITO'
                      AND i.ID_CLIENTE = p_id_cliente) AS MI_INSCRIPCION
            FROM   SGCD_TORNEOS t
            JOIN   SGCD_MODALIDADES m ON m.ID_MODALIDAD = t.ID_MODALIDAD
            WHERE  (p_id_modalidad IS NULL OR t.ID_MODALIDAD = p_id_modalidad)
              AND  (p_estado IS NULL OR t.ESTADO_TORNEO = p_estado)
            ORDER  BY t.FECHA_INICIO, t.NOMBRE_TORNEO;
    END listar_torneos;

    PROCEDURE listar_inscripciones(
        p_id_torneo  NUMBER DEFAULT NULL,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT i.ID_INSCRIPCION, i.ID_TORNEO, t.NOMBRE_TORNEO,
                   i.NOMBRE_EQUIPO, i.CANTIDAD_JUGADORES, i.FECHA_INSCRIPCION,
                   i.ESTADO_INSCRIPCION, i.ID_CLIENTE, c.NOMBRE_CLIENTE AS CAPITAN
            FROM   SGCD_INSCRIPCIONES_TORNEO i
            JOIN   SGCD_TORNEOS t ON t.ID_TORNEO = i.ID_TORNEO
            JOIN   SGCD_CLIENTES c ON c.ID_CLIENTE = i.ID_CLIENTE
            WHERE  (p_id_torneo IS NULL OR i.ID_TORNEO = p_id_torneo)
              AND  (p_id_cliente IS NULL OR i.ID_CLIENTE = p_id_cliente)
            ORDER  BY i.FECHA_INSCRIPCION DESC, i.NOMBRE_EQUIPO;
    END listar_inscripciones;

    PROCEDURE inscripcion(
        p_id_inscripcion NUMBER,
        p_cursor         OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT i.ID_INSCRIPCION, i.ID_TORNEO, t.NOMBRE_TORNEO,
                   i.NOMBRE_EQUIPO, i.ID_CLIENTE, c.NOMBRE_CLIENTE AS CAPITAN,
                   i.CANTIDAD_JUGADORES, i.FECHA_INSCRIPCION,
                   i.ESTADO_INSCRIPCION, t.MAX_JUGADORES_POR_EQUIPO
            FROM   SGCD_INSCRIPCIONES_TORNEO i
            JOIN   SGCD_TORNEOS t ON t.ID_TORNEO = i.ID_TORNEO
            JOIN   SGCD_CLIENTES c ON c.ID_CLIENTE = i.ID_CLIENTE
            WHERE  i.ID_INSCRIPCION = p_id_inscripcion;
    END inscripcion;

    PROCEDURE jugadores_inscripcion(
        p_id_inscripcion NUMBER,
        p_cursor         OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT j.ID_JUGADOR,
                   j.RUT_JUGADOR || '-' || j.DV_JUGADOR AS RUT,
                   j.NOMBRE_JUGADOR
            FROM   SGCD_EQUIPOS_JUGADORES ej
            JOIN   SGCD_JUGADORES j ON j.ID_JUGADOR = ej.ID_JUGADOR
            WHERE  ej.ID_INSCRIPCION = p_id_inscripcion
            ORDER  BY j.NOMBRE_JUGADOR;
    END jugadores_inscripcion;

END SGCD_PKG_TORNEOS;
/
