-- =====================================================================
-- SGCD_PKG_PAGOS - un pago por reserva, por adelantado y por el total
-- Requiere: 10_ddl_sgcd_19.sql, 12g_pkg_reservas.sql
--
-- Reglas:
--  * Solo se cobra por adelantado: la reserva debe estar CONFIRMADA. Una
--    solicitud PENDIENTE, una CANCELADA o una COMPLETADA no se cobran.
--  * El importe es exacto: siempre el IMPORTE_ACORDADO de la reserva, sin
--    parciales ni sobrepago.
--  * La tabla tiene un solo pago por reserva (UQ_SGCD_PAGO_RESERVA). Anular
--    conserva la fila y recobrar la reutiliza, sin acumular pagos.
--  * Anular es el mecanismo de devolucion: se admite aunque la reserva este
--    CANCELADA, porque cancelar no devuelve el dinero por si solo.
--  * El bloqueo es siempre reserva y despues pago, para que dos cajas no
--    cobren la misma reserva a la vez.
--  * cobrar_diferencia cubre lo que deja una reprogramacion al alza. Si el
--    importe acordado ya esta cubierto no hace nada y falla -20056.
--
-- Codigos: -20050 datos invalidos, -20051 la reserva no existe, -20052 el
-- estado no admite pago, -20053 ya hay un pago vigente, -20054 no hay pago
-- que cobrar o anular, -20055 el pago ya esta anulado, -20056 no hay
-- diferencia por cobrar, -20057 el administrador no esta habilitado.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_PAGOS AS
    PROCEDURE registrar_pago(
        p_id_reserva       NUMBER,
        p_medio_pago       VARCHAR2,
        p_id_administrador NUMBER);
    PROCEDURE cobrar_diferencia(
        p_id_reserva       NUMBER,
        p_medio_pago       VARCHAR2,
        p_id_administrador NUMBER);
    PROCEDURE anular_pago(
        p_id_reserva       NUMBER,
        p_id_administrador NUMBER);
    FUNCTION pago_de_reserva(p_id_reserva NUMBER) RETURN SYS_REFCURSOR;
    FUNCTION saldo_reserva(p_id_reserva NUMBER) RETURN NUMBER;
END SGCD_PKG_PAGOS;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_PAGOS AS

    PROCEDURE validar_medio(p_medio_pago VARCHAR2) IS
    BEGIN
        IF p_medio_pago IS NULL
           OR UPPER(TRIM(p_medio_pago)) NOT IN ('EFECTIVO', 'DEBITO', 'CREDITO', 'TRANSFERENCIA') THEN
            RAISE_APPLICATION_ERROR(-20050,
                'El medio de pago debe ser EFECTIVO, DEBITO, CREDITO o TRANSFERENCIA');
        END IF;
    END validar_medio;

    PROCEDURE validar_administrador(p_id_administrador NUMBER) IS
        v_n NUMBER;
    BEGIN
        IF p_id_administrador IS NULL THEN
            RAISE_APPLICATION_ERROR(-20057, 'Falta el administrador que cobra');
        END IF;
        SELECT COUNT(*) INTO v_n
        FROM   SGCD_ADMINISTRADORES a
        WHERE  a.ID_ADMINISTRADOR = p_id_administrador
          AND  a.ESTADO_ADMINISTRADOR = 'ACTIVO';
        IF v_n = 0 THEN
            RAISE_APPLICATION_ERROR(-20057, 'El administrador no existe o esta inactivo');
        END IF;
    END validar_administrador;

    PROCEDURE leer_reserva(
        p_id_reserva NUMBER,
        p_estado     OUT VARCHAR2,
        p_importe    OUT NUMBER) IS
    BEGIN
        IF p_id_reserva IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050, 'Falta el ID de la reserva');
        END IF;
        BEGIN
            SELECT r.ESTADO_RESERVA, r.IMPORTE_ACORDADO
            INTO   p_estado, p_importe
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20051, 'La reserva no existe');
        END;
    END leer_reserva;

    PROCEDURE registrar_pago(
        p_id_reserva       NUMBER,
        p_medio_pago       VARCHAR2,
        p_id_administrador NUMBER) IS
        v_estado        VARCHAR2(15);
        v_acordado      NUMBER(12,2);
        v_id_pago       NUMBER;
        v_estado_pago   VARCHAR2(15);
    BEGIN
        validar_medio(p_medio_pago);
        validar_administrador(p_id_administrador);
        leer_reserva(p_id_reserva, v_estado, v_acordado);
        IF v_estado <> 'CONFIRMADA' THEN
            RAISE_APPLICATION_ERROR(-20052,
                'Solo se cobra por adelantado una reserva confirmada');
        END IF;

        BEGIN
            SELECT p.ID_PAGO, p.ESTADO_PAGO INTO v_id_pago, v_estado_pago
            FROM   SGCD_PAGOS p
            WHERE  p.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_id_pago := NULL;
        END;

        IF v_id_pago IS NULL THEN
            INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO, ESTADO_PAGO)
            VALUES (p_id_reserva, v_acordado, UPPER(TRIM(p_medio_pago)), 'PAGADO');
        ELSE
            IF v_estado_pago = 'PAGADO' THEN
                RAISE_APPLICATION_ERROR(-20053, 'La reserva ya tiene un pago vigente');
            END IF;
            UPDATE SGCD_PAGOS
            SET    IMPORTE_PAGO = v_acordado,
                   FECHA_PAGO  = SYSDATE,
                   MEDIO_PAGO  = UPPER(TRIM(p_medio_pago)),
                   ESTADO_PAGO = 'PAGADO'
            WHERE  ID_PAGO = v_id_pago;
        END IF;
    END registrar_pago;

    PROCEDURE cobrar_diferencia(
        p_id_reserva       NUMBER,
        p_medio_pago       VARCHAR2,
        p_id_administrador NUMBER) IS
        v_estado      VARCHAR2(15);
        v_acordado    NUMBER(12,2);
        v_id_pago     NUMBER;
        v_pagado      NUMBER(12,2);
        v_estado_pago VARCHAR2(15);
    BEGIN
        validar_medio(p_medio_pago);
        validar_administrador(p_id_administrador);
        leer_reserva(p_id_reserva, v_estado, v_acordado);
        IF v_estado <> 'CONFIRMADA' THEN
            RAISE_APPLICATION_ERROR(-20052,
                'Solo se cobra por adelantado una reserva confirmada');
        END IF;

        BEGIN
            SELECT p.ID_PAGO, p.IMPORTE_PAGO, p.ESTADO_PAGO
            INTO   v_id_pago, v_pagado, v_estado_pago
            FROM   SGCD_PAGOS p
            WHERE  p.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20054, 'La reserva no tiene un pago que cobrar');
        END;
        IF v_estado_pago <> 'PAGADO' THEN
            RAISE_APPLICATION_ERROR(-20054, 'El pago esta anulado: se registra uno nuevo');
        END IF;
        IF v_acordado <= v_pagado THEN
            RAISE_APPLICATION_ERROR(-20056, 'No hay diferencia por cobrar');
        END IF;

        UPDATE SGCD_PAGOS
        SET    IMPORTE_PAGO = v_acordado,
               FECHA_PAGO  = SYSDATE,
               MEDIO_PAGO  = UPPER(TRIM(p_medio_pago))
        WHERE  ID_PAGO = v_id_pago;
    END cobrar_diferencia;

    PROCEDURE anular_pago(
        p_id_reserva       NUMBER,
        p_id_administrador NUMBER) IS
        v_estado      VARCHAR2(15);
        v_acordado    NUMBER(12,2);
        v_estado_pago VARCHAR2(15);
    BEGIN
        validar_administrador(p_id_administrador);
        -- Bloquear la reserva aunque este cancelada: anular es el reembolso
        leer_reserva(p_id_reserva, v_estado, v_acordado);

        BEGIN
            SELECT p.ESTADO_PAGO INTO v_estado_pago
            FROM   SGCD_PAGOS p
            WHERE  p.ID_RESERVA = p_id_reserva
            FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20054, 'La reserva no tiene un pago que anular');
        END;
        IF v_estado_pago = 'ANULADO' THEN
            RAISE_APPLICATION_ERROR(-20055, 'El pago ya esta anulado');
        END IF;

        UPDATE SGCD_PAGOS SET ESTADO_PAGO = 'ANULADO'
        WHERE  ID_RESERVA = p_id_reserva;
    END anular_pago;

    FUNCTION pago_de_reserva(p_id_reserva NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        OPEN v_cursor FOR
            SELECT p.ID_PAGO, p.ID_RESERVA, p.IMPORTE_PAGO, p.FECHA_PAGO,
                   p.MEDIO_PAGO, p.ESTADO_PAGO, r.IMPORTE_ACORDADO,
                   r.IMPORTE_ACORDADO
                   - CASE WHEN p.ESTADO_PAGO = 'PAGADO' THEN p.IMPORTE_PAGO ELSE 0 END AS SALDO
            FROM   SGCD_PAGOS p
            JOIN   SGCD_RESERVAS r ON r.ID_RESERVA = p.ID_RESERVA
            WHERE  p.ID_RESERVA = p_id_reserva;
        RETURN v_cursor;
    END pago_de_reserva;

    FUNCTION saldo_reserva(p_id_reserva NUMBER) RETURN NUMBER IS
        v_acordado NUMBER(12,2);
        v_pagado   NUMBER(12,2);
    BEGIN
        IF p_id_reserva IS NULL THEN
            RAISE_APPLICATION_ERROR(-20050, 'Falta el ID de la reserva');
        END IF;
        BEGIN
            SELECT r.IMPORTE_ACORDADO INTO v_acordado
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_RESERVA = p_id_reserva;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20051, 'La reserva no existe');
        END;
        SELECT NVL(SUM(p.IMPORTE_PAGO), 0) INTO v_pagado
        FROM   SGCD_PAGOS p
        WHERE  p.ID_RESERVA = p_id_reserva
          AND  p.ESTADO_PAGO = 'PAGADO';
        RETURN v_acordado - v_pagado;
    END saldo_reserva;

END SGCD_PKG_PAGOS;
/
