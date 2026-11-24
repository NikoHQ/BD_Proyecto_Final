-- =====================================================================
-- Sesion de la prueba de integracion con dos conexiones reales.
-- Requiere el fixture de tests/integracion_dos_sesiones.sh.
-- Se invoca como:  @sesion.sql <caso> <A|B>
--
-- Caso 1: misma cancha (4) y mismo bloque, 10:00.
-- Caso 2: A reserva la grande (7) y B la cancha 1, 11:00.
-- Caso 3: A reserva la cancha 2 y B la grande (7), 12:00.
-- Caso 4: A y B pelean el ultimo cupo del torneo CONCURRENCIA CUPO.
-- Caso 5: A y B cobran la misma reserva de las 13:00.
--
-- A hace la operacion, duerme y recien despues confirma: asi la ventana de
-- carrera es real y B espera el candado de la sesion A.
-- =====================================================================


SET SERVEROUTPUT ON SIZE UNLIMITED


DECLARE
    V_CASO   NUMBER := &1;
    V_ROL    VARCHAR2(1) := '&2';
    V_MARTES DATE := TRUNC(SYSDATE, 'IW') + 8;
    V_CLI    NUMBER;
    V_CLI2   NUMBER;
    V_ADMIN  NUMBER;
    V_TORNEO NUMBER;
    V_RES    NUMBER;
    V_CANCHA NUMBER;
    V_ID     NUMBER;
BEGIN
    SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
    FROM   SGCD_ADMINISTRADORES a
    WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';
    SELECT c.ID_CLIENTE INTO V_CLI
    FROM   SGCD_CLIENTES c
    WHERE  c.RUT_CLIENTE = 39000001;

    IF V_CASO = 1 THEN
        BEGIN
            SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '10:00', 1,
                                            'MOSTRADOR', V_ID);
            IF V_ROL = 'A' THEN
                DBMS_SESSION.SLEEP(4);
            END IF;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                DBMS_OUTPUT.PUT_LINE('RESULTADO: ERROR ' || SQLCODE);
        END;

    ELSIF V_CASO = 2 OR V_CASO = 3 THEN
        IF V_CASO = 2 THEN
            V_CANCHA := CASE V_ROL WHEN 'A' THEN 7 ELSE 1 END;
        ELSE
            V_CANCHA := CASE V_ROL WHEN 'A' THEN 2 ELSE 7 END;
        END IF;
        BEGIN
            SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, V_CANCHA, 1, V_MARTES,
                                            CASE V_CASO WHEN 2 THEN '11:00' ELSE '12:00' END,
                                            1, 'MOSTRADOR', V_ID);
            IF V_ROL = 'A' THEN
                DBMS_SESSION.SLEEP(4);
            END IF;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                DBMS_OUTPUT.PUT_LINE('RESULTADO: ERROR ' || SQLCODE);
        END;

    ELSIF V_CASO = 4 THEN
        SELECT t.ID_TORNEO INTO V_TORNEO
        FROM   SGCD_TORNEOS t
        WHERE  t.NOMBRE_TORNEO = 'CONCURRENCIA CUPO';
        IF V_ROL = 'A' THEN
            SELECT c.ID_CLIENTE INTO V_CLI2 FROM SGCD_CLIENTES c WHERE c.RUT_CLIENTE = 39000002;
        ELSE
            SELECT c.ID_CLIENTE INTO V_CLI2 FROM SGCD_CLIENTES c WHERE c.RUT_CLIENTE = 39000003;
        END IF;
        BEGIN
            SGCD_PKG_TORNEOS.inscribir_equipo(V_TORNEO, V_CLI2,
                                              CASE V_ROL WHEN 'A' THEN 'Equipo A' ELSE 'Equipo B' END,
                                              V_ID);
            IF V_ROL = 'A' THEN
                DBMS_SESSION.SLEEP(4);
            END IF;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                DBMS_OUTPUT.PUT_LINE('RESULTADO: ERROR ' || SQLCODE);
        END;

    ELSIF V_CASO = 5 THEN
        SELECT r.ID_RESERVA INTO V_RES
        FROM   SGCD_RESERVAS r
        WHERE  r.ID_CLIENTE = V_CLI
          AND  r.INICIO_RESERVA = V_MARTES + 13 / 24;
        BEGIN
            SGCD_PKG_PAGOS.registrar_pago(V_RES, 'EFECTIVO', V_ADMIN);
            IF V_ROL = 'A' THEN
                DBMS_SESSION.SLEEP(4);
            END IF;
            COMMIT;
            DBMS_OUTPUT.PUT_LINE('RESULTADO: OK');
        EXCEPTION
            WHEN OTHERS THEN
                ROLLBACK;
                DBMS_OUTPUT.PUT_LINE('RESULTADO: ERROR ' || SQLCODE);
        END;
    END IF;
END;
/
