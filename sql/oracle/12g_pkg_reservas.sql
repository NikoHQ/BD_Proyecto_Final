-- =====================================================================
-- SGCD_PKG_RESERVAS - reservas por bloques consecutivos de una hora
-- Requiere: 10_ddl_sgcd_19.sql, 11_catalogos_sgcd_19.sql y 12f_pkg_tarifas.sql
--
-- Reglas:
--  * Una reserva ocupa [INICIO, TERMINO) y choca con cualquier reserva no
--    CANCELADA de la misma cancha, no solo con el mismo inicio.
--  * La cancha grande y sus componentes 1-2-3 se excluyen en ambos sentidos:
--    reservar la grande ocupa las tres pequenas y reservar una pequena ocupa
--    la grande.
--  * Los candados se toman siempre en orden ascendente de ID_CANCHA para que
--    dos sesiones que pelean el grupo grande no se crucen en deadlock.
--  * MOSTRADOR nace CONFIRMADA y exige administrador; WEB nace PENDIENTE y
--    retiene el bloque hasta que se confirme o se cancele.
--  * No se reserva en el pasado ni mas alla de C_HORIZONTE_DIAS.
--  * El precio es una tarifa por hora cobrada con SGCD_PKG_TARIFAS; si falta
--    la tarifa de un bloque se falla, no se cotiza a medias.
--  * COMPLETADA no se escribe sola: marcar_completadas cierra las CONFIRMADA
--    cuyo termino ya paso. Las CANCELADA no se tocan.
--
-- Las reservas de torneo entran por crear_reserva_torneo: toman la modalidad
-- del torneo, no llevan cliente y nacen CONFIRMADA. SGCD_PKG_TORNEOS las crea
-- por esa puerta y no inserta en SGCD_RESERVAS por su cuenta.
--
-- agenda entrega el detalle del calendario para el panel y el portal: incluye
-- todos los estados, y las canceladas se distinguen por su ESTADO_RESERVA.
--
-- Codigos: -20040 datos invalidos, -20041 cancha o modalidad invalida,
-- -20042 fuera de horario, -20043 choque de horario, -20044 fecha u hora
-- fuera de rango, -20045 cliente o administrador no habilitado, -20046 el
-- estado no permite la operacion, -20047 la reserva no existe, -20060 falta
-- el torneo, -20061 el torneo no existe, -20062 su estado no admite bloques.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_RESERVAS AS
    FUNCTION disponible(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER) RETURN NUMBER;
    PROCEDURE agenda(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cancha  NUMBER DEFAULT NULL,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR);
    PROCEDURE crear_reserva(
        p_id_cliente       NUMBER,
        p_id_administrador NUMBER,
        p_id_cancha        NUMBER,
        p_id_modalidad     NUMBER,
        p_fecha            DATE,
        p_hora_desde       VARCHAR2,
        p_bloques          NUMBER,
        p_origen           VARCHAR2,
        p_id_reserva       OUT NUMBER);
    PROCEDURE crear_solicitud_web(
        p_id_cliente   NUMBER,
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER,
        p_id_reserva   OUT NUMBER);
    PROCEDURE crear_reserva_torneo(
        p_id_torneo  NUMBER,
        p_id_cancha  NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_bloques    NUMBER,
        p_id_reserva OUT NUMBER);
    PROCEDURE confirmar_reserva(p_id_reserva NUMBER);
    PROCEDURE cancelar_reserva(p_id_reserva NUMBER);
    PROCEDURE reprogramar_reserva(
        p_id_reserva NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_bloques    NUMBER);
    FUNCTION marcar_completadas RETURN NUMBER;
END SGCD_PKG_RESERVAS;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_RESERVAS AS

    C_HORIZONTE_DIAS CONSTANT NUMBER := 90;

    PROCEDURE validar_hora(p_hora VARCHAR2) IS
    BEGIN
        IF p_hora IS NULL
           OR NOT REGEXP_LIKE(TRIM(p_hora), '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
            RAISE_APPLICATION_ERROR(-20040, 'La hora debe venir en formato HH:MI');
        END IF;
    END validar_hora;

    FUNCTION hora_fecha(p_fecha DATE, p_hora VARCHAR2) RETURN DATE IS
    BEGIN
        RETURN TRUNC(p_fecha)
               + (TO_NUMBER(SUBSTR(p_hora, 1, 2)) * 60 + TO_NUMBER(SUBSTR(p_hora, 4, 2))) / 1440;
    END hora_fecha;

    PROCEDURE validar_fecha(p_fecha DATE) IS
    BEGIN
        IF p_fecha IS NULL THEN
            RAISE_APPLICATION_ERROR(-20040, 'Falta la fecha de la reserva');
        END IF;
        IF TRUNC(p_fecha) < TRUNC(SYSDATE) THEN
            RAISE_APPLICATION_ERROR(-20044, 'No se puede reservar en una fecha pasada');
        END IF;
        IF TRUNC(p_fecha) > TRUNC(SYSDATE) + C_HORIZONTE_DIAS THEN
            RAISE_APPLICATION_ERROR(-20044,
                'Solo se reserva hasta ' || C_HORIZONTE_DIAS || ' dias hacia adelante');
        END IF;
    END validar_fecha;

    PROCEDURE validar_cliente(p_id_cliente NUMBER) IS
        v_n NUMBER;
    BEGIN
        IF p_id_cliente IS NULL THEN
            RAISE_APPLICATION_ERROR(-20045, 'La reserva necesita un cliente');
        END IF;
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_CLIENTES c
        WHERE  c.ID_CLIENTE = p_id_cliente
          AND  c.ESTADO_CLIENTE = 'ACTIVO';
        IF v_n = 0 THEN
            RAISE_APPLICATION_ERROR(-20045, 'El cliente no existe o esta inactivo');
        END IF;
    END validar_cliente;

    PROCEDURE validar_administrador(p_id_administrador NUMBER) IS
        v_n NUMBER;
    BEGIN
        IF p_id_administrador IS NULL THEN
            RAISE_APPLICATION_ERROR(-20045, 'La reserva de mostrador necesita un administrador');
        END IF;
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_ADMINISTRADORES a
        WHERE  a.ID_ADMINISTRADOR = p_id_administrador
          AND  a.ESTADO_ADMINISTRADOR = 'ACTIVO';
        IF v_n = 0 THEN
            RAISE_APPLICATION_ERROR(-20045, 'El administrador no existe o esta inactivo');
        END IF;
    END validar_administrador;

    PROCEDURE validar_origen(p_origen VARCHAR2) IS
    BEGIN
        IF p_origen IS NULL OR p_origen NOT IN ('MOSTRADOR', 'WEB') THEN
            RAISE_APPLICATION_ERROR(-20040, 'El origen debe ser MOSTRADOR o WEB');
        END IF;
    END validar_origen;

    PROCEDURE validar_cancha_modalidad(p_id_cancha NUMBER, p_id_modalidad NUMBER) IS
        v_n NUMBER;
    BEGIN
        IF p_id_cancha IS NULL OR p_id_modalidad IS NULL THEN
            RAISE_APPLICATION_ERROR(-20041, 'Falta la cancha o la modalidad');
        END IF;
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_CANCHAS_MODALIDADES cm
        WHERE  cm.ID_CANCHA = p_id_cancha
          AND  cm.ID_MODALIDAD = p_id_modalidad;
        IF v_n = 0 THEN
            RAISE_APPLICATION_ERROR(-20041, 'La cancha no admite esa modalidad');
        END IF;
    END validar_cancha_modalidad;

    PROCEDURE calcular_ventana(
        p_id_cancha  NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_bloques    NUMBER,
        p_inicio     OUT DATE,
        p_termino    OUT DATE) IS
        v_hora    VARCHAR2(5);
        v_dia     NUMBER;
        v_horario NUMBER;
        v_apertura CHAR(5);
        v_cierre   CHAR(5);
        v_inicio  DATE;
        v_termino DATE;
        v_bloques_en_ventana NUMBER;
    BEGIN
        IF p_bloques IS NULL OR p_bloques < 1 OR p_bloques <> TRUNC(p_bloques) THEN
            RAISE_APPLICATION_ERROR(-20040, 'La cantidad de bloques debe ser un entero mayor que cero');
        END IF;
        v_hora := TRIM(p_hora_desde);
        validar_hora(v_hora);

        v_dia := TRUNC(p_fecha) - TRUNC(p_fecha, 'IW') + 1;
        BEGIN
            SELECT h.ID_HORARIO, h.HORA_APERTURA, h.HORA_CIERRE
            INTO   v_horario, v_apertura, v_cierre
            FROM   SGCD_HORARIOS h
            JOIN   SGCD_CANCHAS c ON c.ID_RECINTO = h.ID_RECINTO
            WHERE  c.ID_CANCHA = p_id_cancha
              AND  h.DIA_SEMANA = v_dia;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20042, 'El recinto no abre ese dia');
        END;

        v_inicio  := hora_fecha(p_fecha, v_hora);
        v_termino := v_inicio + p_bloques / 24;
        IF v_inicio < hora_fecha(p_fecha, v_apertura)
           OR v_termino > hora_fecha(p_fecha, v_cierre) THEN
            RAISE_APPLICATION_ERROR(-20042, 'La reserva se sale del horario del recinto');
        END IF;
        IF v_inicio <= SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20044, 'La hora de inicio ya paso');
        END IF;

        SELECT COUNT(*) INTO v_bloques_en_ventana
        FROM   SGCD_BLOQUES_HORARIOS b
        WHERE  b.ID_HORARIO = v_horario
          AND  b.HORA_INICIO BETWEEN v_hora AND TO_CHAR(v_termino - 1 / 1440, 'HH24:MI');
        IF v_bloques_en_ventana <> p_bloques THEN
            RAISE_APPLICATION_ERROR(-20042, 'La reserva debe empezar en un bloque y no salirse de la ultima franja');
        END IF;

        p_inicio  := v_inicio;
        p_termino := v_termino;
    END calcular_ventana;

    FUNCTION reservas_en_conflicto(
        p_id_cancha NUMBER,
        p_inicio    DATE,
        p_termino   DATE,
        p_ignorar   NUMBER DEFAULT NULL) RETURN NUMBER IS
        v_ocupadas NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_ocupadas
        FROM   SGCD_RESERVAS r
        WHERE  r.ESTADO_RESERVA <> 'CANCELADA'
          AND  (p_ignorar IS NULL OR r.ID_RESERVA <> p_ignorar)
          AND  r.INICIO_RESERVA < p_termino
          AND  r.TERMINO_RESERVA > p_inicio
          AND  (r.ID_CANCHA = p_id_cancha
                OR r.ID_CANCHA IN (SELECT cc.ID_CANCHA_PEQUENA
                                   FROM   SGCD_CANCHAS_COMPONENTES cc
                                   WHERE  cc.ID_CANCHA_GRANDE = p_id_cancha)
                OR r.ID_CANCHA IN (SELECT cc.ID_CANCHA_GRANDE
                                   FROM   SGCD_CANCHAS_COMPONENTES cc
                                   WHERE  cc.ID_CANCHA_PEQUENA = p_id_cancha));
        RETURN v_ocupadas;
    END reservas_en_conflicto;

    PROCEDURE bloquear_canchas(
        p_id_cancha NUMBER,
        p_inicio    DATE,
        p_termino   DATE,
        p_ignorar   NUMBER) IS
        v_estado VARCHAR2(15);
    BEGIN
        FOR r IN (
            SELECT c.ID_CANCHA
            FROM   SGCD_CANCHAS c
            WHERE  c.ID_CANCHA = p_id_cancha
               OR  c.ID_CANCHA IN (SELECT cc.ID_CANCHA_PEQUENA
                                   FROM   SGCD_CANCHAS_COMPONENTES cc
                                   WHERE  cc.ID_CANCHA_GRANDE = p_id_cancha)
               OR  c.ID_CANCHA IN (SELECT cc.ID_CANCHA_GRANDE
                                   FROM   SGCD_CANCHAS_COMPONENTES cc
                                   WHERE  cc.ID_CANCHA_PEQUENA = p_id_cancha)
            ORDER BY c.ID_CANCHA
        ) LOOP
            SELECT c.ESTADO_CANCHA INTO v_estado
            FROM   SGCD_CANCHAS c
            WHERE  c.ID_CANCHA = r.ID_CANCHA
            FOR UPDATE;
            IF v_estado <> 'DISPONIBLE' THEN
                RAISE_APPLICATION_ERROR(-20041, 'La cancha no esta disponible');
            END IF;
        END LOOP;

        IF reservas_en_conflicto(p_id_cancha, p_inicio, p_termino, p_ignorar) > 0 THEN
            RAISE_APPLICATION_ERROR(-20043, 'La cancha ya esta reservada en ese horario');
        END IF;
    END bloquear_canchas;

    FUNCTION cotizar_bloques(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_inicio       DATE,
        p_bloques      NUMBER) RETURN NUMBER IS
        v_total NUMBER(12,2) := 0;
    BEGIN
        FOR i IN 0 .. p_bloques - 1 LOOP
            v_total := v_total + SGCD_PKG_TARIFAS.valor_bloque(
                p_id_cancha, p_id_modalidad, p_fecha, TO_CHAR(p_inicio + i / 24, 'HH24:MI'));
        END LOOP;
        RETURN v_total;
    END cotizar_bloques;

    FUNCTION disponible(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER) RETURN NUMBER IS
        v_inicio  DATE;
        v_termino DATE;
    BEGIN
        validar_fecha(p_fecha);
        validar_cancha_modalidad(p_id_cancha, p_id_modalidad);
        calcular_ventana(p_id_cancha, p_fecha, p_hora_desde, p_bloques, v_inicio, v_termino);
        IF reservas_en_conflicto(p_id_cancha, v_inicio, v_termino) > 0 THEN
            RETURN 0;
        END IF;
        RETURN 1;
    EXCEPTION
        WHEN OTHERS THEN
            RETURN 0;
    END disponible;

    PROCEDURE agenda(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cancha  NUMBER DEFAULT NULL,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR) IS
    BEGIN
        IF p_desde IS NULL OR p_hasta IS NULL OR TRUNC(p_hasta) < TRUNC(p_desde) THEN
            RAISE_APPLICATION_ERROR(-20044, 'El rango de la agenda no es valido');
        END IF;
        OPEN p_cursor FOR
            SELECT r.ID_RESERVA, r.INICIO_RESERVA, r.TERMINO_RESERVA,
                   r.ID_CANCHA, c.NOMBRE_CANCHA,
                   r.ID_MODALIDAD, m.NOMBRE_MODALIDAD,
                   r.ID_CLIENTE, cl.NOMBRE_CLIENTE,
                   r.ID_TORNEO, t.NOMBRE_TORNEO,
                   r.ORIGEN_RESERVA, r.ESTADO_RESERVA, r.IMPORTE_ACORDADO
            FROM   SGCD_RESERVAS r
            JOIN   SGCD_CANCHAS c ON c.ID_CANCHA = r.ID_CANCHA
            JOIN   SGCD_MODALIDADES m ON m.ID_MODALIDAD = r.ID_MODALIDAD
            LEFT   JOIN SGCD_CLIENTES cl ON cl.ID_CLIENTE = r.ID_CLIENTE
            LEFT   JOIN SGCD_TORNEOS t ON t.ID_TORNEO = r.ID_TORNEO
            WHERE  r.INICIO_RESERVA >= TRUNC(p_desde)
              AND  r.INICIO_RESERVA < TRUNC(p_hasta) + 1
              AND  (p_id_cancha IS NULL OR r.ID_CANCHA = p_id_cancha)
              AND  (p_id_cliente IS NULL OR r.ID_CLIENTE = p_id_cliente)
            ORDER  BY r.INICIO_RESERVA, c.NOMBRE_CANCHA;
    END agenda;

    PROCEDURE insertar_reserva(
        p_id_cliente       NUMBER,
        p_id_administrador NUMBER,
        p_id_torneo        NUMBER,
        p_id_cancha        NUMBER,
        p_id_modalidad     NUMBER,
        p_fecha            DATE,
        p_hora_desde       VARCHAR2,
        p_bloques          NUMBER,
        p_origen           VARCHAR2,
        p_estado           VARCHAR2,
        p_id_reserva       OUT NUMBER) IS
        v_inicio  DATE;
        v_termino DATE;
        v_total   NUMBER(12,2);
    BEGIN
        validar_cancha_modalidad(p_id_cancha, p_id_modalidad);
        validar_fecha(p_fecha);
        calcular_ventana(p_id_cancha, p_fecha, p_hora_desde, p_bloques, v_inicio, v_termino);
        bloquear_canchas(p_id_cancha, v_inicio, v_termino, NULL);
        v_total := cotizar_bloques(p_id_cancha, p_id_modalidad, p_fecha, v_inicio, p_bloques);

        INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_ADMINISTRADOR, ID_TORNEO, ID_CANCHA,
                                   ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                   IMPORTE_ACORDADO, ORIGEN_RESERVA, ESTADO_RESERVA)
        VALUES (p_id_cliente, p_id_administrador, p_id_torneo, p_id_cancha,
                p_id_modalidad, v_inicio, v_termino, v_total, p_origen, p_estado)
        RETURNING ID_RESERVA INTO p_id_reserva;
    END insertar_reserva;

    PROCEDURE crear_reserva(
        p_id_cliente       NUMBER,
        p_id_administrador NUMBER,
        p_id_cancha        NUMBER,
        p_id_modalidad     NUMBER,
        p_fecha            DATE,
        p_hora_desde       VARCHAR2,
        p_bloques          NUMBER,
        p_origen           VARCHAR2,
        p_id_reserva       OUT NUMBER) IS
        v_estado VARCHAR2(15);
    BEGIN
        validar_origen(p_origen);
        IF p_origen = 'MOSTRADOR' THEN
            validar_administrador(p_id_administrador);
            v_estado := 'CONFIRMADA';
        ELSE
            IF p_id_administrador IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20040, 'Una solicitud web no lleva administrador');
            END IF;
            v_estado := 'PENDIENTE';
        END IF;
        validar_cliente(p_id_cliente);
        insertar_reserva(p_id_cliente, p_id_administrador, NULL, p_id_cancha, p_id_modalidad,
                         p_fecha, p_hora_desde, p_bloques, p_origen, v_estado, p_id_reserva);
    END crear_reserva;

    PROCEDURE crear_reserva_torneo(
        p_id_torneo  NUMBER,
        p_id_cancha  NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_bloques    NUMBER,
        p_id_reserva OUT NUMBER) IS
        v_modalidad NUMBER;
        v_estado    VARCHAR2(15);
    BEGIN
        IF p_id_torneo IS NULL THEN
            RAISE_APPLICATION_ERROR(-20060, 'Falta el torneo de la reserva');
        END IF;
        BEGIN
            SELECT t.ID_MODALIDAD, t.ESTADO_TORNEO INTO v_modalidad, v_estado
            FROM   SGCD_TORNEOS t
            WHERE  t.ID_TORNEO = p_id_torneo
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20061, 'El torneo no existe');
        END;
        IF v_estado NOT IN ('PLANIFICADO', 'EN_CURSO') THEN
            RAISE_APPLICATION_ERROR(-20062,
                'Un torneo ' || v_estado || ' no admite bloques');
        END IF;
        insertar_reserva(NULL, NULL, p_id_torneo, p_id_cancha, v_modalidad,
                         p_fecha, p_hora_desde, p_bloques, 'TORNEO', 'CONFIRMADA', p_id_reserva);
    END crear_reserva_torneo;

    PROCEDURE crear_solicitud_web(
        p_id_cliente   NUMBER,
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER,
        p_id_reserva   OUT NUMBER) IS
    BEGIN
        crear_reserva(p_id_cliente, NULL, p_id_cancha, p_id_modalidad,
                      p_fecha, p_hora_desde, p_bloques, 'WEB', p_id_reserva);
    END crear_solicitud_web;

    PROCEDURE confirmar_reserva(p_id_reserva NUMBER) IS
        v_estado VARCHAR2(15);
        v_inicio DATE;
    BEGIN
        IF p_id_reserva IS NULL THEN
            RAISE_APPLICATION_ERROR(-20047, 'Falta el ID de la reserva');
        END IF;
        BEGIN
            SELECT r.ESTADO_RESERVA, r.INICIO_RESERVA INTO v_estado, v_inicio
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20047, 'La reserva no existe');
        END;
        IF v_estado <> 'PENDIENTE' THEN
            RAISE_APPLICATION_ERROR(-20046, 'Solo se confirma una solicitud pendiente');
        END IF;
        IF v_inicio <= SYSDATE THEN
            RAISE_APPLICATION_ERROR(-20044, 'La solicitud ya vencio');
        END IF;
        UPDATE SGCD_RESERVAS SET ESTADO_RESERVA = 'CONFIRMADA'
        WHERE  ID_RESERVA = p_id_reserva;
    END confirmar_reserva;

    PROCEDURE cancelar_reserva(p_id_reserva NUMBER) IS
        v_estado VARCHAR2(15);
    BEGIN
        IF p_id_reserva IS NULL THEN
            RAISE_APPLICATION_ERROR(-20047, 'Falta el ID de la reserva');
        END IF;
        BEGIN
            SELECT r.ESTADO_RESERVA INTO v_estado
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20047, 'La reserva no existe');
        END;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20046, 'La reserva ya esta ' || v_estado);
        END IF;
        UPDATE SGCD_RESERVAS SET ESTADO_RESERVA = 'CANCELADA'
        WHERE  ID_RESERVA = p_id_reserva;
    END cancelar_reserva;

    PROCEDURE reprogramar_reserva(
        p_id_reserva NUMBER,
        p_fecha      DATE,
        p_hora_desde VARCHAR2,
        p_bloques    NUMBER) IS
        v_estado       VARCHAR2(15);
        v_cancha       NUMBER;
        v_modalidad    NUMBER;
        v_importe      NUMBER(12,2);
        v_pagado       NUMBER(12,2);
        v_inicio       DATE;
        v_termino      DATE;
        v_total        NUMBER(12,2);
    BEGIN
        IF p_id_reserva IS NULL THEN
            RAISE_APPLICATION_ERROR(-20047, 'Falta el ID de la reserva');
        END IF;
        BEGIN
            SELECT r.ESTADO_RESERVA, r.ID_CANCHA, r.ID_MODALIDAD, r.IMPORTE_ACORDADO
            INTO   v_estado, v_cancha, v_modalidad, v_importe
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20047, 'La reserva no existe');
        END;
        IF v_estado NOT IN ('PENDIENTE', 'CONFIRMADA') THEN
            RAISE_APPLICATION_ERROR(-20046, 'No se reprograma una reserva ' || v_estado);
        END IF;

        validar_fecha(p_fecha);
        calcular_ventana(v_cancha, p_fecha, p_hora_desde, p_bloques, v_inicio, v_termino);
        bloquear_canchas(v_cancha, v_inicio, v_termino, p_id_reserva);
        v_total := cotizar_bloques(v_cancha, v_modalidad, p_fecha, v_inicio, p_bloques);

        SELECT NVL(SUM(p.IMPORTE_PAGO), 0) INTO v_pagado
        FROM   SGCD_PAGOS p
        WHERE  p.ID_RESERVA = p_id_reserva
          AND  p.ESTADO_PAGO = 'PAGADO';
        -- Lo pagado y el importe ya acordado no se devuelven: el nuevo valor
        -- nunca baja de lo que el cliente ya cubrio.
        v_importe := GREATEST(v_total, v_importe, v_pagado);

        UPDATE SGCD_RESERVAS
        SET    INICIO_RESERVA   = v_inicio,
               TERMINO_RESERVA  = v_termino,
               IMPORTE_ACORDADO = v_importe
        WHERE  ID_RESERVA = p_id_reserva;
    END reprogramar_reserva;

    FUNCTION marcar_completadas RETURN NUMBER IS
        v_cantidad NUMBER;
    BEGIN
        UPDATE SGCD_RESERVAS
        SET    ESTADO_RESERVA = 'COMPLETADA'
        WHERE  ESTADO_RESERVA = 'CONFIRMADA'
          AND  TERMINO_RESERVA < SYSDATE;
        v_cantidad := SQL%ROWCOUNT;
        RETURN v_cantidad;
    END marcar_completadas;

END SGCD_PKG_RESERVAS;
/
