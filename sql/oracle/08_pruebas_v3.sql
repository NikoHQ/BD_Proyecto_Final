-- =====================================================================
-- SGCD - PRUEBAS DE LA v3
-- Seccion 1: ficha de cliente (crear, actualizar, estado, borrar) y la
--            auditoria que escriben los triggers de monitoreo
-- Seccion 2: errores esperados de SGCD_PKG_CLIENTES
-- Seccion 3: reportes de SGCD_PKG_CONSULTAS
--
-- Requiere: 04_ddl_v3.sql, 05_paquetes_plsql.sql y 06_catalogos_v3.sql.
-- Todas las secciones revierten sus datos. La auditoria confirmada permanece.
-- Ejecutar con SQLBLANKLINES ON. Los bloques de la seccion 3 van uno por uno.
-- =====================================================================


SET DEFINE OFF
SET SERVEROUTPUT ON


-- =====================================================================
-- 1. CRUD de la ficha + auditoria (un solo bloque, revierte al final)
-- =====================================================================
DECLARE
    V_ID      NUMBER;
    V_ID2     NUMBER;
    V_N       NUMBER;
    V_M       NUMBER;
    V_ESTADO  SGCD_CLIENTES.ESTADO_CLIENTE%TYPE;
BEGIN
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES
    WHERE RUT_CLIENTE IN (99999999, 99999998);
    IF V_N > 0 THEN
        RAISE_APPLICATION_ERROR(-20990, 'RUT de prueba ocupados: limpiar el esquema');
    END IF;

    -- El operador de la sesion queda en la auditoria (lo fija la web al entrar).
    DBMS_SESSION.SET_IDENTIFIER('2');

    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999999, '9', 'ORIGINAL')
    RETURNING ID_CLIENTE INTO V_ID;

    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999998, '8', 'OTRO')
    RETURNING ID_CLIENTE INTO V_ID2;

    -- 1.1 Actualizar normaliza espacios y mayusculas del correo.
    SGCD_PKG_CLIENTES.actualizar_ficha(V_ID, '  NOMBRE NUEVO  ', ' +56 9 1234 ', ' CORREO@PRUEBA.CL ');

    SELECT COUNT(*) INTO V_N FROM SGCD_AUDITORIA_CLIENTES
    WHERE ID_CLIENTE = V_ID AND ACCION = 'UPDATE'
      AND NOMBRE_ANTERIOR = 'ORIGINAL' AND NOMBRE_NUEVO = 'NOMBRE NUEVO'
      AND TELEFONO_ANTERIOR IS NULL AND TELEFONO_NUEVO = '+56 9 1234'
      AND CORREO_ANTERIOR IS NULL AND CORREO_NUEVO = 'correo@prueba.cl'
      AND ID_ADMINISTRADOR = 2;
    IF V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20991, 'FALLO: update, normalizacion o auditoria del operador');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.1 actualiza, normaliza y audita con operador');

    -- 1.2 Un update sin cambios no ensucia la auditoria.
    SGCD_PKG_CLIENTES.actualizar_ficha(V_ID, 'NOMBRE NUEVO', '+56 9 1234', 'correo@prueba.cl');
    SELECT COUNT(*) INTO V_N FROM SGCD_AUDITORIA_CLIENTES WHERE ID_CLIENTE = V_ID;
    IF V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20992, 'FALLO: se audito un update sin cambios');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.2 update sin cambios no audita');

    -- 1.3 NULL vacia los campos opcionales y eso tambien se audita.
    SGCD_PKG_CLIENTES.actualizar_ficha(V_ID, 'NOMBRE NUEVO', NULL, NULL);
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES
    WHERE ID_CLIENTE = V_ID AND TELEFONO_CLIENTE IS NULL AND CORREO_CLIENTE IS NULL;
    IF V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20991, 'FALLO: NULL no vacio los campos opcionales');
    END IF;
    SELECT COUNT(*) INTO V_N FROM SGCD_AUDITORIA_CLIENTES
    WHERE ID_CLIENTE = V_ID AND ACCION = 'UPDATE'
      AND TELEFONO_ANTERIOR = '+56 9 1234' AND TELEFONO_NUEVO IS NULL
      AND CORREO_ANTERIOR = 'correo@prueba.cl' AND CORREO_NUEVO IS NULL;
    IF V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20992, 'FALLO: auditoria del cambio hacia NULL');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.3 vacia campos y audita cambios hacia NULL');

    -- 1.4 ID, RUT, DV se conservan tras cualquier actualizacion.
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES
    WHERE ID_CLIENTE = V_ID AND RUT_CLIENTE = 99999999 AND DV_CLIENTE = '9';
    IF V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20991, 'FALLO: el update toco ID/RUT/DV');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.4 conserva ID, RUT y DV');

    -- 1.5 Desactivar el cliente queda en la auditoria.
    SGCD_PKG_CLIENTES.cambiar_estado(V_ID, 'inactivo');
    SELECT ESTADO_CLIENTE INTO V_ESTADO FROM SGCD_CLIENTES WHERE ID_CLIENTE = V_ID;
    SELECT COUNT(*) INTO V_N FROM SGCD_AUDITORIA_CLIENTES
    WHERE ID_CLIENTE = V_ID AND ACCION = 'UPDATE'
      AND ESTADO_ANTERIOR = 'ACTIVO' AND ESTADO_NUEVO = 'INACTIVO';
    IF V_ESTADO <> 'INACTIVO' OR V_N <> 1 THEN
        RAISE_APPLICATION_ERROR(-20992, 'FALLO: estado o su auditoria');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.5 cambiar_estado y su registro de auditoria');

    -- 1.6 Borrar una ficha sin dependencias, conservando su historia.
    SGCD_PKG_CLIENTES.borrar_ficha(V_ID2);
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES WHERE ID_CLIENTE = V_ID2;
    SELECT COUNT(*) INTO V_M FROM SGCD_AUDITORIA_CLIENTES
    WHERE ID_CLIENTE = V_ID2 AND ACCION = 'DELETE'
      AND NOMBRE_ANTERIOR = 'OTRO' AND ESTADO_ANTERIOR = 'ACTIVO'
      AND ID_ADMINISTRADOR = 2;
    IF V_N <> 0 OR V_M <> 1 THEN
        RAISE_APPLICATION_ERROR(-20993, 'FALLO: borrado o su auditoria');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.6 borra sin dependencias y conserva la auditoria');

    -- 1.7 El rollback revierte fichas, cambios y auditoria.
    ROLLBACK;
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES
    WHERE RUT_CLIENTE IN (99999999, 99999998);
    IF V_N <> 0 THEN
        RAISE_APPLICATION_ERROR(-20994, 'FALLO: el rollback dejo fichas de prueba');
    END IF;
    SELECT COUNT(*) INTO V_N FROM SGCD_AUDITORIA_CLIENTES
    WHERE ID_CLIENTE IN (V_ID, V_ID2);
    IF V_N <> 0 THEN
        RAISE_APPLICATION_ERROR(-20994, 'FALLO: el rollback no revirtio la auditoria');
    END IF;
    DBMS_OUTPUT.PUT_LINE('OK 1.7 rollback revierte fichas y auditoria');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


-- =====================================================================
-- 2. Errores esperados. Ejecutar cada bloque por separado.
-- =====================================================================
-- E1. Esperado -20024: ID nulo.
BEGIN
    SGCD_PKG_CLIENTES.borrar_ficha(NULL);
END;
/

-- E2. Esperado -20024: ID fraccionario.
BEGIN
    SGCD_PKG_CLIENTES.actualizar_ficha(1.5, 'NOMBRE', NULL, NULL);
END;
/

-- E3. Esperado -20025: nombre vacio, antes de buscar la ficha.
BEGIN
    SGCD_PKG_CLIENTES.actualizar_ficha(1, '   ', NULL, NULL);
END;
/

-- E4. Esperado -20002: el cliente no existe.
DECLARE
    V_N NUMBER;
BEGIN
    SELECT COUNT(*) INTO V_N FROM SGCD_CLIENTES WHERE ID_CLIENTE = 999999999;
    IF V_N > 0 THEN
        RAISE_APPLICATION_ERROR(-20990, 'ID de prueba ocupado: limpiar el esquema');
    END IF;
    SGCD_PKG_CLIENTES.borrar_ficha(999999999);
END;
/

-- E5. Esperado -20009: estado fuera del catalogo.
DECLARE
    V_ID NUMBER;
BEGIN
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999997, '7', 'ESTADO INVALIDO')
    RETURNING ID_CLIENTE INTO V_ID;
    SGCD_PKG_CLIENTES.cambiar_estado(V_ID, 'SUSPENDIDO');
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20999, 'FALLO: se acepto un estado invalido');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- E6. Esperado -20017: el correo pertenece a otra ficha.
DECLARE
    V_ID  NUMBER;
    V_ID2 NUMBER;
BEGIN
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE, CORREO_CLIENTE)
    VALUES (99999996, '6', 'PRUEBA UNO', 'ocupado@prueba.cl')
    RETURNING ID_CLIENTE INTO V_ID;
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999995, '5', 'PRUEBA DOS')
    RETURNING ID_CLIENTE INTO V_ID2;
    SGCD_PKG_CLIENTES.actualizar_ficha(V_ID2, 'PRUEBA DOS', NULL, 'ocupado@prueba.cl');
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20999, 'FALLO: se acepto un correo duplicado');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- E7. Esperado -20026: una credencial vinculada impide borrar la ficha.
DECLARE
    V_ID NUMBER;
BEGIN
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999994, '4', 'PRUEBA CON DEPENDENCIA')
    RETURNING ID_CLIENTE INTO V_ID;
    INSERT INTO SGCD_CREDENCIALES (LOGIN_CREDENCIAL, CLAVE_HASH_CREDENCIAL, ID_CLIENTE)
    VALUES ('PRUEBA_' || V_ID, 'SOLO_PRUEBA_NO_USAR_PARA_LOGIN', V_ID);
    SGCD_PKG_CLIENTES.borrar_ficha(V_ID);
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20999, 'FALLO: se borro un cliente con dependencia');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/

-- E8. Esperado ORA-02290 por CK_SGCD_CLIENTE_CORREO: la tabla mantiene el
-- formato aunque el paquete no lo valide.
DECLARE
    V_ID NUMBER;
BEGIN
    INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE)
    VALUES (99999993, '3', 'PRUEBA FORMATO')
    RETURNING ID_CLIENTE INTO V_ID;
    SGCD_PKG_CLIENTES.actualizar_ficha(V_ID, 'PRUEBA FORMATO', NULL, 'sin-arroba');
    ROLLBACK;
    RAISE_APPLICATION_ERROR(-20999, 'FALLO: se acepto un correo invalido');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
        RAISE;
END;
/


-- =====================================================================
-- 3. Reportes: abren cursor y validan el rango.
-- La comparacion de totales exige un rango sin operaciones previas; si ya
-- hay movimientos, el bloque avisa y no falla.
-- =====================================================================
DECLARE
    V_CUR    SYS_REFCURSOR;
    V_TEXTO  VARCHAR2(100);
    V_NUM1   NUMBER;
    V_NUM2   NUMBER;
    V_NUM3   NUMBER;
    V_FILAS  NUMBER;
    V_HAY    NUMBER;
BEGIN
    SELECT COUNT(*) INTO V_HAY FROM SGCD_PAGOS
    WHERE FECHA_PAGO >= SYSTIMESTAMP - 30 AND FECHA_PAGO < SYSTIMESTAMP;
    SELECT COUNT(*) INTO V_NUM3 FROM SGCD_RESERVAS
    WHERE INICIO_RESERVA >= SYSTIMESTAMP - 30 AND INICIO_RESERVA < SYSTIMESTAMP;

    V_CUR := SGCD_PKG_CONSULTAS.reporte_ingresos(30);
    V_FILAS := 0;
    LOOP
        FETCH V_CUR INTO V_TEXTO, V_TEXTO, V_NUM1, V_NUM2;
        EXIT WHEN V_CUR%NOTFOUND;
        V_FILAS := V_FILAS + 1;
    END LOOP;
    CLOSE V_CUR;
    IF V_HAY = 0 AND V_FILAS <> 0 THEN
        RAISE_APPLICATION_ERROR(-20995, 'FALLO: ingresos con filas sin pagos');
    END IF;

    V_CUR := SGCD_PKG_CONSULTAS.reporte_reservas_cancha(30);
    V_FILAS := 0;
    LOOP
        FETCH V_CUR INTO V_NUM1, V_TEXTO, V_NUM2;
        EXIT WHEN V_CUR%NOTFOUND;
        V_FILAS := V_FILAS + 1;
    END LOOP;
    CLOSE V_CUR;
    IF V_NUM3 = 0 AND V_FILAS <> 0 THEN
        RAISE_APPLICATION_ERROR(-20995, 'FALLO: reservas por cancha sin reservas');
    END IF;

    V_CUR := SGCD_PKG_CONSULTAS.reporte_clientes_reservas(30);
    V_FILAS := 0;
    LOOP
        FETCH V_CUR INTO V_NUM1, V_TEXTO, V_NUM2;
        EXIT WHEN V_CUR%NOTFOUND;
        V_FILAS := V_FILAS + 1;
    END LOOP;
    CLOSE V_CUR;
    IF V_NUM3 = 0 AND V_FILAS <> 0 THEN
        RAISE_APPLICATION_ERROR(-20995, 'FALLO: clientes con reservas sin reservas');
    END IF;

    BEGIN
        V_CUR := SGCD_PKG_CONSULTAS.reporte_ingresos(0);
        RAISE_APPLICATION_ERROR(-20999, 'FALLO: se acepto un rango de dias invalido');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20019 THEN RAISE; END IF;
    END;

    DBMS_OUTPUT.PUT_LINE('OK 3.1 los tres reportes abren cursor');
    DBMS_OUTPUT.PUT_LINE('OK 3.2 -20019 con rango de dias invalido');
    IF V_HAY > 0 OR V_NUM3 > 0 THEN
        DBMS_OUTPUT.PUT_LINE('AVISO: hay movimientos en los ultimos 30 dias; '
            || 'comparar los totales a mano.');
    END IF;
END;
/

EXIT
