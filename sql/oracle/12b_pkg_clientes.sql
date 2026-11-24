-- =====================================================================
-- SGCD_PKG_CLIENTES - ficha del cliente sobre SGCD_CLIENTES
-- Requiere: 10_ddl_sgcd_19.sql y 12a_pkg_auth.sql
--
-- La ficha existe sin cuenta: ese es el caso normal del cliente presencial.
-- ID_USUARIO se llena solo cuando la persona se registra en el portal, y ese
-- registro crea la cuenta y la ficha en una sola transaccion.
--
-- La auditoria no vive aqui: la hacen los triggers TRG_SGCD_CLIENTES_AU y _AD
-- del DDL. Este paquete no escribe en SGCD_AUDITORIA_CLIENTES.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_CLIENTES AS
    FUNCTION normalizar_dv(p_dv VARCHAR2) RETURN CHAR;
    FUNCTION dv_calculado(p_rut NUMBER) RETURN CHAR;
    FUNCTION rut_valido(p_rut NUMBER, p_dv VARCHAR2) RETURN BOOLEAN;
    FUNCTION obtener_por_rut(p_rut NUMBER, p_dv VARCHAR2) RETURN NUMBER;
    PROCEDURE crear_ficha(
        p_rut        NUMBER,
        p_dv         VARCHAR2,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER,
        p_creada     OUT BOOLEAN);
    PROCEDURE registrar_cuenta_web(
        p_login      VARCHAR2,
        p_hash       VARCHAR2,
        p_rut        NUMBER,
        p_dv         VARCHAR2,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER);
    PROCEDURE actualizar_ficha(
        p_id_cliente NUMBER,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL);
    PROCEDURE cambiar_estado(p_id_cliente NUMBER, p_estado VARCHAR2);
    PROCEDURE borrar_ficha(p_id_cliente NUMBER);
    PROCEDURE listar_fichas(
        p_texto   VARCHAR2 DEFAULT NULL,
        p_estado  VARCHAR2 DEFAULT NULL,
        p_desde   NUMBER DEFAULT 1,
        p_tamano  NUMBER DEFAULT 20,
        p_cursor  OUT SYS_REFCURSOR,
        p_total   OUT NUMBER);
    FUNCTION ficha_detalle(p_id_cliente NUMBER) RETURN SYS_REFCURSOR;
END SGCD_PKG_CLIENTES;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_CLIENTES AS

    PROCEDURE validar_id(p_id_cliente NUMBER) IS
    BEGIN
        IF p_id_cliente IS NULL OR p_id_cliente <= 0
           OR p_id_cliente <> TRUNC(p_id_cliente) THEN
            RAISE_APPLICATION_ERROR(-20024, 'El ID del cliente debe ser un entero mayor que cero');
        END IF;
    END validar_id;

    PROCEDURE validar_nombre(p_nombre VARCHAR2) IS
    BEGIN
        IF p_nombre IS NULL OR TRIM(p_nombre) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20025, 'El nombre del cliente es obligatorio');
        END IF;
    END validar_nombre;

    PROCEDURE validar_filtro(p_estado VARCHAR2, p_desde NUMBER, p_tamano NUMBER) IS
    BEGIN
        IF (p_estado IS NOT NULL AND UPPER(TRIM(p_estado)) NOT IN ('ACTIVO', 'INACTIVO'))
           OR p_desde IS NULL OR p_desde < 1 OR p_desde <> TRUNC(p_desde)
           OR p_tamano IS NULL OR p_tamano < 1 OR p_tamano > 100 OR p_tamano <> TRUNC(p_tamano) THEN
            RAISE_APPLICATION_ERROR(-20027, 'Revisa el estado, la pagina y el tamano de la lista');
        END IF;
    END validar_filtro;

    FUNCTION normalizar_dv(p_dv VARCHAR2) RETURN CHAR IS
    BEGIN
        RETURN SUBSTR(UPPER(TRIM(p_dv)), 1, 1);
    END normalizar_dv;

    FUNCTION dv_calculado(p_rut NUMBER) RETURN CHAR IS
        v_num    NUMBER := p_rut;
        v_suma   NUMBER := 0;
        v_factor NUMBER := 2;
        v_dig    NUMBER;
        v_dv     NUMBER;
    BEGIN
        WHILE v_num > 0 LOOP
            v_dig    := MOD(v_num, 10);
            v_suma   := v_suma + v_dig * v_factor;
            v_factor := CASE WHEN v_factor = 7 THEN 2 ELSE v_factor + 1 END;
            v_num    := TRUNC(v_num / 10);
        END LOOP;
        v_dv := 11 - MOD(v_suma, 11);
        RETURN CASE WHEN v_dv = 11 THEN '0' WHEN v_dv = 10 THEN 'K' ELSE TO_CHAR(v_dv) END;
    END dv_calculado;

    FUNCTION rut_valido(p_rut NUMBER, p_dv VARCHAR2) RETURN BOOLEAN IS
    BEGIN
        IF p_rut IS NULL OR p_rut < 1 OR p_rut > 99999999
           OR p_rut <> TRUNC(p_rut) THEN
            RETURN FALSE;
        END IF;
        RETURN dv_calculado(p_rut) = normalizar_dv(p_dv);
    END rut_valido;

    FUNCTION obtener_por_rut(p_rut NUMBER, p_dv VARCHAR2) RETURN NUMBER IS
        v_id NUMBER;
    BEGIN
        SELECT c.ID_CLIENTE INTO v_id
        FROM   SGCD_CLIENTES c
        WHERE  c.RUT_CLIENTE = p_rut AND c.DV_CLIENTE = normalizar_dv(p_dv);
        RETURN v_id;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN RETURN NULL;
    END obtener_por_rut;

    FUNCTION correo_en_uso(p_correo VARCHAR2, p_id_cliente NUMBER) RETURN BOOLEAN IS
        v_cantidad NUMBER;
    BEGIN
        IF p_correo IS NULL THEN
            RETURN FALSE;
        END IF;
        SELECT COUNT(*) INTO v_cantidad
        FROM   SGCD_CLIENTES c
        WHERE  c.CORREO_CLIENTE = LOWER(TRIM(p_correo))
          AND  (p_id_cliente IS NULL OR c.ID_CLIENTE <> p_id_cliente);
        RETURN v_cantidad > 0;
    END correo_en_uso;

    PROCEDURE crear_ficha(
        p_rut        NUMBER,
        p_dv         VARCHAR2,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER,
        p_creada     OUT BOOLEAN)
    IS
        v_dv     CHAR(1) := normalizar_dv(p_dv);
        v_existe NUMBER;
    BEGIN
        validar_nombre(p_nombre);
        IF NOT rut_valido(p_rut, v_dv) THEN
            RAISE_APPLICATION_ERROR(-20001, 'RUT invalido: ' || p_rut || '-' || v_dv);
        END IF;
        v_existe := obtener_por_rut(p_rut, v_dv);
        IF v_existe IS NOT NULL THEN
            p_id_cliente := v_existe;
            p_creada     := FALSE;
            RETURN;
        END IF;
        IF correo_en_uso(p_correo, NULL) THEN
            RAISE_APPLICATION_ERROR(-20017, 'El correo ya esta registrado en otra ficha');
        END IF;
        INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE, TELEFONO_CLIENTE, CORREO_CLIENTE)
        VALUES (p_rut, v_dv, TRIM(p_nombre), p_telefono, LOWER(TRIM(p_correo)))
        RETURNING ID_CLIENTE INTO p_id_cliente;
        p_creada := TRUE;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            v_existe := obtener_por_rut(p_rut, v_dv);
            IF v_existe IS NOT NULL THEN
                p_id_cliente := v_existe;
                p_creada     := FALSE;
            ELSE
                RAISE_APPLICATION_ERROR(-20017, 'El correo ya esta registrado en otra ficha');
            END IF;
    END crear_ficha;

    PROCEDURE registrar_cuenta_web(
        p_login      VARCHAR2,
        p_hash       VARCHAR2,
        p_rut        NUMBER,
        p_dv         VARCHAR2,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER)
    IS
        v_dv       CHAR(1) := normalizar_dv(p_dv);
        v_id       NUMBER;
        v_usuario  NUMBER;
        v_nuevo    NUMBER;
    BEGIN
        validar_nombre(p_nombre);
        IF NOT rut_valido(p_rut, v_dv) THEN
            RAISE_APPLICATION_ERROR(-20001, 'RUT invalido: ' || p_rut || '-' || v_dv);
        END IF;
        v_id := obtener_por_rut(p_rut, v_dv);
        IF v_id IS NOT NULL THEN
            SELECT c.ID_USUARIO INTO v_usuario FROM SGCD_CLIENTES c WHERE c.ID_CLIENTE = v_id;
            IF v_usuario IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20032, 'Ese RUT ya tiene una cuenta web');
            END IF;
        ELSIF correo_en_uso(p_correo, NULL) THEN
            RAISE_APPLICATION_ERROR(-20017, 'El correo ya esta registrado en otra ficha');
        END IF;
        SGCD_PKG_AUTH.crear_usuario(p_login, p_hash, 'CLIENTE', v_nuevo);
        IF v_id IS NULL THEN
            INSERT INTO SGCD_CLIENTES (ID_USUARIO, RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE,
                                       TELEFONO_CLIENTE, CORREO_CLIENTE)
            VALUES (v_nuevo, p_rut, v_dv, TRIM(p_nombre), p_telefono, LOWER(TRIM(p_correo)))
            RETURNING ID_CLIENTE INTO p_id_cliente;
        ELSE
            -- La ficha presencial ya tiene los datos que tomo recepcion: solo se engancha la cuenta
            UPDATE SGCD_CLIENTES SET ID_USUARIO = v_nuevo WHERE ID_CLIENTE = v_id;
            p_id_cliente := v_id;
        END IF;
    END registrar_cuenta_web;

    PROCEDURE actualizar_ficha(
        p_id_cliente NUMBER,
        p_nombre     VARCHAR2,
        p_telefono   VARCHAR2 DEFAULT NULL,
        p_correo     VARCHAR2 DEFAULT NULL)
    IS
    BEGIN
        validar_id(p_id_cliente);
        validar_nombre(p_nombre);
        IF correo_en_uso(p_correo, p_id_cliente) THEN
            RAISE_APPLICATION_ERROR(-20017, 'El correo ya esta registrado en otra ficha');
        END IF;
        UPDATE SGCD_CLIENTES
        SET    NOMBRE_CLIENTE = TRIM(p_nombre),
               TELEFONO_CLIENTE = p_telefono,
               CORREO_CLIENTE = LOWER(TRIM(p_correo))
        WHERE  ID_CLIENTE = p_id_cliente;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El cliente no existe');
        END IF;
    END actualizar_ficha;

    PROCEDURE cambiar_estado(p_id_cliente NUMBER, p_estado VARCHAR2) IS
        v_estado VARCHAR2(10) := UPPER(TRIM(p_estado));
    BEGIN
        validar_id(p_id_cliente);
        IF v_estado IS NULL OR v_estado NOT IN ('ACTIVO', 'INACTIVO') THEN
            RAISE_APPLICATION_ERROR(-20009, 'El estado debe ser ACTIVO o INACTIVO');
        END IF;
        UPDATE SGCD_CLIENTES SET ESTADO_CLIENTE = v_estado WHERE ID_CLIENTE = p_id_cliente;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El cliente no existe');
        END IF;
    END cambiar_estado;

    PROCEDURE borrar_ficha(p_id_cliente NUMBER) IS
        v_relaciones NUMBER;
    BEGIN
        validar_id(p_id_cliente);
        SELECT (SELECT COUNT(*) FROM SGCD_RESERVAS r WHERE r.ID_CLIENTE = p_id_cliente)
             + (SELECT COUNT(*) FROM SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_CLIENTE = p_id_cliente)
             + (SELECT COUNT(*) FROM SGCD_JUGADORES j WHERE j.ID_CLIENTE = p_id_cliente)
             + (SELECT COUNT(*) FROM SGCD_CLIENTES c
                WHERE c.ID_CLIENTE = p_id_cliente AND c.ID_USUARIO IS NOT NULL)
        INTO   v_relaciones
        FROM   DUAL;
        IF v_relaciones > 0 THEN
            RAISE_APPLICATION_ERROR(-20026, 'El cliente tiene cuenta, reservas o torneos: desactivalo en vez de borrarlo');
        END IF;
        DELETE FROM SGCD_CLIENTES WHERE ID_CLIENTE = p_id_cliente;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'El cliente no existe');
        END IF;
    END borrar_ficha;

    PROCEDURE listar_fichas(
        p_texto   VARCHAR2 DEFAULT NULL,
        p_estado  VARCHAR2 DEFAULT NULL,
        p_desde   NUMBER DEFAULT 1,
        p_tamano  NUMBER DEFAULT 20,
        p_cursor  OUT SYS_REFCURSOR,
        p_total   OUT NUMBER)
    IS
        v_texto  VARCHAR2(120) := '%' || SUBSTR(UPPER(TRIM(p_texto)), 1, 100) || '%';
        v_estado VARCHAR2(10)  := UPPER(TRIM(p_estado));
    BEGIN
        validar_filtro(p_estado, p_desde, p_tamano);
        SELECT COUNT(*) INTO p_total
        FROM   SGCD_CLIENTES c
        WHERE  (p_texto IS NULL
                OR UPPER(c.NOMBRE_CLIENTE) LIKE v_texto
                OR UPPER(c.CORREO_CLIENTE) LIKE v_texto
                OR c.TELEFONO_CLIENTE LIKE v_texto
                OR (TO_CHAR(c.RUT_CLIENTE) || c.DV_CLIENTE) LIKE v_texto)
          AND  (v_estado IS NULL OR c.ESTADO_CLIENTE = v_estado);
        OPEN p_cursor FOR
            SELECT c.ID_CLIENTE, c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE,
                   c.CORREO_CLIENTE, c.TELEFONO_CLIENTE, c.ESTADO_CLIENTE, c.ID_USUARIO
            FROM   SGCD_CLIENTES c
            WHERE  (p_texto IS NULL
                    OR UPPER(c.NOMBRE_CLIENTE) LIKE v_texto
                    OR UPPER(c.CORREO_CLIENTE) LIKE v_texto
                    OR c.TELEFONO_CLIENTE LIKE v_texto
                    OR (TO_CHAR(c.RUT_CLIENTE) || c.DV_CLIENTE) LIKE v_texto)
              AND  (v_estado IS NULL OR c.ESTADO_CLIENTE = v_estado)
            ORDER  BY c.NOMBRE_CLIENTE, c.ID_CLIENTE
            OFFSET p_desde - 1 ROWS FETCH NEXT p_tamano ROWS ONLY;
    END listar_fichas;

    FUNCTION ficha_detalle(p_id_cliente NUMBER) RETURN SYS_REFCURSOR IS
        v_cursor SYS_REFCURSOR;
    BEGIN
        validar_id(p_id_cliente);
        OPEN v_cursor FOR
            SELECT c.ID_CLIENTE, c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE,
                   c.CORREO_CLIENTE, c.TELEFONO_CLIENTE, c.ESTADO_CLIENTE, c.ID_USUARIO
            FROM   SGCD_CLIENTES c
            WHERE  c.ID_CLIENTE = p_id_cliente;
        RETURN v_cursor;
    END ficha_detalle;

END SGCD_PKG_CLIENTES;
/
