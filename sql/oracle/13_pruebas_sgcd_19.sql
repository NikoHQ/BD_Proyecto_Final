-- =====================================================================
-- PRUEBAS DEL DDL DE 19 TABLAS Y DE LOS CATALOGOS
-- Ejecutar con 10_ddl_sgcd_19.sql y 11_catalogos_sgcd_19.sql ya cargados.
-- Todo se revierte al final: no deja datos.
--
--   docker exec -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
--     -i oracle-free sqlplus -s -L SGCD/<clave>@localhost/FREEPDB1 \
--     < sql/oracle/13_pruebas_sgcd_19.sql
--
-- Cada linea "OK" es una comprobacion que paso. Al final imprime el total de
-- fallas; 0 significa que el esquema cumple lo acordado.
-- =====================================================================


SET SERVEROUTPUT ON
SET DEFINE OFF


DECLARE
    V_NUM    NUMBER;
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK   ' || P_TEXTO);
    END;

    PROCEDURE FALLA (P_TEXTO VARCHAR2) IS
    BEGIN
        V_FALLAS := V_FALLAS + 1;
        DBMS_OUTPUT.PUT_LINE('FALLA ' || P_TEXTO);
    END;

    PROCEDURE COMPROBAR (P_CONDICION BOOLEAN, P_TEXTO VARCHAR2) IS
    BEGIN
        IF P_CONDICION THEN OK(P_TEXTO); ELSE FALLA(P_TEXTO); END IF;
    END;

    PROCEDURE ESPERAR_ERROR (P_SQL VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_SQL;
        FALLA(P_NOMBRE || ' (se acepto y debia rechazarse)');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE = P_CODIGO THEN
                OK(P_NOMBRE);
            ELSE
                FALLA(P_NOMBRE || ' (ORA-' || SQLCODE || ', se esperaba ORA-' || P_CODIGO || ')');
            END IF;
    END;

BEGIN
    -- 1. Objetos del modelo
    SELECT COUNT(*) INTO V_NUM FROM USER_TABLES WHERE TABLE_NAME LIKE 'SGCD\_%' ESCAPE '\';
    COMPROBAR(V_NUM = 19, 'hay 19 tablas SGCD_ (encontradas: ' || V_NUM || ')');
    SELECT COUNT(*) INTO V_NUM FROM USER_SEQUENCES WHERE SEQUENCE_NAME LIKE 'SGCD\_SEQ\_%' ESCAPE '\';
    COMPROBAR(V_NUM = 16, 'hay 16 secuencias, una por tabla con llave simple (encontradas: ' || V_NUM || ')');
    SELECT COUNT(*) INTO V_NUM FROM USER_TRIGGERS WHERE TRIGGER_NAME LIKE 'TRG_SGCD%' AND STATUS = 'ENABLED';
    COMPROBAR(V_NUM = 18, 'hay 18 triggers habilitados: 16 de llave y 2 de auditoria (encontrados: ' || V_NUM || ')');
    SELECT COUNT(*) INTO V_NUM FROM USER_ERRORS;
    COMPROBAR(V_NUM = 0, 'sin objetos con errores de compilacion (encontrados: ' || V_NUM || ')');

    -- 2. Catalogos
    SELECT COUNT(*) INTO V_NUM FROM SGCD_RECINTOS;
    COMPROBAR(V_NUM = 1, 'un solo recinto');
    SELECT COUNT(*) INTO V_NUM FROM SGCD_CANCHAS WHERE ID_RECINTO = (SELECT MIN(ID_RECINTO) FROM SGCD_RECINTOS);
    COMPROBAR(V_NUM = 10, 'diez canchas en el recinto (encontradas: ' || V_NUM || ')');
    SELECT COUNT(*) INTO V_NUM FROM SGCD_CANCHAS_COMPONENTES WHERE ID_CANCHA_GRANDE = 7;
    COMPROBAR(V_NUM = 3, 'la cancha grande tiene tres componentes');
    SELECT COUNT(*) INTO V_NUM
    FROM   SGCD_CANCHAS_COMPONENTES CC
    WHERE  NOT EXISTS (SELECT 1 FROM SGCD_CANCHAS C
                       WHERE C.ID_CANCHA = CC.ID_CANCHA_PEQUENA AND C.ID_CANCHA BETWEEN 1 AND 3);
    COMPROBAR(V_NUM = 0, 'las componentes de la grande son 1, 2 y 3');
    SELECT COUNT(*) INTO V_NUM
    FROM   SGCD_BLOQUES_HORARIOS B
    JOIN   SGCD_HORARIOS H ON H.ID_HORARIO = B.ID_HORARIO
    WHERE  B.HORA_INICIO < H.HORA_APERTURA OR B.HORA_TERMINO > H.HORA_CIERRE;
    COMPROBAR(V_NUM = 0, 'ningun bloque sale de su ventana de apertura');
    SELECT COUNT(*) INTO V_NUM
    FROM   SGCD_BLOQUES_HORARIOS B
    WHERE  (TO_NUMBER(SUBSTR(B.HORA_TERMINO, 1, 2)) * 60 + TO_NUMBER(SUBSTR(B.HORA_TERMINO, 4, 2)))
         - (TO_NUMBER(SUBSTR(B.HORA_INICIO, 1, 2)) * 60 + TO_NUMBER(SUBSTR(B.HORA_INICIO, 4, 2))) <> 60;
    COMPROBAR(V_NUM = 0, 'todos los bloques miden 60 minutos');
    SELECT COUNT(*) INTO V_NUM
    FROM   (SELECT H.DIA_SEMANA, C.ID_CANCHA FROM SGCD_HORARIOS H CROSS JOIN SGCD_CANCHAS C
            WHERE C.ID_CANCHA BETWEEN 1 AND 10)
    WHERE  NOT EXISTS (SELECT 1 FROM SGCD_TARIFAS T
                       WHERE T.ID_CANCHA = ID_CANCHA AND T.DIA_SEMANA = DIA_SEMANA);
    COMPROBAR(V_NUM = 0, 'cada cancha tiene tarifa en cada dia abierto');

    -- 3. La llave la genera el trigger, no la aplicacion
    INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA)
    VALUES (1, 'Cancha de prueba', 'FUTBOL_6');
    SELECT COUNT(*) INTO V_NUM FROM SGCD_CANCHAS WHERE NOMBRE_CANCHA = 'Cancha de prueba' AND ID_CANCHA > 10;
    COMPROBAR(V_NUM = 1, 'el trigger asigna ID a una cancha creada sin ID');

    -- 4. Auditoria: solo los campos que cambian, con el administrador de la sesion
    DBMS_SESSION.SET_IDENTIFIER('1');
    UPDATE SGCD_CLIENTES
    SET    NOMBRE_CLIENTE = 'Nombre auditado', TELEFONO_CLIENTE = NULL
    WHERE  ID_CLIENTE = 1;
    SELECT COUNT(*) INTO V_NUM
    FROM   SGCD_AUDITORIA_CLIENTES
    WHERE  ID_CLIENTE = 1 AND ACCION = 'UPDATE' AND ID_ADMINISTRADOR = 1
      AND  VALORES_ANTERIORES LIKE '%"nombre"%'
      AND  VALORES_ANTERIORES NOT LIKE '%"correo"%'
      AND  VALORES_NUEVOS LIKE '%"telefono":null%';
    COMPROBAR(V_NUM = 1, 'la auditoria de UPDATE guarda solo los campos cambiados y el administrador');
    UPDATE SGCD_CLIENTES SET NOMBRE_CLIENTE = 'Nombre auditado' WHERE ID_CLIENTE = 1;
    SELECT COUNT(*) INTO V_NUM FROM SGCD_AUDITORIA_CLIENTES WHERE ID_CLIENTE = 1 AND ACCION = 'UPDATE';
    COMPROBAR(V_NUM = 1, 'un UPDATE sin cambios no genera auditoria');

    -- 5. Auditoria: el borrado guarda el retrato previo
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE, CORREO_CLIENTE, TELEFONO_CLIENTE)
    VALUES (99999999, '9', 'Borrado auditado', 'borrado@demo.cl', '+56 9 0000 0000');
    DELETE FROM SGCD_CLIENTES WHERE RUT_CLIENTE = 99999999;
    SELECT COUNT(*) INTO V_NUM
    FROM   SGCD_AUDITORIA_CLIENTES
    WHERE  ACCION = 'DELETE' AND VALORES_NUEVOS IS NULL
      AND  VALORES_ANTERIORES LIKE '%"nombre":"Borrado auditado"%'
      AND  VALORES_ANTERIORES LIKE '%"estado":"ACTIVO"%';
    COMPROBAR(V_NUM = 1, 'la auditoria de DELETE guarda el retrato completo sin valores nuevos');

    -- 6. Reglas del modelo que el DDL hace cumplir
    ESPERAR_ERROR(
        'INSERT INTO SGCD_USUARIOS (LOGIN, CLAVE_HASH, ROL) VALUES (''operador'', ''x'', ''OPERADOR'')',
        -2290, 'rechaza un rol fuera de ADMINISTRADOR/CLIENTE');
    ESPERAR_ERROR(
        'INSERT INTO SGCD_CANCHAS_COMPONENTES (ID_CANCHA_GRANDE, ID_CANCHA_PEQUENA) VALUES (7, 1)',
        -1, 'rechaza que la cancha 1 pertenezca a dos canchas grandes');
    ESPERAR_ERROR(
        'INSERT INTO SGCD_RESERVAS (ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA, IMPORTE_ACORDADO) VALUES (1, 1, DATE ''2026-11-24'' + 10/24, DATE ''2026-11-24'' + 11/24, 18000)',
        -2290, 'rechaza una reserva sin cliente y sin torneo');
    ESPERAR_ERROR(
        'INSERT INTO SGCD_AUDITORIA_CLIENTES (ID_CLIENTE, ACCION, VALORES_ANTERIORES) VALUES (1, ''UPDATE'', ''sin llaves'')',
        -2290, 'rechaza un registro de auditoria que no sea JSON');

    -- 7. Bloque ocupado: una sola reserva viva por cancha e inicio
    INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                               IMPORTE_ACORDADO, ESTADO_RESERVA)
    VALUES (1, 4, 1, DATE '2026-11-24' + 12/24, DATE '2026-11-24' + 13/24, 18000, 'CONFIRMADA');
    ESPERAR_ERROR(
        'INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA, IMPORTE_ACORDADO, ESTADO_RESERVA) VALUES (2, 4, 1, DATE ''2026-11-24'' + 12/24, DATE ''2026-11-24'' + 13/24, 18000, ''CONFIRMADA'')',
        -1, 'rechaza dos reservas vivas del mismo bloque en la misma cancha');
    UPDATE SGCD_RESERVAS
    SET    ESTADO_RESERVA = 'CANCELADA'
    WHERE  ID_CANCHA = 4 AND INICIO_RESERVA = DATE '2026-11-24' + 12/24;
    INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                               IMPORTE_ACORDADO, ESTADO_RESERVA)
    VALUES (2, 4, 1, DATE '2026-11-24' + 12/24, DATE '2026-11-24' + 13/24, 18000, 'CONFIRMADA');
    OK('cancelar libera el bloque: la cancha 4 se puede volver a reservar');

    -- 8. Un solo pago por reserva
    DECLARE
        V_RESERVA NUMBER;
    BEGIN
        INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                   IMPORTE_ACORDADO, ESTADO_RESERVA)
        VALUES (1, 5, 1, DATE '2026-11-25' + 9/24, DATE '2026-11-25' + 10/24, 18000, 'CONFIRMADA')
        RETURNING ID_RESERVA INTO V_RESERVA;
        INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO) VALUES (V_RESERVA, 18000, 'EFECTIVO');
        ESPERAR_ERROR(
            'INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO) VALUES (' || V_RESERVA || ', 18000, ''DEBITO'')',
            -1, 'rechaza un segundo pago para la misma reserva');
    END;

    -- 9. Limpieza: no deja datos de prueba
    ROLLBACK;

    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/
