-- =====================================================================
-- PRUEBAS DE LOS PAQUETES DEL MODELO OBJETIVO
-- Requiere: 10_ddl_sgcd_19.sql, 11_catalogos_sgcd_19.sql y los paquetes 12*.
-- Todo se revierte al final: no deja datos.
--
--   docker exec -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
--     -i oracle-free sqlplus -s -L SGCD19/<clave>@localhost/FREEPDB1 \
--     < sql/oracle/14_pruebas_paquetes_sgcd_19.sql
--
-- Cada unidad de la fase 3 agrega su bloque. Al final imprime el total de
-- fallas; 0 significa que los paquetes cumplen el contrato.
-- =====================================================================


SET SERVEROUTPUT ON
SET DEFINE OFF


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 1: SGCD_PKG_AUTH');

    -- Una clave bcrypt cualquiera: el paquete solo valida forma, la verifica PHP
    DECLARE
        V_CLIENTE NUMBER;
        V_ADMIN   NUMBER;
        C         SYS_REFCURSOR;
        V_ID_U    NUMBER;
        V_LOGIN   VARCHAR2(50);
        V_CLAVE   VARCHAR2(255);
        V_ROL     VARCHAR2(20);
        V_ESTADO  VARCHAR2(10);
        V_PERFIL  NUMBER;
        V_NOMBRE  VARCHAR2(100);
        V_EST_PER VARCHAR2(10);
    BEGIN
        SGCD_PKG_AUTH.crear_usuario('prueba_auth_cli', RPAD('x', 60, 'x'), 'cliente', V_CLIENTE);
        COMPROBAR(V_CLIENTE > 0, 'crear_usuario asigna ID con la secuencia');

        C := SGCD_PKG_AUTH.cuenta(p_login => 'PRUEBA_AUTH_CLI');
        FETCH C INTO V_ID_U, V_LOGIN, V_CLAVE, V_ROL, V_ESTADO, V_PERFIL, V_NOMBRE, V_EST_PER;
        COMPROBAR(V_ID_U = V_CLIENTE AND V_ROL = 'CLIENTE' AND V_ESTADO = 'ACTIVO',
                  'cuenta() por login busca en minusculas y devuelve rol y estado');
        COMPROBAR(V_PERFIL IS NULL AND V_NOMBRE = V_LOGIN,
                  'cuenta() avisa una cuenta todavia sin ficha en vez de ocultarla');
        CLOSE C;

        SGCD_PKG_AUTH.crear_usuario('prueba_auth_adm', RPAD('y', 60, 'y'), 'ADMINISTRADOR', V_ADMIN);
        INSERT INTO SGCD_ADMINISTRADORES (ID_USUARIO, NOMBRE_ADMINISTRADOR)
        VALUES (V_ADMIN, 'Administrador de prueba');

        C := SGCD_PKG_AUTH.cuenta(p_id_usuario => V_ADMIN);
        FETCH C INTO V_ID_U, V_LOGIN, V_CLAVE, V_ROL, V_ESTADO, V_PERFIL, V_NOMBRE, V_EST_PER;
        COMPROBAR(V_ROL = 'ADMINISTRADOR' AND V_PERFIL IS NOT NULL
                  AND V_NOMBRE = 'Administrador de prueba',
                  'cuenta() por ID devuelve el perfil de administrador');
        CLOSE C;

        SGCD_PKG_AUTH.cambiar_clave(V_CLIENTE, RPAD('z', 60, 'z'));
        SELECT CLAVE_HASH INTO V_CLAVE FROM SGCD_USUARIOS WHERE ID_USUARIO = V_CLIENTE;
        COMPROBAR(V_CLAVE = RPAD('z', 60, 'z'), 'cambiar_clave actualiza el hash');

        SGCD_PKG_AUTH.cambiar_estado(V_CLIENTE, 'inactivo');
        SELECT ESTADO_USUARIO INTO V_ESTADO FROM SGCD_USUARIOS WHERE ID_USUARIO = V_CLIENTE;
        COMPROBAR(V_ESTADO = 'INACTIVO', 'cambiar_estado normaliza el estado a mayusculas');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_AUTH.crear_usuario(''prueba_auth_cli'', RPAD(''x'', 60, ''x''), ''CLIENTE'', V); END;',
        -20018, 'rechaza un login ya registrado');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_AUTH.crear_usuario(''prueba_auth_op'', RPAD(''x'', 60, ''x''), ''OPERADOR'', V); END;',
        -20028, 'rechaza el rol OPERADOR, que ya no existe en el modelo');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_AUTH.crear_usuario(''Mayusculas'', RPAD(''x'', 60, ''x''), ''CLIENTE'', V); END;',
        -20029, 'rechaza un login con mayusculas');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_AUTH.crear_usuario(''ab'', RPAD(''x'', 60, ''x''), ''CLIENTE'', V); END;',
        -20029, 'rechaza un login de menos de tres caracteres');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_AUTH.crear_usuario(''prueba_auth_clave'', RPAD(''x'', 5, ''x''), ''CLIENTE'', V); END;',
        -20031, 'rechaza un hash de clave que no tiene forma de hash');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_AUTH.cambiar_clave(999999, RPAD(''x'', 60, ''x'')); END;',
        -20030, 'cambiar_clave rechaza un usuario inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_AUTH.cambiar_estado(999999, ''ACTIVO''); END;',
        -20030, 'cambiar_estado rechaza un usuario inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_AUTH.cambiar_estado(1, ''BLOQUEADA''); END;',
        -20009, 'rechaza un estado distinto de ACTIVO o INACTIVO');
    ESPERAR_ERROR(
        'DECLARE C SYS_REFCURSOR; BEGIN C := SGCD_PKG_AUTH.cuenta(); END;',
        -20030, 'cuenta() exige login o ID');

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 2: SGCD_PKG_CLIENTES');

    DECLARE
        V_PRESENCIAL NUMBER;
        V_WEB        NUMBER;
        V_ADJUNTA    NUMBER;
        V_CREADA     BOOLEAN;
        V_USUARIO    NUMBER;
        V_TOTAL      NUMBER;
        V_CANTIDAD   NUMBER;
        V_ESTADO     VARCHAR2(10);
        V_NOMBRE     VARCHAR2(100);
        C            SYS_REFCURSOR;
        -- Columnas de los cursores, para no reutilizar variables de distinto tipo
        F_ID     NUMBER;
        F_RUT    NUMBER;
        F_DV     VARCHAR2(1);
        F_NOMBRE VARCHAR2(100);
        F_CORREO VARCHAR2(150);
        F_FONO   VARCHAR2(20);
        F_ESTADO VARCHAR2(10);
        F_USR    NUMBER;
    BEGIN
        SGCD_PKG_CLIENTES.crear_ficha(31000001, '9', 'Cliente Presencial', NULL, NULL,
                                      V_PRESENCIAL, V_CREADA);
        COMPROBAR(V_CREADA AND V_PRESENCIAL > 0, 'crear_ficha da de alta una ficha presencial');
        SELECT c.ID_USUARIO INTO V_USUARIO FROM SGCD_CLIENTES c WHERE c.ID_CLIENTE = V_PRESENCIAL;
        COMPROBAR(V_USUARIO IS NULL, 'la ficha presencial nace sin cuenta');

        SGCD_PKG_CLIENTES.crear_ficha(31000001, '9', 'Otro nombre', NULL, NULL, V_ADJUNTA, V_CREADA);
        COMPROBAR(NOT V_CREADA AND V_ADJUNTA = V_PRESENCIAL,
                  'crear_ficha es idempotente por RUT: devuelve la ficha existente');

        SGCD_PKG_CLIENTES.registrar_cuenta_web('cta_web_dos', RPAD('x', 60, 'x'), 31000002, '7',
                                               'Cliente Web Dos', '+56 9 1111 2222',
                                               'cliente.dos@demo.cl', V_WEB);
        SELECT c.ID_USUARIO INTO V_USUARIO FROM SGCD_CLIENTES c WHERE c.ID_CLIENTE = V_WEB;
        COMPROBAR(V_USUARIO IS NOT NULL, 'registrar_cuenta_web engancha la cuenta a la ficha nueva');
        C := SGCD_PKG_AUTH.cuenta(p_login => 'cta_web_dos');
        FETCH C INTO F_ID, F_NOMBRE, F_CORREO, F_NOMBRE, F_ESTADO, F_USR, F_NOMBRE, F_ESTADO;
        COMPROBAR(F_ID = V_USUARIO AND F_USR = V_WEB,
                  'la cuenta nueva resuelve al usuario y a su ficha');
        CLOSE C;

        SGCD_PKG_CLIENTES.registrar_cuenta_web('cta_web_uno', RPAD('x', 60, 'x'), 31000001, '9',
                                               'Cliente Presencial', NULL, NULL, V_ADJUNTA);
        COMPROBAR(V_ADJUNTA = V_PRESENCIAL, 'registrar_cuenta_web reutiliza la ficha presencial');
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CLIENTES WHERE RUT_CLIENTE = 31000001;
        COMPROBAR(V_CANTIDAD = 1, 'no se duplica la persona al enganchar la cuenta');

        SGCD_PKG_CLIENTES.actualizar_ficha(V_WEB, 'Cliente Web Actualizado', '+56 9 3333 4444',
                                           'cliente.web@demo.cl');
        SELECT c.NOMBRE_CLIENTE INTO V_NOMBRE FROM SGCD_CLIENTES c WHERE c.ID_CLIENTE = V_WEB;
        COMPROBAR(V_NOMBRE = 'Cliente Web Actualizado', 'actualizar_ficha cambia los datos');
        SELECT COUNT(*) INTO V_CANTIDAD
        FROM   SGCD_AUDITORIA_CLIENTES a
        WHERE  a.ID_CLIENTE = V_WEB AND a.ACCION = 'UPDATE'
          AND  a.VALORES_ANTERIORES LIKE '%"nombre"%'
          AND  a.VALORES_ANTERIORES LIKE '%"correo"%'
          AND  a.VALORES_NUEVOS LIKE '%"telefono":"+56 9 3333 4444"%';
        COMPROBAR(V_CANTIDAD = 1, 'el cambio de ficha queda auditado sin que el paquete lo escriba');

        SGCD_PKG_CLIENTES.cambiar_estado(V_WEB, 'inactivo');
        SELECT c.ESTADO_CLIENTE INTO V_ESTADO FROM SGCD_CLIENTES c WHERE c.ID_CLIENTE = V_WEB;
        COMPROBAR(V_ESTADO = 'INACTIVO', 'cambiar_estado desactiva la ficha');

        SGCD_PKG_CLIENTES.listar_fichas(p_texto => '31000002', p_cursor => C, p_total => V_TOTAL);
        FETCH C INTO F_ID, F_RUT, F_DV, F_NOMBRE, F_CORREO, F_FONO, F_ESTADO, F_USR;
        COMPROBAR(V_TOTAL = 1 AND F_ID = V_WEB, 'listar_fichas busca por RUT y pagina');
        CLOSE C;

        C := SGCD_PKG_CLIENTES.ficha_detalle(999999);
        FETCH C INTO F_ID, F_RUT, F_DV, F_NOMBRE, F_CORREO, F_FONO, F_ESTADO, F_USR;
        COMPROBAR(C%NOTFOUND, 'ficha_detalle de un ID inexistente devuelve cero filas');
        CLOSE C;

        SGCD_PKG_CLIENTES.crear_ficha(31000005, '1', 'Cliente Con Reserva', NULL, NULL,
                                      V_ADJUNTA, V_CREADA);
        INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA,
                                   TERMINO_RESERVA, IMPORTE_ACORDADO, ESTADO_RESERVA)
        VALUES (V_ADJUNTA, 9, 2, DATE '2026-12-01' + 10/24, DATE '2026-12-01' + 11/24,
                16000, 'CONFIRMADA');
        ESPERAR_ERROR('BEGIN SGCD_PKG_CLIENTES.borrar_ficha(' || V_ADJUNTA || '); END;',
                      -20026, 'rechaza borrar una ficha con reservas');
        ESPERAR_ERROR('BEGIN SGCD_PKG_CLIENTES.borrar_ficha(' || V_WEB || '); END;',
                      -20026, 'rechaza borrar una ficha con cuenta');

        SGCD_PKG_CLIENTES.crear_ficha(31000004, '3', 'Cliente Desechable', NULL, 'desechable@demo.cl',
                                      V_PRESENCIAL, V_CREADA);
        SGCD_PKG_CLIENTES.borrar_ficha(V_PRESENCIAL);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CLIENTES WHERE ID_CLIENTE = V_PRESENCIAL;
        COMPROBAR(V_CANTIDAD = 0, 'borra la ficha cuando no tiene relaciones');
        SELECT COUNT(*) INTO V_CANTIDAD
        FROM   SGCD_AUDITORIA_CLIENTES a
        WHERE  a.ID_CLIENTE = V_PRESENCIAL AND a.ACCION = 'DELETE'
          AND  a.VALORES_NUEVOS IS NULL;
        COMPROBAR(V_CANTIDAD = 1, 'el borrado deja el retrato previo en la auditoria');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; B BOOLEAN; BEGIN SGCD_PKG_CLIENTES.crear_ficha(31000003, ''5'', ''   '', NULL, NULL, V, B); END;',
        -20025, 'rechaza una ficha sin nombre');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; B BOOLEAN; BEGIN SGCD_PKG_CLIENTES.crear_ficha(31000003, ''4'', ''RUT Malo'', NULL, NULL, V, B); END;',
        -20001, 'rechaza un RUT con digito verificador incorrecto');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; B BOOLEAN; BEGIN SGCD_PKG_CLIENTES.crear_ficha(31000003, ''5'', ''Correo Repetido'', NULL, ''camila.rojas@demo.cl'', V, B); END;',
        -20017, 'rechaza una ficha con el correo de otra ficha');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_CLIENTES.registrar_cuenta_web(''cta_web_tres'', RPAD(''x'', 60, ''x''), 31000001, ''9'', ''Repetido'', NULL, NULL, V); END;',
        -20032, 'rechaza registrar una cuenta sobre un RUT que ya la tiene');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_CLIENTES.registrar_cuenta_web(''cta_web_dos'', RPAD(''x'', 60, ''x''), 31000003, ''5'', ''Login Repetido'', NULL, NULL, V); END;',
        -20018, 'rechaza un login ya usado');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_CLIENTES.actualizar_ficha(999999, ''Nadie''); END;',
        -20002, 'actualizar_ficha rechaza un cliente inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_CLIENTES.cambiar_estado(1, ''SUSPENDIDO''); END;',
        -20009, 'rechaza un estado distinto de ACTIVO o INACTIVO');
    ESPERAR_ERROR(
        'DECLARE C SYS_REFCURSOR; T NUMBER; BEGIN SGCD_PKG_CLIENTES.listar_fichas(NULL, NULL, 1, 0, C, T); END;',
        -20027, 'listar_fichas rechaza un tamano de pagina invalido');
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_CLIENTES.borrar_ficha(999999); END;',
        -20002, 'borrar_ficha rechaza un cliente inexistente');

    DECLARE
        V_CANTIDAD NUMBER;
    BEGIN
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CLIENTES WHERE RUT_CLIENTE = 31000003;
        COMPROBAR(V_CANTIDAD = 0, 'un registro rechazado no deja ficha a medias');
    END;

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 3: mantenedores de catalogo');

    DECLARE
        V_DEPORTE   NUMBER;
        V_MODALIDAD NUMBER;
        V_CANCHA    NUMBER;
        V_CANTIDAD  NUMBER;
        V_ENCONTRADA BOOLEAN := FALSE;
        V_MAX       NUMBER;
        V_NOMBRE    VARCHAR2(80);
        V_ESTADO    VARCHAR2(10);
        C           SYS_REFCURSOR;
        -- columnas de los cursores
        L_ID        NUMBER;
        L_PADRE     NUMBER;
        L_MAX       NUMBER;
        L_NOMBRE    VARCHAR2(100);
        L_ESTADO    VARCHAR2(15);
    BEGIN
        SGCD_CREAR_DEPORTE('Futsal', V_DEPORTE);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_DEPORTES WHERE NOMBRE_DEPORTE = 'Futsal';
        COMPROBAR(V_DEPORTE > 3 AND V_CANTIDAD = 1, 'alta de deporte con ID de la secuencia');

        SGCD_CREAR_MODALIDAD(V_DEPORTE, 12, 'Futsal 5', V_MODALIDAD);
        SELECT MAX_JUGADORES_POR_EQUIPO INTO V_MAX FROM SGCD_MODALIDADES WHERE ID_MODALIDAD = V_MODALIDAD;
        COMPROBAR(V_MODALIDAD > 3 AND V_MAX = 12, 'alta de modalidad con su maximo de jugadores');

        SGCD_ACTUALIZAR_MODALIDAD(V_MODALIDAD, V_DEPORTE, 14, 'Futsal 5 reducido', 'INACTIVO');
        SELECT NOMBRE_MODALIDAD, ESTADO_MODALIDAD, MAX_JUGADORES_POR_EQUIPO
        INTO   V_NOMBRE, V_ESTADO, V_MAX
        FROM   SGCD_MODALIDADES WHERE ID_MODALIDAD = V_MODALIDAD;
        COMPROBAR(V_NOMBRE = 'Futsal 5 reducido' AND V_ESTADO = 'INACTIVO' AND V_MAX = 14,
                  'actualizar modalidad cambia nombre, estado y maximo');

        SGCD_LISTAR_MODALIDADES(C);
        LOOP
            FETCH C INTO L_ID, L_PADRE, L_MAX, L_NOMBRE, L_ESTADO;
            EXIT WHEN C%NOTFOUND;
            IF L_ID = V_MODALIDAD THEN
                V_ENCONTRADA := TRUE;
            END IF;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_ENCONTRADA, 'listar modalidades devuelve la recien creada');

        SGCD_CREAR_CANCHA(1, 'Cancha Futsal 1', 'FUTBOL_6', 'DISPONIBLE', V_CANCHA);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CANCHAS WHERE ID_RECINTO = 1;
        COMPROBAR(V_CANCHA > 10 AND V_CANTIDAD = 11, 'alta de cancha con ID de la secuencia');

        SGCD_CREAR_CANCHA_MODALIDAD(V_CANCHA, V_MODALIDAD);
        SGCD_LISTAR_CANCHA_MODALIDAD(V_CANCHA, C);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CANCHAS_MODALIDADES WHERE ID_CANCHA = V_CANCHA;
        FETCH C INTO L_ID, L_PADRE, L_NOMBRE;
        COMPROBAR(V_CANTIDAD = 1 AND L_NOMBRE = 'Futsal 5 reducido',
                  'el par cancha-modalidad se crea y se lista con el nombre de la modalidad');
        CLOSE C;

        SGCD_ACTUALIZAR_CANCHA_MODALIDAD(V_CANCHA, V_MODALIDAD, 1);
        SELECT COUNT(*) INTO V_CANTIDAD
        FROM   SGCD_CANCHAS_MODALIDADES WHERE ID_CANCHA = V_CANCHA AND ID_MODALIDAD = 1;
        COMPROBAR(V_CANTIDAD = 1, 'actualizar cancha-modalidad reemplaza el par');

        SGCD_BORRAR_CANCHA_MODALIDAD(V_CANCHA, 1);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CANCHAS_MODALIDADES WHERE ID_CANCHA = V_CANCHA;
        COMPROBAR(V_CANTIDAD = 0, 'borrar cancha-modalidad elimina el par');

        SGCD_BORRAR_CANCHA(V_CANCHA);
        SGCD_BORRAR_MODALIDAD(V_MODALIDAD);
        SGCD_BORRAR_DEPORTE(V_DEPORTE);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_CANCHAS WHERE ID_CANCHA = V_CANCHA;
        COMPROBAR(V_CANTIDAD = 0, 'borra cancha, modalidad y deporte cuando no tienen uso');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_DEPORTE(NULL, V); END;',
        -20830, 'rechaza un deporte sin nombre');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_DEPORTE(''Balonmano'', V); SGCD_CREAR_DEPORTE(''Balonmano'', V); END;',
        -20833, 'rechaza un deporte con nombre repetido');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_MODALIDAD(1, 0, ''Sin jugadores'', V); END;',
        -20831, 'rechaza una modalidad con maximo de jugadores en cero');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_MODALIDAD(999, 5, ''Deporte Fantasma'', V); END;',
        -2291, 'el padre inexistente lo rechaza la FK, no el procedimiento (a traducir en el API)');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_CANCHA(1, ''Cancha Duplicada'', ''FUTBOL_6'', ''DISPONIBLE'', V); SGCD_CREAR_CANCHA(1, ''Cancha Duplicada'', ''FUTBOL_6'', ''DISPONIBLE'', V); END;',
        -20863, 'rechaza una cancha con nombre repetido en el recinto');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_CANCHA(1, ''Cancha Nueva'', ''FUTBOL_6'', ''OCUPADA'', V); END;',
        -20860, 'rechaza un estado de cancha fuera de DISPONIBLE/MANTENCION/INACTIVA');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_CANCHA(999999, ''Cancha Nueva'', ''FUTBOL_6'', ''DISPONIBLE''); END;',
        -20862, 'actualizar cancha rechaza un ID inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_CANCHA(1); END;',
        -20864, 'rechaza borrar una cancha con tarifas y componentes');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_MODALIDAD(1); END;',
        -20835, 'rechaza borrar una modalidad en uso');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_DEPORTE(1); END;',
        -20835, 'rechaza borrar un deporte con modalidades');
    ESPERAR_ERROR(
        'BEGIN SGCD_CREAR_CANCHA_MODALIDAD(1, 1); END;',
        -20850, 'rechaza un par cancha-modalidad repetido');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_CANCHA_MODALIDAD(10, 2, 3); END;',
        -20851, 'actualizar rechaza un par cancha-modalidad inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_CANCHA_MODALIDAD(10, 2); END;',
        -20851, 'borrar rechaza un par cancha-modalidad inexistente');

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 4: mantenedores de horario y administradores');

    DECLARE
        V_HORARIO NUMBER;
        V_BLOQUE  NUMBER;
        V_USUARIO NUMBER;
        V_CLIENTE NUMBER;
        V_ADMIN   NUMBER;
        V_CANTIDAD NUMBER;
        V_APERTURA VARCHAR2(5);
        V_CIERRE   VARCHAR2(5);
        V_NOMBRE   VARCHAR2(100);
        V_ESTADO   VARCHAR2(10);
        C          SYS_REFCURSOR;
        L_ID       NUMBER;
        L_DIA      NUMBER;
        L_APERTURA VARCHAR2(5);
        L_CIERRE   VARCHAR2(5);
        L_USUARIO  NUMBER;
        L_NOMBRE   VARCHAR2(100);
        L_ESTADO   VARCHAR2(15);
    BEGIN
        SGCD_CREAR_HORARIO(1, 1, '08:00', '22:00', V_HORARIO);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_HORARIOS WHERE ID_RECINTO = 1;
        COMPROBAR(V_HORARIO > 6 AND V_CANTIDAD = 7, 'alta de horario para el lunes, que faltaba');

        SGCD_LISTAR_HORARIOS(1, C);
        V_CANTIDAD := 0;
        LOOP
            FETCH C INTO L_ID, L_DIA, L_APERTURA, L_CIERRE;
            EXIT WHEN C%NOTFOUND;
            V_CANTIDAD := V_CANTIDAD + 1;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CANTIDAD = 7, 'listar horarios devuelve la semana completa');

        SGCD_ACTUALIZAR_HORARIO(V_HORARIO, '09:00', '21:00');
        SELECT HORA_APERTURA, HORA_CIERRE INTO V_APERTURA, V_CIERRE
        FROM   SGCD_HORARIOS WHERE ID_HORARIO = V_HORARIO;
        COMPROBAR(V_APERTURA = '09:00' AND V_CIERRE = '21:00', 'actualizar horario cambia la ventana');

        SGCD_CREAR_BLOQUE_HORARIO(V_HORARIO, '18:00', '19:00', V_BLOQUE);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_BLOQUES_HORARIOS WHERE ID_HORARIO = V_HORARIO;
        COMPROBAR(V_BLOQUE > 82 AND V_CANTIDAD = 1, 'alta de bloque con ID de la secuencia');

        SGCD_ACTUALIZAR_BLOQUE_HORARIO(V_BLOQUE, '19:00', '20:00');
        SELECT HORA_INICIO INTO V_APERTURA FROM SGCD_BLOQUES_HORARIOS
        WHERE  ID_BLOQUE_HORARIO = V_BLOQUE;
        COMPROBAR(V_APERTURA = '19:00', 'actualizar bloque mueve la hora de inicio');

        SGCD_BORRAR_BLOQUE_HORARIO(V_BLOQUE);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_BLOQUES_HORARIOS WHERE ID_HORARIO = V_HORARIO;
        COMPROBAR(V_CANTIDAD = 0, 'borrar bloque lo quita de la plantilla');

        SGCD_BORRAR_HORARIO(V_HORARIO);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_HORARIOS WHERE ID_HORARIO = V_HORARIO;
        COMPROBAR(V_CANTIDAD = 0, 'borrar horario sin bloques funciona');

        SGCD_PKG_AUTH.crear_usuario('cta_admin_nuevo', RPAD('x', 60, 'x'), 'ADMINISTRADOR', V_USUARIO);
        SGCD_CREAR_ADMINISTRADOR(V_USUARIO, 'Administrador Nuevo', 'ACTIVO', V_ADMIN);
        SELECT NOMBRE_ADMINISTRADOR INTO V_NOMBRE FROM SGCD_ADMINISTRADORES
        WHERE  ID_ADMINISTRADOR = V_ADMIN;
        COMPROBAR(V_ADMIN > 1 AND V_NOMBRE = 'Administrador Nuevo',
                  'alta de administrador vinculado a una cuenta con rol');

        SGCD_ACTUALIZAR_ADMINISTRADOR(V_ADMIN, 'Administrador Nuevo 2', 'INACTIVO');
        SELECT NOMBRE_ADMINISTRADOR, ESTADO_ADMINISTRADOR INTO V_NOMBRE, V_ESTADO
        FROM   SGCD_ADMINISTRADORES WHERE ID_ADMINISTRADOR = V_ADMIN;
        COMPROBAR(V_NOMBRE = 'Administrador Nuevo 2' AND V_ESTADO = 'INACTIVO',
                  'actualizar administrador cambia nombre y estado');

        SGCD_LISTAR_ADMINISTRADORES(C);
        V_CANTIDAD := 0;
        LOOP
            FETCH C INTO L_ID, L_USUARIO, L_NOMBRE, L_ESTADO;
            EXIT WHEN C%NOTFOUND;
            IF L_ID = V_ADMIN THEN
                V_CANTIDAD := 1;
            END IF;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CANTIDAD = 1, 'listar administradores incluye el nuevo');

        SGCD_BORRAR_ADMINISTRADOR(V_ADMIN);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_ADMINISTRADORES WHERE ID_ADMINISTRADOR = V_ADMIN;
        COMPROBAR(V_CANTIDAD = 0, 'borrar administrador sin reservas funciona');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_HORARIO(1, 8, ''08:00'', ''22:00'', V); END;',
        -20840, 'rechaza un dia fuera de 1..7');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_HORARIO(1, 2, ''08:00'', ''22:00'', V); END;',
        -20841, 'rechaza un horario repetido para el mismo dia y recinto');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_HORARIO(3, ''08:00'', ''12:00''); END;',
        -20842, 'rechaza achicar el horario con bloques afuera');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_HORARIO(999999, ''08:00'', ''22:00''); END;',
        -20843, 'actualizar horario rechaza un ID inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_HORARIO(1); END;',
        -20844, 'rechaza borrar un horario con bloques');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_HORARIO(999999); END;',
        -20843, 'borrar horario rechaza un ID inexistente');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_BLOQUE_HORARIO(1, ''18:30'', ''19:30'', V); END;',
        -20824, 'rechaza un bloque solapado con otro del mismo horario');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_BLOQUE_HORARIO(1, ''07:00'', ''08:00'', V); END;',
        -20823, 'rechaza un bloque fuera de la ventana del recinto');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_BLOQUE_HORARIO(1, ''18:00'', ''18:30'', V); END;',
        -20822, 'rechaza un bloque que no dura una hora');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_BLOQUE_HORARIO(1, ''18:5'', ''19:00'', V); END;',
        -20821, 'rechaza una hora mal escrita');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_BLOQUE_HORARIO(999999, ''18:00'', ''19:00'', V); END;',
        -20820, 'rechaza un bloque sobre un horario inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_BLOQUE_HORARIO(999999); END;',
        -20825, 'borrar bloque rechaza un ID inexistente');

    DECLARE
        V_USUARIO NUMBER;
        V_CLIENTE NUMBER;
    BEGIN
        SGCD_PKG_AUTH.crear_usuario('cta_admin_repetido', RPAD('x', 60, 'x'), 'ADMINISTRADOR', V_USUARIO);
        SGCD_PKG_AUTH.crear_usuario('cta_cliente_admin', RPAD('x', 60, 'x'), 'CLIENTE', V_CLIENTE);
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_CREAR_ADMINISTRADOR(' || V_USUARIO || ', ''Repetido'', ''ACTIVO'', V); SGCD_CREAR_ADMINISTRADOR(' || V_USUARIO || ', ''Repetido'', ''ACTIVO'', V); END;',
            -20863, 'rechaza vincular dos veces la misma cuenta');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_CREAR_ADMINISTRADOR(' || V_CLIENTE || ', ''Cliente'', ''ACTIVO'', V); END;',
            -20861, 'rechaza una cuenta que no tiene rol de administrador');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_CREAR_ADMINISTRADOR(999999, ''Fantasma'', ''ACTIVO'', V); END;',
            -20861, 'rechaza una cuenta inexistente');
        ESPERAR_ERROR(
            'BEGIN SGCD_ACTUALIZAR_ADMINISTRADOR(999999, ''Fantasma'', ''ACTIVO''); END;',
            -20862, 'actualizar administrador rechaza un ID inexistente');
        ESPERAR_ERROR(
            'BEGIN SGCD_BORRAR_ADMINISTRADOR(999999); END;',
            -20862, 'borrar administrador rechaza un ID inexistente');
    END;

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 5: mantenedor de tarifas');

    DECLARE
        V_HOY     NUMBER;
        V_MANANA  NUMBER;
        V_CANTIDAD NUMBER;
        V_VALOR   NUMBER;
        V_ENCONTRADA BOOLEAN := FALSE;
        C         SYS_REFCURSOR;
        L_ID      NUMBER;
        L_CANCHA  NUMBER;
        L_MODALIDAD NUMBER;
        L_DIA     NUMBER;
        L_DESDE   VARCHAR2(5);
        L_HASTA   VARCHAR2(5);
        L_VIG_DESDE DATE;
        L_VIG_HASTA DATE;
        L_VALOR   NUMBER;
        L_ESTADO  VARCHAR2(10);
    BEGIN
        SGCD_CREAR_TARIFA(1, 1, 1, '08:00', '18:00', TRUNC(SYSDATE), NULL, 10000, V_HOY);
        COMPROBAR(V_HOY > 120, 'alta de tarifa con ID de la secuencia');

        SGCD_CREAR_TARIFA(1, 1, 1, '18:00', '22:00', TRUNC(SYSDATE) + 1, NULL, 11000, V_MANANA);
        COMPROBAR(V_MANANA > V_HOY, 'alta de una segunda franja con vigencia desde manana');

        SGCD_ACTUALIZAR_TARIFA(V_MANANA, 1, '18:00', '22:00', TRUNC(SYSDATE) + 1, NULL, 12000);
        SELECT VALOR_HORA INTO V_VALOR FROM SGCD_TARIFAS WHERE ID_TARIFA = V_MANANA;
        COMPROBAR(V_VALOR = 12000, 'actualizar tarifa cambia el valor si aun no empieza');

        SGCD_CAMBIAR_ESTADO_TARIFA(V_HOY, 'inactiva');
        SELECT ESTADO_TARIFA INTO L_ESTADO FROM SGCD_TARIFAS WHERE ID_TARIFA = V_HOY;
        COMPROBAR(L_ESTADO = 'INACTIVA', 'cambiar estado desactiva la tarifa');
        SGCD_CAMBIAR_ESTADO_TARIFA(V_HOY, 'ACTIVA');

        SGCD_LISTAR_TARIFAS(1, 1, 'ACTIVA', C);
        V_CANTIDAD := 0;
        LOOP
            FETCH C INTO L_ID, L_CANCHA, L_MODALIDAD, L_DIA, L_DESDE, L_HASTA,
                         L_VIG_DESDE, L_VIG_HASTA, L_VALOR, L_ESTADO;
            EXIT WHEN C%NOTFOUND;
            IF L_ID IN (V_HOY, V_MANANA) THEN
                V_CANTIDAD := V_CANTIDAD + 1;
            END IF;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CANTIDAD = 2, 'listar tarifas por cancha, modalidad y estado devuelve las dos nuevas');

        SGCD_BORRAR_TARIFA(V_MANANA);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_TARIFAS WHERE ID_TARIFA = V_MANANA;
        COMPROBAR(V_CANTIDAD = 0, 'borra la tarifa que aun no empieza');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 1, 1, ''12:00'', ''13:00'', TRUNC(SYSDATE), NULL, 9000, V); END;',
        -20808, 'rechaza una franja solapada con la misma vigencia');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 1, 8, ''08:00'', ''12:00'', TRUNC(SYSDATE), NULL, 9000, V); END;',
        -20804, 'rechaza un dia fuera de 1..7');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 1, 1, ''18:00'', ''08:00'', TRUNC(SYSDATE), NULL, 9000, V); END;',
        -20805, 'rechaza una franja que termina antes de empezar');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 1, 1, ''08:00'', ''12:00'', TRUNC(SYSDATE) - 5, NULL, 9000, V); END;',
        -20806, 'rechaza una vigencia que ya paso');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 1, 1, ''08:00'', ''12:00'', TRUNC(SYSDATE), NULL, 0, V); END;',
        -20807, 'rechaza un valor por hora en cero');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_TARIFA(1, 2, 1, ''08:00'', ''12:00'', TRUNC(SYSDATE), NULL, 9000, V); END;',
        -20803, 'rechaza una cancha que no admite esa modalidad');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_TARIFA(1, 2, ''08:00'', ''12:00'', TRUNC(SYSDATE), NULL, 9000); END;',
        -20810, 'rechaza modificar una tarifa ya iniciada');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_TARIFA(1); END;',
        -20811, 'rechaza borrar una tarifa ya iniciada');
    ESPERAR_ERROR(
        'BEGIN SGCD_CAMBIAR_ESTADO_TARIFA(1, ''PAUSADA''); END;',
        -20809, 'rechaza un estado distinto de ACTIVA o INACTIVA');
    ESPERAR_ERROR(
        'BEGIN SGCD_CAMBIAR_ESTADO_TARIFA(0, ''ACTIVA''); END;',
        -20801, 'rechaza un ID de tarifa invalido');
    ESPERAR_ERROR(
        'BEGIN SGCD_ACTUALIZAR_TARIFA(999999, 1, ''08:00'', ''12:00'', TRUNC(SYSDATE) + 1, NULL, 9000); END;',
        -20802, 'actualizar rechaza una tarifa inexistente');
    ESPERAR_ERROR(
        'BEGIN SGCD_BORRAR_TARIFA(999999); END;',
        -20802, 'borrar rechaza una tarifa inexistente');
    ESPERAR_ERROR(
        'DECLARE C SYS_REFCURSOR; BEGIN SGCD_LISTAR_TARIFAS(1, 1, ''PAUSADA'', C); END;',
        -20812, 'rechaza un filtro de estado invalido');
    ESPERAR_ERROR(
        'DECLARE C SYS_REFCURSOR; BEGIN SGCD_LISTAR_TARIFAS(-1, 1, NULL, C); END;',
        -20803, 'rechaza un filtro de cancha invalido');

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/


DECLARE
    V_FALLAS NUMBER := 0;

    PROCEDURE OK (P_TEXTO VARCHAR2) IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
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

    PROCEDURE ESPERAR_ERROR (P_BLOQUE VARCHAR2, P_CODIGO NUMBER, P_NOMBRE VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE P_BLOQUE;
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 6: SGCD_PKG_TARIFAS');

    DECLARE
        V_MARTES  DATE := TRUNC(SYSDATE, 'IW') + 1;
        V_DOMINGO DATE := TRUNC(SYSDATE, 'IW') + 6;
        V_LUNES   DATE := TRUNC(SYSDATE, 'IW');
        V_TOTAL   NUMBER;
        V_CANTIDAD NUMBER;
        C         SYS_REFCURSOR;
        L_INICIO  VARCHAR2(5);
        L_TERMINO VARCHAR2(5);
        L_VALOR   NUMBER;
        L_PRIMERO NUMBER;
        L_SEGUNDO NUMBER;
    BEGIN
        COMPROBAR(SGCD_PKG_TARIFAS.valor_bloque(1, 1, V_MARTES, '10:00') = 18000,
                  'cotiza la franja diurna del futbol 6 en 18.000');
        COMPROBAR(SGCD_PKG_TARIFAS.valor_bloque(1, 1, V_MARTES, '20:00') = 22000,
                  'cotiza la franja nocturna en 22.000');
        COMPROBAR(SGCD_PKG_TARIFAS.valor_bloque(1, 1, V_DOMINGO, '19:00') = 22000,
                  'el domingo cotiza la franja nocturna aunque cierre a las 20:00');

        SGCD_PKG_TARIFAS.cotizar(1, 1, V_MARTES, '17:00', 2, V_TOTAL, C);
        COMPROBAR(V_TOTAL = 40000, 'dos bloques consecutivos suman 40.000 (18.000 + 22.000)');
        V_CANTIDAD := 0;
        LOOP
            FETCH C INTO L_INICIO, L_TERMINO, L_VALOR;
            EXIT WHEN C%NOTFOUND;
            V_CANTIDAD := V_CANTIDAD + 1;
            IF V_CANTIDAD = 1 THEN
                L_PRIMERO := L_VALOR;
            ELSE
                L_SEGUNDO := L_VALOR;
            END IF;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CANTIDAD = 2 AND L_PRIMERO = 18000 AND L_SEGUNDO = 22000,
                  'el detalle trae un valor por bloque');
    END;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN V := SGCD_PKG_TARIFAS.valor_bloque(1, 1, TRUNC(SYSDATE, ''IW''), ''10:00''); END;',
        -20006, 'el lunes no hay tarifa porque el recinto esta cerrado');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; C SYS_REFCURSOR; BEGIN SGCD_PKG_TARIFAS.cotizar(1, 1, TRUNC(SYSDATE, ''IW'') + 1, ''21:00'', 2, V, C); END;',
        -20006, 'no cotiza un bloque que se sale de la ultima franja');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; C SYS_REFCURSOR; BEGIN SGCD_PKG_TARIFAS.cotizar(1, 1, TRUNC(SYSDATE, ''IW'') + 1, ''17:00'', 0, V, C); END;',
        -20019, 'rechaza una cantidad de bloques en cero');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN V := SGCD_PKG_TARIFAS.valor_bloque(1, 1, TRUNC(SYSDATE, ''IW'') + 1, ''25:00''); END;',
        -20019, 'rechaza una hora mal escrita');

    DECLARE
        V_MARTES DATE := TRUNC(SYSDATE, 'IW') + 1;
    BEGIN
        INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA, HORA_DESDE, HORA_HASTA,
                                  VIGENTE_DESDE, VIGENTE_HASTA, VALOR_HORA, ESTADO_TARIFA)
        VALUES (1, 1, 2, '10:00', '11:00', TRUNC(SYSDATE) + 60, NULL, 99999, 'ACTIVA');
        COMPROBAR(SGCD_PKG_TARIFAS.valor_bloque(1, 1, V_MARTES, '10:00') = 18000,
                  'una tarifa con vigencia futura no cotiza todavia');
        DELETE FROM SGCD_TARIFAS WHERE ID_CANCHA = 1 AND HORA_DESDE = '10:00';

        INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA, HORA_DESDE, HORA_HASTA,
                                  VIGENTE_DESDE, VIGENTE_HASTA, VALOR_HORA, ESTADO_TARIFA)
        VALUES (1, 1, 2, '09:00', '11:00', TRUNC(SYSDATE), NULL, 15000, 'ACTIVA');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN V := SGCD_PKG_TARIFAS.valor_bloque(1, 1, TRUNC(SYSDATE, ''IW'') + 1, ''10:00''); END;',
            -20033, 'ante dos tarifas activas para el mismo bloque no elige una: falla');
    END;

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/
