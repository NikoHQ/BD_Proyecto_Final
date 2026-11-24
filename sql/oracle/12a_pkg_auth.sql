-- =====================================================================
-- SGCD_PKG_AUTH - acceso al sistema sobre SGCD_USUARIOS
-- Requiere: 10_ddl_sgcd_19.sql
--
-- El paquete nunca ve la clave en claro: recibe y devuelve el hash bcrypt que
-- calcula PHP. Tampoco decide permisos: eso es del API, que conoce el perfil
-- de la sesion. Aqui solo se crea la cuenta, se cambia su clave o su estado y
-- se entrega la cuenta con su perfil para que PHP la verifique.
--
-- Cuenta con perfil de cliente y de administrador tiene la misma forma, porque
-- la web trabaja con una sola fila de sesion.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_AUTH AS
    PROCEDURE crear_usuario(
        p_login      VARCHAR2,
        p_hash       VARCHAR2,
        p_rol        VARCHAR2,
        p_id_usuario OUT NUMBER);
    FUNCTION cuenta(
        p_login      VARCHAR2 DEFAULT NULL,
        p_id_usuario NUMBER   DEFAULT NULL) RETURN SYS_REFCURSOR;
    PROCEDURE cambiar_clave(p_id_usuario NUMBER, p_hash VARCHAR2);
    PROCEDURE cambiar_estado(p_id_usuario NUMBER, p_estado VARCHAR2);
END SGCD_PKG_AUTH;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_AUTH AS

    PROCEDURE validar_hash(p_hash VARCHAR2) IS
    BEGIN
        IF p_hash IS NULL OR LENGTH(p_hash) < 20 OR LENGTH(p_hash) > 255 THEN
            RAISE_APPLICATION_ERROR(-20031, 'El hash de la clave no es valido');
        END IF;
    END validar_hash;

    PROCEDURE validar_id(p_id_usuario NUMBER) IS
    BEGIN
        IF p_id_usuario IS NULL OR p_id_usuario <= 0
           OR p_id_usuario <> TRUNC(p_id_usuario) THEN
            RAISE_APPLICATION_ERROR(-20030, 'El ID del usuario no es valido');
        END IF;
    END validar_id;

    PROCEDURE crear_usuario(
        p_login      VARCHAR2,
        p_hash       VARCHAR2,
        p_rol        VARCHAR2,
        p_id_usuario OUT NUMBER)
    IS
        v_login VARCHAR2(50) := TRIM(p_login);
        v_rol   VARCHAR2(20) := UPPER(TRIM(p_rol));
    BEGIN
        IF v_login IS NULL OR v_login <> LOWER(v_login)
           OR NOT REGEXP_LIKE(v_login, '^[a-z0-9._-]{3,50}$') THEN
            RAISE_APPLICATION_ERROR(-20029, 'El login debe tener entre 3 y 50 caracteres, en minusculas, sin espacios');
        END IF;
        IF v_rol IS NULL OR v_rol NOT IN ('ADMINISTRADOR', 'CLIENTE') THEN
            RAISE_APPLICATION_ERROR(-20028, 'El rol debe ser ADMINISTRADOR o CLIENTE');
        END IF;
        validar_hash(p_hash);
        INSERT INTO SGCD_USUARIOS (LOGIN, CLAVE_HASH, ROL)
        VALUES (v_login, p_hash, v_rol)
        RETURNING ID_USUARIO INTO p_id_usuario;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20018, 'El login ya esta registrado');
    END crear_usuario;

    FUNCTION cuenta(
        p_login      VARCHAR2 DEFAULT NULL,
        p_id_usuario NUMBER   DEFAULT NULL) RETURN SYS_REFCURSOR
    IS
        v_cursor SYS_REFCURSOR;
        v_login  VARCHAR2(50) := LOWER(TRIM(p_login));
    BEGIN
        IF p_id_usuario IS NULL AND v_login IS NULL THEN
            RAISE_APPLICATION_ERROR(-20030, 'Indica el login o el ID del usuario');
        END IF;
        OPEN v_cursor FOR
            SELECT u.ID_USUARIO, u.LOGIN, u.CLAVE_HASH, u.ROL, u.ESTADO_USUARIO,
                   NVL(a.ID_ADMINISTRADOR, c.ID_CLIENTE) AS ID_PERFIL,
                   NVL(NVL(a.NOMBRE_ADMINISTRADOR, c.NOMBRE_CLIENTE), u.LOGIN) AS NOMBRE,
                   NVL(a.ESTADO_ADMINISTRADOR, c.ESTADO_CLIENTE) AS ESTADO_PERFIL
            FROM   SGCD_USUARIOS u
            LEFT   JOIN SGCD_ADMINISTRADORES a ON a.ID_USUARIO = u.ID_USUARIO
            LEFT   JOIN SGCD_CLIENTES c ON c.ID_USUARIO = u.ID_USUARIO
            WHERE  (p_id_usuario IS NOT NULL AND u.ID_USUARIO = p_id_usuario)
               OR  (p_id_usuario IS NULL AND u.LOGIN = v_login);
        RETURN v_cursor;
    END cuenta;

    PROCEDURE cambiar_clave(p_id_usuario NUMBER, p_hash VARCHAR2) IS
    BEGIN
        validar_id(p_id_usuario);
        validar_hash(p_hash);
        UPDATE SGCD_USUARIOS SET CLAVE_HASH = p_hash WHERE ID_USUARIO = p_id_usuario;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20030, 'El usuario no existe');
        END IF;
    END cambiar_clave;

    PROCEDURE cambiar_estado(p_id_usuario NUMBER, p_estado VARCHAR2) IS
        v_estado VARCHAR2(10) := UPPER(TRIM(p_estado));
    BEGIN
        validar_id(p_id_usuario);
        IF v_estado IS NULL OR v_estado NOT IN ('ACTIVO', 'INACTIVO') THEN
            RAISE_APPLICATION_ERROR(-20009, 'El estado debe ser ACTIVO o INACTIVO');
        END IF;
        UPDATE SGCD_USUARIOS SET ESTADO_USUARIO = v_estado WHERE ID_USUARIO = p_id_usuario;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20030, 'El usuario no existe');
        END IF;
    END cambiar_estado;

END SGCD_PKG_AUTH;
/
