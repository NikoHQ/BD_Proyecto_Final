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

        DECLARE
            V_RESERVAS NUMBER;
            V_VIGENTES NUMBER;
            V_PAGADO   NUMBER;
            V_CUENTA   NUMBER;
            V_EVENTOS  NUMBER;
        BEGIN
            C := SGCD_PKG_CLIENTES.ficha_detalle(V_WEB);
            FETCH C INTO F_ID, F_RUT, F_DV, F_NOMBRE, F_CORREO, F_FONO, F_ESTADO, F_USR,
                         V_RESERVAS, V_VIGENTES, V_PAGADO, V_CUENTA, V_EVENTOS;
            COMPROBAR(F_ID = V_WEB AND V_CUENTA = 1 AND V_EVENTOS >= 2
                      AND V_RESERVAS = 0 AND V_VIGENTES = 0 AND V_PAGADO = 0,
                      'ficha_detalle incluye resumen de actividad y auditoria');
            CLOSE C;
            C := SGCD_PKG_CLIENTES.ficha_detalle(999999);
            FETCH C INTO F_ID, F_RUT, F_DV, F_NOMBRE, F_CORREO, F_FONO, F_ESTADO, F_USR,
                         V_RESERVAS, V_VIGENTES, V_PAGADO, V_CUENTA, V_EVENTOS;
            COMPROBAR(C%NOTFOUND, 'ficha_detalle de un ID inexistente devuelve cero filas');
            CLOSE C;
        END;

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
        V_MIN       NUMBER;
        V_MAX       NUMBER;
        V_NOMBRE    VARCHAR2(80);
        V_ESTADO    VARCHAR2(10);
        C           SYS_REFCURSOR;
        -- columnas de los cursores
        L_ID        NUMBER;
        L_PADRE     NUMBER;
        L_MIN       NUMBER;
        L_MAX       NUMBER;
        L_NOMBRE    VARCHAR2(100);
        L_ESTADO    VARCHAR2(15);
    BEGIN
        SGCD_CREAR_DEPORTE('Futsal', V_DEPORTE);
        SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_DEPORTES WHERE NOMBRE_DEPORTE = 'Futsal';
        COMPROBAR(V_DEPORTE > 3 AND V_CANTIDAD = 1, 'alta de deporte con ID de la secuencia');

        SGCD_CREAR_MODALIDAD(V_DEPORTE, 5, 12, 'Futsal 5', V_MODALIDAD);
        SELECT MIN_JUGADORES_POR_EQUIPO, MAX_JUGADORES_POR_EQUIPO
        INTO   V_MIN, V_MAX
        FROM   SGCD_MODALIDADES WHERE ID_MODALIDAD = V_MODALIDAD;
        COMPROBAR(V_MODALIDAD > 3 AND V_MIN = 5 AND V_MAX = 12,
                  'alta de modalidad con su rango de jugadores');

        SGCD_ACTUALIZAR_MODALIDAD(V_MODALIDAD, V_DEPORTE, 1, 14, 'Futsal 5 reducido', 'INACTIVO');
        SELECT NOMBRE_MODALIDAD, ESTADO_MODALIDAD, MIN_JUGADORES_POR_EQUIPO, MAX_JUGADORES_POR_EQUIPO
        INTO   V_NOMBRE, V_ESTADO, V_MIN, V_MAX
        FROM   SGCD_MODALIDADES WHERE ID_MODALIDAD = V_MODALIDAD;
        COMPROBAR(V_NOMBRE = 'Futsal 5 reducido' AND V_ESTADO = 'INACTIVO'
                  AND V_MIN = 1 AND V_MAX = 14,
                  'actualizar modalidad cambia nombre, estado y rango');

        SGCD_LISTAR_MODALIDADES(C);
        LOOP
            FETCH C INTO L_ID, L_PADRE, L_MIN, L_MAX, L_NOMBRE, L_ESTADO;
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
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_MODALIDAD(1, 0, 5, ''Sin jugadores'', V); END;',
        -20831, 'rechaza una modalidad con minimo de jugadores en cero');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_CREAR_MODALIDAD(999, 1, 5, ''Deporte Fantasma'', V); END;',
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
        L_LOGIN    VARCHAR2(50);
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
            FETCH C INTO L_ID, L_USUARIO, L_NOMBRE, L_ESTADO, L_LOGIN;
            EXIT WHEN C%NOTFOUND;
            IF L_ID = V_ADMIN AND L_LOGIN = 'cta_admin_nuevo' THEN
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
        VALUES (1, 1, 2, '09:00', '11:00', V_MARTES, NULL, 15000, 'ACTIVA');
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
DBMS_OUTPUT.PUT_LINE('--- UNIDAD 7: SGCD_PKG_RESERVAS');

    DECLARE
        V_CLI      NUMBER;
        V_INAC     NUMBER;
        V_CREADA   BOOLEAN;
        V_ADMIN    NUMBER;
        V_R1       NUMBER;
        V_R2       NUMBER;
        V_R3       NUMBER;
        V_R4       NUMBER;
        V_R5       NUMBER;
        V_R6       NUMBER;
        V_R7       NUMBER;
        V_R8       NUMBER;
        V_ESTADO   VARCHAR2(15);
        V_IMPORTE  NUMBER(12,2);
        V_ADMIN_R  NUMBER;
        V_CANTIDAD NUMBER;
        V_HORA     VARCHAR2(5);
        V_MARTES   DATE := TRUNC(SYSDATE, 'IW') + 8;
        C          SYS_REFCURSOR;
        A_ID       NUMBER;
        A_INICIO   DATE;
        A_TERMINO  DATE;
        A_CANCHA   NUMBER;
        A_NOMBRE_C VARCHAR2(100);
        A_MOD      NUMBER;
        A_NOMBRE_M VARCHAR2(100);
        A_CLI      NUMBER;
        A_NOMBRE_L VARCHAR2(100);
        A_TORNEO   NUMBER;
        A_NOMBRE_T VARCHAR2(100);
        A_ORIGEN   VARCHAR2(15);
        A_ESTADO_R VARCHAR2(15);
        A_IMPORTE  NUMBER(12,2);

    BEGIN

    SGCD_PKG_CLIENTES.crear_ficha(32000001, '7', 'Cliente Reservas', NULL, NULL,
                                  V_CLI, V_CREADA);
    SGCD_PKG_CLIENTES.crear_ficha(32000002, '5', 'Cliente Inactivo', NULL, NULL,
                                  V_INAC, V_CREADA);
    SGCD_PKG_CLIENTES.cambiar_estado(V_INAC, 'INACTIVO');
    SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
    FROM   SGCD_ADMINISTRADORES a
    WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';

    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '10:00', 1,
                                    'MOSTRADOR', V_R1);
    SELECT r.ESTADO_RESERVA, r.IMPORTE_ACORDADO, r.ID_ADMINISTRADOR
    INTO   V_ESTADO, V_IMPORTE, V_ADMIN_R
    FROM   SGCD_RESERVAS r
    WHERE  r.ID_RESERVA = V_R1;
    COMPROBAR(V_ESTADO = 'CONFIRMADA' AND V_IMPORTE = 18000,
              'crear_reserva de mostrador nace confirmada y cobra una tarifa de dia');
    COMPROBAR(V_ADMIN_R = V_ADMIN, 'la reserva de mostrador guarda al administrador');
    SELECT TO_CHAR(r.TERMINO_RESERVA, 'HH24:MI') INTO V_HORA
    FROM   SGCD_RESERVAS r
    WHERE  r.ID_RESERVA = V_R1;
    COMPROBAR(V_HORA = '11:00', 'un bloque termina exactamente una hora despues');

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20043, 'rechaza el mismo bloque en la misma cancha');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''09:00'', 2, ''MOSTRADOR'', V); END;',
        -20043, 'rechaza un solape parcial contra una reserva existente');

    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '14:00', 2,
                                    'MOSTRADOR', V_R2);
    SELECT r.IMPORTE_ACORDADO INTO V_IMPORTE FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R2;
    COMPROBAR(V_IMPORTE = 36000, 'dos bloques suman dos tarifas: 36.000');

    SGCD_PKG_RESERVAS.crear_solicitud_web(V_CLI, 4, 1, V_MARTES, '12:00', 1, V_R3);
    SELECT r.ESTADO_RESERVA, r.ID_ADMINISTRADOR INTO V_ESTADO, V_ADMIN_R
    FROM   SGCD_RESERVAS r
    WHERE  r.ID_RESERVA = V_R3;
    COMPROBAR(V_ESTADO = 'PENDIENTE' AND V_ADMIN_R IS NULL,
              'la solicitud web nace pendiente y sin administrador');
    COMPROBAR(SGCD_PKG_RESERVAS.disponible(4, 1, V_MARTES, '12:00', 1) = 0
              AND SGCD_PKG_RESERVAS.disponible(4, 1, V_MARTES, '13:00', 1) = 1,
              'una solicitud pendiente retiene el bloque y el vecino sigue libre');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''12:00'', 1, ''MOSTRADOR'', V); END;',
        -20043, 'la solicitud web pendiente bloquea el mostrador');

    SGCD_PKG_RESERVAS.confirmar_reserva(V_R3);
    SELECT r.ESTADO_RESERVA INTO V_ESTADO FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R3;
    COMPROBAR(V_ESTADO = 'CONFIRMADA', 'confirmar_reserva pasa la solicitud a confirmada');
    ESPERAR_ERROR('BEGIN SGCD_PKG_RESERVAS.confirmar_reserva(' || V_R3 || '); END;',
                  -20046, 'no se confirma dos veces');

    SGCD_PKG_RESERVAS.cancelar_reserva(V_R1);
    SELECT r.ESTADO_RESERVA INTO V_ESTADO FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R1;
    COMPROBAR(V_ESTADO = 'CANCELADA', 'cancelar_reserva deja la reserva cancelada');
    ESPERAR_ERROR('BEGIN SGCD_PKG_RESERVAS.cancelar_reserva(' || V_R1 || '); END;',
                  -20046, 'no se cancela dos veces');

    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '10:00', 1,
                                    'MOSTRADOR', V_R4);
    COMPROBAR(SGCD_PKG_RESERVAS.disponible(4, 1, V_MARTES, '10:00', 1) = 0,
              'el bloque cancelado se puede volver a reservar y queda ocupado');

    SGCD_PKG_RESERVAS.reprogramar_reserva(V_R4, V_MARTES, '18:00', 1);
    SELECT r.IMPORTE_ACORDADO INTO V_IMPORTE FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R4;
    COMPROBAR(V_IMPORTE = 22000
              AND SGCD_PKG_RESERVAS.disponible(4, 1, V_MARTES, '10:00', 1) = 1,
              'reprogramar libera el bloque viejo y recotiza la tarifa de noche');

    INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO, ESTADO_PAGO)
    VALUES (V_R4, 18000, 'EFECTIVO', 'PAGADO');
    SGCD_PKG_RESERVAS.reprogramar_reserva(V_R4, V_MARTES, '16:00', 2);
    SELECT r.IMPORTE_ACORDADO INTO V_IMPORTE FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R4;
    COMPROBAR(V_IMPORTE = 36000,
              'si el nuevo total supera lo pagado, el importe sube y queda diferencia por cobrar');
    SGCD_PKG_RESERVAS.reprogramar_reserva(V_R4, V_MARTES, '16:00', 1);
    SELECT r.IMPORTE_ACORDADO INTO V_IMPORTE FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R4;
    COMPROBAR(V_IMPORTE = 36000,
              'si el nuevo total baja, se mantiene el importe original sin reembolso');

    SGCD_PKG_RESERVAS.cancelar_reserva(V_R2);
    ESPERAR_ERROR(
        'BEGIN SGCD_PKG_RESERVAS.reprogramar_reserva(' || V_R2
        || ', TRUNC(SYSDATE, ''IW'') + 8, ''11:00'', 1); END;',
        -20046, 'no se reprograma una reserva cancelada');

    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 7, 1, V_MARTES, '10:00', 1,
                                    'MOSTRADOR', V_R5);
    SELECT r.IMPORTE_ACORDADO INTO V_IMPORTE FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R5;
    COMPROBAR(V_IMPORTE = 45000, 'la cancha grande cotiza su propia tarifa');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 1, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20043, 'la cancha grande ocupa su componente 1');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 3, 1, TRUNC(SYSDATE, ''IW'') + 8, ''09:00'', 2, ''MOSTRADOR'', V); END;',
        -20043, 'la cancha grande ocupa su componente 3 en cualquier solape');

    SGCD_PKG_RESERVAS.cancelar_reserva(V_R5);
    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 2, 1, V_MARTES, '10:00', 1,
                                    'MOSTRADOR', V_R6);
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 7, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20043, 'una componente ocupada bloquea la cancha grande');
    SGCD_PKG_RESERVAS.cancelar_reserva(V_R6);

    UPDATE SGCD_CANCHAS SET ESTADO_CANCHA = 'MANTENCION' WHERE ID_CANCHA = 6;
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 6, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20041, 'no reserva una cancha en mantencion');
    UPDATE SGCD_CANCHAS SET ESTADO_CANCHA = 'DISPONIBLE' WHERE ID_CANCHA = 6;

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 8, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20041, 'rechaza una modalidad que la cancha no admite');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 13, ''20:00'', 1, ''MOSTRADOR'', V); END;',
        -20042, 'el domingo cierra a las 20:00 y no admite un bloque mas');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 7, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20042, 'el lunes el recinto no abre');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''07:00'', 1, ''MOSTRADOR'', V); END;',
        -20042, 'rechaza una hora antes de la apertura');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''21:00'', 2, ''MOSTRADOR'', V); END;',
        -20042, 'rechaza dos bloques que se salen del cierre');

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE) - 1, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20044, 'no reserva en una fecha pasada');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE) + 91, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20044, 'no reserva mas alla de 90 dias');

    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 0, ''MOSTRADOR'', V); END;',
        -20040, 'rechaza una cantidad de bloques en cero');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, NULL, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20040, 'rechaza una reserva sin fecha');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''TORNEO'', V); END;',
        -20040, 'el origen TORNEO no se usa en este paquete');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''WEB'', V); END;',
        -20040, 'una solicitud web no lleva administrador');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_CLI
        || ', NULL, 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
        -20045, 'el mostrador exige administrador');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_INAC || ', ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''09:00'', 1, ''MOSTRADOR'', V); END;',
        -20045, 'rechaza un cliente inactivo');
    ESPERAR_ERROR(
        'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(NULL, ' || V_ADMIN
        || ', 4, 1, TRUNC(SYSDATE, ''IW'') + 8, ''09:00'', 1, ''MOSTRADOR'', V); END;',
        -20045, 'rechaza una reserva sin cliente');

    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '20:00', 1,
                                    'MOSTRADOR', V_R7);
    UPDATE SGCD_RESERVAS
    SET    INICIO_RESERVA = TRUNC(SYSDATE) - 2,
           TERMINO_RESERVA = TRUNC(SYSDATE) - 2 + 1 / 24
    WHERE  ID_RESERVA = V_R7;
    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '21:00', 1,
                                    'MOSTRADOR', V_R8);
    SGCD_PKG_RESERVAS.cancelar_reserva(V_R8);
    UPDATE SGCD_RESERVAS
    SET    INICIO_RESERVA = TRUNC(SYSDATE) - 2,
           TERMINO_RESERVA = TRUNC(SYSDATE) - 2 + 1 / 24
    WHERE  ID_RESERVA = V_R8;

    V_CANTIDAD := SGCD_PKG_RESERVAS.marcar_completadas();
    SELECT r.ESTADO_RESERVA INTO V_ESTADO FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R7;
    COMPROBAR(V_CANTIDAD >= 1 AND V_ESTADO = 'COMPLETADA',
              'marcar_completadas cierra la confirmada cuya fecha ya paso');
    SELECT r.ESTADO_RESERVA INTO V_ESTADO FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R8;
    COMPROBAR(V_ESTADO = 'CANCELADA', 'marcar_completadas no toca las canceladas');

    V_CANTIDAD := 0;
    SGCD_PKG_RESERVAS.agenda(V_MARTES, V_MARTES, 4, NULL, C);
    LOOP
        FETCH C INTO A_ID, A_INICIO, A_TERMINO, A_CANCHA, A_NOMBRE_C, A_MOD,
                    A_NOMBRE_M, A_CLI, A_NOMBRE_L, A_TORNEO, A_NOMBRE_T,
                    A_ORIGEN, A_ESTADO_R, A_IMPORTE;
        EXIT WHEN C%NOTFOUND;
        V_CANTIDAD := V_CANTIDAD + 1;
    END LOOP;
    CLOSE C;
    COMPROBAR(V_CANTIDAD >= 3, 'la agenda trae el detalle de la cancha en el dia');

    V_CANTIDAD := 0;
    SGCD_PKG_RESERVAS.agenda(V_MARTES, V_MARTES, NULL, V_CLI, C);
    LOOP
        FETCH C INTO A_ID, A_INICIO, A_TERMINO, A_CANCHA, A_NOMBRE_C, A_MOD,
                    A_NOMBRE_M, A_CLI, A_NOMBRE_L, A_TORNEO, A_NOMBRE_T,
                    A_ORIGEN, A_ESTADO_R, A_IMPORTE;
        EXIT WHEN C%NOTFOUND;
        IF A_CLI <> V_CLI THEN
            V_CANTIDAD := -1000;
        ELSE
            V_CANTIDAD := V_CANTIDAD + 1;
        END IF;
    END LOOP;
    CLOSE C;
    COMPROBAR(V_CANTIDAD >= 3, 'la agenda filtra por cliente sin mezclar ajenos');

    ESPERAR_ERROR(
        'DECLARE C SYS_REFCURSOR; BEGIN SGCD_PKG_RESERVAS.agenda(TRUNC(SYSDATE, ''IW'') + 8, TRUNC(SYSDATE, ''IW'') + 7, NULL, NULL, C); END;',
        -20044, 'la agenda rechaza un rango invertido');
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 8: SGCD_PKG_PAGOS');

    DECLARE
        V_CLI        NUMBER;
        V_CREADA     BOOLEAN;
        V_ADMIN      NUMBER;
        V_USR_INAC   NUMBER;
        V_ADMIN_INAC NUMBER;
        V_R1         NUMBER;
        V_R2         NUMBER;
        V_R3         NUMBER;
        V_R4         NUMBER;
        V_R5         NUMBER;
        V_R6         NUMBER;
        V_ID1        NUMBER;
        V_ID2        NUMBER;
        V_ESTADO     VARCHAR2(15);
        V_MEDIO      VARCHAR2(20);
        V_IMPORTE    NUMBER(12,2);
        V_FECHA      DATE;
        V_CANTIDAD   NUMBER;
        C            SYS_REFCURSOR;
        F_ID_PAGO    NUMBER;
        F_ID_RES     NUMBER;
        F_IMPORTE    NUMBER(12,2);
        F_FECHA      DATE;
        F_MEDIO      VARCHAR2(20);
        F_ESTADO     VARCHAR2(15);
        F_ACORDADO   NUMBER(12,2);
        F_SALDO      NUMBER(12,2);
        V_MARTES     DATE := TRUNC(SYSDATE, 'IW') + 8;
    BEGIN
        SGCD_PKG_CLIENTES.crear_ficha(33000001, '5', 'Cliente Pagos', NULL, NULL,
                                      V_CLI, V_CREADA);
        SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
        FROM   SGCD_ADMINISTRADORES a
        WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';
        SGCD_PKG_AUTH.crear_usuario('cta_pago_inactivo', RPAD('x', 60, 'x'),
                                    'ADMINISTRADOR', V_USR_INAC);
        SGCD_CREAR_ADMINISTRADOR(V_USR_INAC, 'Admin Inactivo Pagos', 'INACTIVO', V_ADMIN_INAC);

        SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '10:00', 1,
                                        'MOSTRADOR', V_R1);
        SGCD_PKG_RESERVAS.crear_solicitud_web(V_CLI, 4, 1, V_MARTES, '12:00', 1, V_R2);
        SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '11:00', 1,
                                        'MOSTRADOR', V_R3);
        SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '13:00', 1,
                                        'MOSTRADOR', V_R4);
        SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '14:00', 1,
                                        'MOSTRADOR', V_R5);
        SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, V_MARTES, '15:00', 1,
                                        'MOSTRADOR', V_R6);

        COMPROBAR(SGCD_PKG_PAGOS.saldo_reserva(V_R1) = 18000,
                  'una reserva sin pagar debe el importe completo');

        SGCD_PKG_PAGOS.registrar_pago(V_R1, 'efectivo', V_ADMIN);
        SELECT p.ID_PAGO, p.IMPORTE_PAGO, p.MEDIO_PAGO, p.ESTADO_PAGO, p.FECHA_PAGO
        INTO   V_ID1, V_IMPORTE, V_MEDIO, V_ESTADO, V_FECHA
        FROM   SGCD_PAGOS p
        WHERE  p.ID_RESERVA = V_R1;
        COMPROBAR(V_ESTADO = 'PAGADO' AND V_IMPORTE = 18000 AND V_MEDIO = 'EFECTIVO',
                  'registrar_pago deja el pago vigente por el total y normaliza el medio');
        COMPROBAR(TO_CHAR(V_FECHA, 'YYYY-MM-DD') = TO_CHAR(SYSDATE, 'YYYY-MM-DD'),
                  'la fecha del pago es la del dia');
        COMPROBAR(SGCD_PKG_PAGOS.saldo_reserva(V_R1) = 0,
                  'con el pago registrado el saldo queda en cero');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R1 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20053, 'no se registra dos veces el mismo pago');

        C := SGCD_PKG_PAGOS.pago_de_reserva(V_R1);
        FETCH C INTO F_ID_PAGO, F_ID_RES, F_IMPORTE, F_FECHA, F_MEDIO, F_ESTADO,
                    F_ACORDADO, F_SALDO;
        COMPROBAR(F_ID_PAGO = V_ID1 AND F_ESTADO = 'PAGADO' AND F_ACORDADO = 18000
                  AND F_SALDO = 0,
                  'pago_de_reserva devuelve el pago con su saldo');
        CLOSE C;

        SGCD_PKG_PAGOS.anular_pago(V_R1, V_ADMIN);
        SELECT p.ESTADO_PAGO INTO V_ESTADO FROM SGCD_PAGOS p WHERE p.ID_RESERVA = V_R1;
        COMPROBAR(V_ESTADO = 'ANULADO' AND SGCD_PKG_PAGOS.saldo_reserva(V_R1) = 18000,
                  'anular deja la fila y vuelve a deber el importe');
        ESPERAR_ERROR('BEGIN SGCD_PKG_PAGOS.anular_pago(' || V_R1 || ', ' || V_ADMIN || '); END;',
                      -20055, 'no se anula dos veces');

        SGCD_PKG_PAGOS.registrar_pago(V_R1, 'DEBITO', V_ADMIN);
        SELECT p.ID_PAGO, p.ESTADO_PAGO, p.MEDIO_PAGO
        INTO   V_ID2, V_ESTADO, V_MEDIO
        FROM   SGCD_PAGOS p
        WHERE  p.ID_RESERVA = V_R1;
        COMPROBAR(V_ID2 = V_ID1 AND V_ESTADO = 'PAGADO' AND V_MEDIO = 'DEBITO',
                  'recobrar reutiliza la misma fila del pago anulado');

        SGCD_PKG_RESERVAS.cancelar_reserva(V_R1);
        SGCD_PKG_PAGOS.anular_pago(V_R1, V_ADMIN);
        SELECT p.ESTADO_PAGO INTO V_ESTADO FROM SGCD_PAGOS p WHERE p.ID_RESERVA = V_R1;
        COMPROBAR(V_ESTADO = 'ANULADO',
                  'anular un pago de una reserva cancelada es el reembolso');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R1 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20052, 'una reserva cancelada no se cobra');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R2 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20052, 'una solicitud web pendiente no se cobra');

        SGCD_PKG_RESERVAS.cancelar_reserva(V_R3);
        ESPERAR_ERROR('BEGIN SGCD_PKG_PAGOS.anular_pago(' || V_R3 || ', ' || V_ADMIN || '); END;',
                      -20054, 'anular exige un pago existente');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.cobrar_diferencia(' || V_R6 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20054, 'la diferencia exige un pago vigente');

        UPDATE SGCD_RESERVAS
        SET    INICIO_RESERVA = TRUNC(SYSDATE) - 2,
               TERMINO_RESERVA = TRUNC(SYSDATE) - 2 + 1 / 24
        WHERE  ID_RESERVA = V_R4;
        V_CANTIDAD := SGCD_PKG_RESERVAS.marcar_completadas();
        SELECT r.ESTADO_RESERVA INTO V_ESTADO FROM SGCD_RESERVAS r WHERE r.ID_RESERVA = V_R4;
        COMPROBAR(V_ESTADO = 'COMPLETADA' AND V_CANTIDAD >= 1,
                  'la reserva de prueba queda completada');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R4 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20052, 'una reserva completada no se cobra: el pago es por adelantado');

        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R5 || ', ''CHEQUE'', ' || V_ADMIN || '); END;',
            -20050, 'rechaza un medio de pago fuera del catalogo');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(999999, ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20051, 'rechaza una reserva inexistente');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(' || V_R5 || ', ''EFECTIVO'', ' || V_ADMIN_INAC || '); END;',
            -20057, 'rechaza un administrador inactivo');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.registrar_pago(NULL, ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20050, 'rechaza una reserva nula');

        SGCD_PKG_PAGOS.registrar_pago(V_R5, 'EFECTIVO', V_ADMIN);
        SGCD_PKG_RESERVAS.reprogramar_reserva(V_R5, V_MARTES, '18:00', 1);
        SGCD_PKG_PAGOS.cobrar_diferencia(V_R5, 'CREDITO', V_ADMIN);
        SELECT p.IMPORTE_PAGO, p.MEDIO_PAGO INTO V_IMPORTE, V_MEDIO
        FROM   SGCD_PAGOS p WHERE p.ID_RESERVA = V_R5;
        COMPROBAR(V_IMPORTE = 22000 AND V_MEDIO = 'CREDITO'
                  AND SGCD_PKG_PAGOS.saldo_reserva(V_R5) = 0,
                  'cobrar_diferencia sube el pago a la tarifa de noche');

        SGCD_PKG_RESERVAS.reprogramar_reserva(V_R5, V_MARTES, '19:00', 2);
        COMPROBAR(SGCD_PKG_PAGOS.saldo_reserva(V_R5) = 22000,
                  'tras reprogramar a dos bloques queda la diferencia por cobrar');
        SGCD_PKG_PAGOS.cobrar_diferencia(V_R5, 'TRANSFERENCIA', V_ADMIN);
        SELECT p.IMPORTE_PAGO INTO V_IMPORTE FROM SGCD_PAGOS p WHERE p.ID_RESERVA = V_R5;
        COMPROBAR(V_IMPORTE = 44000 AND SGCD_PKG_PAGOS.saldo_reserva(V_R5) = 0,
                  'cobrar_diferencia cubre el total de dos bloques');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_PAGOS.cobrar_diferencia(' || V_R5 || ', ''EFECTIVO'', ' || V_ADMIN || '); END;',
            -20056, 'no se cobra una diferencia cuando el saldo es cero');
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 9: SGCD_PKG_TORNEOS');

    DECLARE
        V_C1        NUMBER;
        V_C2        NUMBER;
        V_C3        NUMBER;
        V_CREADA    BOOLEAN;
        V_ADMIN     NUMBER;
        V_T1        NUMBER;
        V_T2        NUMBER;
        V_T3        NUMBER;
        V_I1        NUMBER;
        V_I2        NUMBER;
        V_I3        NUMBER;
        V_I4        NUMBER;
        V_MAX_MOD   NUMBER;
        V_MAX_TORN  NUMBER;
        V_ESTADO    VARCHAR2(15);
        V_CANTIDAD  NUMBER;
        V_CUENTA    NUMBER;
        V_RUT_J     NUMBER;
        V_CLIENTE_J NUMBER;
        V_ID_CLIENTE NUMBER;
        C           SYS_REFCURSOR;
        L1 NUMBER; L2 VARCHAR2(100); L3 NUMBER; L4 VARCHAR2(100);
        L5 DATE; L6 DATE; L7 NUMBER; L8 NUMBER; L9 NUMBER;
        L9B NUMBER; L10 VARCHAR2(15); L11 NUMBER;
        M1 NUMBER; M2 NUMBER; M3 VARCHAR2(100); M4 VARCHAR2(100);
        M5 NUMBER; M6 DATE; M7 VARCHAR2(15); M8 NUMBER; M9 VARCHAR2(100);
        J1 NUMBER; J2 VARCHAR2(20); J3 VARCHAR2(100); J4 NUMBER;
        V_ID_TORNEO NUMBER;
        V_ORIGEN    VARCHAR2(15);
        V_ESTADO_RES VARCHAR2(15);
        V_IMPORTE   NUMBER(12,2);
        V_MARTES    DATE := TRUNC(SYSDATE, 'IW') + 8;
    BEGIN
        SGCD_PKG_CLIENTES.crear_ficha(34000001, '3', 'Capitan Uno', NULL, NULL, V_C1, V_CREADA);
        SGCD_PKG_CLIENTES.crear_ficha(34000002, '1', 'Capitan Dos', NULL, NULL, V_C2, V_CREADA);
        SGCD_PKG_CLIENTES.crear_ficha(34000003, 'K', 'Capitan Tres', NULL, NULL, V_C3, V_CREADA);
        SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
        FROM   SGCD_ADMINISTRADORES a
        WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';

        SGCD_PKG_TORNEOS.crear_torneo(1, 'Copa Futbol', V_MARTES, V_MARTES + 7, 2,
                                      NULL, V_T1);
        SELECT t.ESTADO_TORNEO, t.MAX_JUGADORES_POR_EQUIPO
        INTO   V_ESTADO, V_MAX_TORN
        FROM   SGCD_TORNEOS t WHERE t.ID_TORNEO = V_T1;
        SELECT m.MAX_JUGADORES_POR_EQUIPO INTO V_MAX_MOD
        FROM   SGCD_MODALIDADES m WHERE m.ID_MODALIDAD = 1;
        COMPROBAR(V_ESTADO = 'PLANIFICADO' AND V_MAX_TORN = V_MAX_MOD,
                  'crear_torneo nace planificado y copia el maximo de la modalidad');

        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.crear_torneo(1, ''Mal Fechado'', TRUNC(SYSDATE) + 10, TRUNC(SYSDATE) + 5, 2, NULL, V); END;',
            -20060, 'rechaza un termino anterior al inicio');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.crear_torneo(1, ''Sin Cupos'', TRUNC(SYSDATE) + 5, TRUNC(SYSDATE) + 10, 0, NULL, V); END;',
            -20060, 'rechaza cero cupos');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.crear_torneo(99, ''Sin Modalidad'', TRUNC(SYSDATE) + 5, TRUNC(SYSDATE) + 10, 2, NULL, V); END;',
            -20060, 'rechaza una modalidad inexistente');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.crear_torneo(1, ''Pasado'', TRUNC(SYSDATE) - 5, TRUNC(SYSDATE) + 5, 2, NULL, V); END;',
            -20060, 'rechaza un torneo que empieza en el pasado');

        SGCD_PKG_TORNEOS.inscribir_equipo(V_T1, V_C1, 'Los Uno', V_I1);
        SELECT i.ESTADO_INSCRIPCION, i.CANTIDAD_JUGADORES INTO V_ESTADO, V_CANTIDAD
        FROM   SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_INSCRIPCION = V_I1;
        COMPROBAR(V_ESTADO = 'INSCRITO' AND V_CANTIDAD = 1,
                  'inscribir_equipo crea el equipo con el capitan como primer jugador');
        SELECT j.RUT_JUGADOR, j.ID_CLIENTE INTO V_RUT_J, V_CLIENTE_J
        FROM   SGCD_EQUIPOS_JUGADORES ej
        JOIN   SGCD_JUGADORES j ON j.ID_JUGADOR = ej.ID_JUGADOR
        WHERE  ej.ID_INSCRIPCION = V_I1;
        COMPROBAR(V_RUT_J = 34000001 AND V_CLIENTE_J = V_C1,
                  'el capitan queda vinculado a su ficha de cliente');

        SGCD_PKG_TORNEOS.agregar_jugador(V_I1, 35000001, '1', 'Jugador Uno');
        SGCD_PKG_TORNEOS.agregar_jugador(V_I1, 35000002, 'K', 'Jugador Dos');
        SELECT i.CANTIDAD_JUGADORES INTO V_CANTIDAD
        FROM   SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_INSCRIPCION = V_I1;
        COMPROBAR(V_CANTIDAD = 3, 'agregar_jugador recalcula la plantilla a tres');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(' || V_I1 || ', 35000001, ''1'', ''Repetido''); END;',
            -20065, 'rechaza un jugador repetido en el mismo equipo');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(' || V_I1 || ', 35000003, ''8'', ''  ''); END;',
            -20060, 'rechaza un jugador sin nombre');

        SGCD_PKG_TORNEOS.inscribir_equipo(V_T1, V_C2, 'Los Dos', V_I2);
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(' || V_I2 || ', 35000001, ''1'', ''Jugador Uno''); END;',
            -20066, 'rechaza un jugador ya inscrito en otro equipo del torneo');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(' || V_T1 || ', ' || V_C3 || ', ''Los Tres'', V); END;',
            -20063, 'rechaza la inscripcion cuando no quedan cupos');

        SGCD_PKG_TORNEOS.retirar_equipo(V_I1);
        SELECT i.ESTADO_INSCRIPCION INTO V_ESTADO
        FROM   SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_INSCRIPCION = V_I1;
        COMPROBAR(V_ESTADO = 'RETIRADO', 'retirar_equipo deja la inscripcion retirada');
        SGCD_PKG_TORNEOS.retirar_equipo(V_I1);
        OK('retirar dos veces no falla');
        SGCD_PKG_TORNEOS.inscribir_equipo(V_T1, V_C3, 'Los Tres', V_I3);
        SELECT i.ESTADO_INSCRIPCION INTO V_ESTADO
        FROM   SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_INSCRIPCION = V_I3;
        COMPROBAR(V_ESTADO = 'INSCRITO', 'el retiro libera el cupo para otro equipo');
        SGCD_PKG_TORNEOS.agregar_jugador(V_I3, 35000001, '1', 'Jugador Uno');
        SELECT i.CANTIDAD_JUGADORES INTO V_CANTIDAD
        FROM   SGCD_INSCRIPCIONES_TORNEO i WHERE i.ID_INSCRIPCION = V_I3;
        COMPROBAR(V_CANTIDAD = 2,
                  'el retiro libera los RUT del equipo retirado en ese torneo');

        SGCD_PKG_TORNEOS.crear_torneo(2, 'Copa Padel', V_MARTES, V_MARTES + 3, 1, NULL, V_T2);
        SGCD_PKG_TORNEOS.inscribir_equipo(V_T2, V_C1, 'Padel Uno', V_I4);
        SELECT t.MAX_JUGADORES_POR_EQUIPO INTO V_MAX_TORN
        FROM   SGCD_TORNEOS t WHERE t.ID_TORNEO = V_T2;
        COMPROBAR(V_MAX_TORN = 2, 'padel copia su maximo de dos jugadores');
        SGCD_PKG_TORNEOS.agregar_jugador(V_I4, 35000002, 'K', 'Jugador Dos');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(' || V_I4 || ', 35000003, ''8'', ''Jugador Tres''); END;',
            -20064, 'rechaza un jugador que supera el maximo del torneo');
        UPDATE SGCD_TORNEOS SET ESTADO_TORNEO = 'EN_CURSO' WHERE ID_TORNEO = V_T2;
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(' || V_I4 || ', 35000003, ''8'', ''Jugador Tres''); END;',
            -20062, 'un torneo en curso no admite cambios de plantilla');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(' || V_T2 || ', ' || V_C3 || ', ''Padel Dos'', V); END;',
            -20062, 'un torneo en curso no admite inscripciones');

        SGCD_PKG_TORNEOS.crear_torneo(1, 'Copa Maximo', V_MARTES, V_MARTES + 5, 3, 2, V_T3);
        SGCD_PKG_TORNEOS.inscribir_equipo(V_T3, V_C2, 'Maximo Uno', V_I1);
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(' || V_T3 || ', ' || V_C3 || ', ''Maximo Uno'', V); END;',
            -20069, 'rechaza un nombre de equipo repetido en el torneo');
        SGCD_PKG_TORNEOS.agregar_jugador(V_I1, 35000003, '8', 'Jugador Tres');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.ajustar_maximo(' || V_T3 || ', 1); END;',
            -20064, 'no baja el maximo por debajo de la plantilla activa');
        SGCD_PKG_TORNEOS.ajustar_maximo(V_T3, 3);
        SELECT t.MAX_JUGADORES_POR_EQUIPO INTO V_MAX_TORN
        FROM   SGCD_TORNEOS t WHERE t.ID_TORNEO = V_T3;
        COMPROBAR(V_MAX_TORN = 3, 'ajustar_maximo sube el tope del torneo');

        SGCD_PKG_TORNEOS.programar_torneo(V_T1, 5, V_MARTES, '10:00', '12:00');
        SELECT COUNT(*), MIN(r.ID_CLIENTE), MIN(r.ID_TORNEO), MIN(r.ORIGEN_RESERVA),
               MIN(r.ESTADO_RESERVA), SUM(r.IMPORTE_ACORDADO)
        INTO   V_CUENTA, V_ID_CLIENTE, V_ID_TORNEO, V_ORIGEN, V_ESTADO_RES, V_IMPORTE
        FROM   SGCD_RESERVAS r
        WHERE  r.ID_TORNEO = V_T1;
        COMPROBAR(V_CUENTA = 2 AND V_ID_CLIENTE IS NULL AND V_ID_TORNEO = V_T1
                  AND V_ORIGEN = 'TORNEO' AND V_ESTADO_RES = 'CONFIRMADA'
                  AND V_IMPORTE = 36000,
                  'programar_torneo crea un bloque por hora, sin cliente y con tarifa');
        COMPROBAR(SGCD_PKG_RESERVAS.disponible(5, 1, V_MARTES, '10:00', 1) = 0,
                  'el bloque del torneo ocupa el calendario');
        ESPERAR_ERROR(
            'DECLARE V NUMBER; BEGIN SGCD_PKG_RESERVAS.crear_reserva(' || V_C1 || ', ' || V_ADMIN
            || ', 5, 1, TRUNC(SYSDATE, ''IW'') + 8, ''10:00'', 1, ''MOSTRADOR'', V); END;',
            -20043, 'el bloque del torneo le gana el horario al mostrador');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(' || V_T1 || ', 5, TRUNC(SYSDATE, ''IW'') + 8, ''11:00'', ''13:00''); END;',
            -20043, 'no programa encima de un bloque ya tomado');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(' || V_T1 || ', 5, TRUNC(SYSDATE, ''IW'') + 8, ''09:00'', ''11:00''); END;',
            -20043, 'no programa si un bloque intermedio choca');
        SELECT COUNT(*) INTO V_CUENTA
        FROM   SGCD_RESERVAS r
        WHERE  r.ID_TORNEO = V_T1 AND r.ID_CANCHA = 5
          AND  r.INICIO_RESERVA = TRUNC(SYSDATE, 'IW') + 8 + 9 / 24;
        COMPROBAR(V_CUENTA = 0,
                  'un fallo a mitad de rango no deja el bloque anterior programado');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(' || V_T1 || ', 5, TRUNC(SYSDATE, ''IW'') + 8, ''10:30'', ''12:30''); END;',
            -20070, 'rechaza un rango que no calza con bloques de una hora');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(' || V_T1 || ', 5, TRUNC(SYSDATE, ''IW'') + 7, ''10:00'', ''11:00''); END;',
            -20042, 'el lunes el recinto no abre, tampoco para torneos');
        ESPERAR_ERROR(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(' || V_T1 || ', 5, TRUNC(SYSDATE, ''IW'') + 8, ''21:00'', ''23:00''); END;',
            -20042, 'un torneo tampoco se sale del cierre');

        SGCD_PKG_TORNEOS.programar_torneo(V_T2, 8, V_MARTES, '13:00', '14:00');
        SELECT COUNT(*) INTO V_CUENTA FROM SGCD_RESERVAS r WHERE r.ID_TORNEO = V_T2;
        COMPROBAR(V_CUENTA = 1, 'un torneo en curso si admite programacion');

        V_CUENTA := 0;
        SGCD_PKG_TORNEOS.listar_torneos(1, 'PLANIFICADO', NULL, C);
        LOOP
            FETCH C INTO L1, L2, L3, L4, L5, L6, L7, L8, L9, L9B, L10, L11;
            EXIT WHEN C%NOTFOUND;
            V_CUENTA := V_CUENTA + 1;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CUENTA >= 2, 'listar_torneos filtra por modalidad y estado');

        V_CUENTA := 0;
        SGCD_PKG_TORNEOS.listar_inscripciones(V_T1, NULL, C);
        LOOP
            FETCH C INTO M1, M2, M3, M4, M5, M6, M7, M8, M9;
            EXIT WHEN C%NOTFOUND;
            V_CUENTA := V_CUENTA + 1;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CUENTA = 3, 'listar_inscripciones trae tambien la retirada del torneo');

        V_CUENTA := 0;
        SGCD_PKG_TORNEOS.jugadores_inscripcion(V_I3, C);
        LOOP
            FETCH C INTO J1, J2, J3, J4;
            EXIT WHEN C%NOTFOUND;
            V_CUENTA := V_CUENTA + 1;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_CUENTA = 2, 'jugadores_inscripcion trae la plantilla real');
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
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 10: SGCD_PKG_CONSULTAS');

    DECLARE
        V_A         NUMBER;
        V_B         NUMBER;
        V_CREADA    BOOLEAN;
        V_ADMIN     NUMBER;
        V_TORNEO    NUMBER;
        V_R1        NUMBER;
        V_R2        NUMBER;
        V_R3        NUMBER;
        V_R4        NUMBER;
        V_MARTES    DATE := TRUNC(SYSDATE, 'IW') + 15;
        V_FILAS     NUMBER;
        V_RESERVAS  NUMBER;
        V_HORAS     NUMBER;
        V_IMPORTE   NUMBER;
        V_DIA       DATE;
        V_PAGOS     NUMBER;
        V_TOTAL     NUMBER;
        V_PAGOS_PREV NUMBER;
        V_TOTAL_PREV NUMBER;
        V_CANCHA    VARCHAR2(100);
        V_MODALIDAD VARCHAR2(100);
        V_CLIENTE   VARCHAR2(100);
        V_RUT       VARCHAR2(20);
        V_ID        NUMBER;
        V_SUMA_RES  NUMBER;
        V_SUMA_HOR  NUMBER;
        V_SUMA_IMP  NUMBER;
        C           SYS_REFCURSOR;
    BEGIN
        SGCD_PKG_CLIENTES.crear_ficha(36000001, 'K', 'Cliente Reporte A', NULL, NULL,
                                      V_A, V_CREADA);
        SGCD_PKG_CLIENTES.crear_ficha(36000002, '8', 'Cliente Reporte B', NULL, NULL,
                                      V_B, V_CREADA);
        SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
        FROM   SGCD_ADMINISTRADORES a
        WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';

        -- Los pagos del dia pueden existir antes de la prueba (datos de la
        -- demo). Se guarda la linea base y se comprueba el delta.
        SELECT COUNT(*), NVL(SUM(p.IMPORTE_PAGO), 0)
        INTO   V_PAGOS_PREV, V_TOTAL_PREV
        FROM   SGCD_PAGOS p
        WHERE  p.ESTADO_PAGO = 'PAGADO'
          AND  p.FECHA_PAGO >= TRUNC(SYSDATE) AND p.FECHA_PAGO < TRUNC(SYSDATE) + 1;

        SGCD_PKG_RESERVAS.crear_reserva(V_A, V_ADMIN, 4, 1, V_MARTES, '10:00', 1,
                                        'MOSTRADOR', V_R1);
        SGCD_PKG_RESERVAS.crear_reserva(V_A, V_ADMIN, 5, 1, V_MARTES, '18:00', 1,
                                        'MOSTRADOR', V_R2);
        SGCD_PKG_RESERVAS.crear_reserva(V_A, V_ADMIN, 4, 1, V_MARTES, '12:00', 1,
                                        'MOSTRADOR', V_R3);
        SGCD_PKG_RESERVAS.cancelar_reserva(V_R3);
        SGCD_PKG_RESERVAS.crear_reserva(V_B, V_ADMIN, 8, 2, V_MARTES, '13:00', 1,
                                        'MOSTRADOR', V_R4);
        SGCD_PKG_TORNEOS.crear_torneo(1, 'Copa Reporte', V_MARTES, V_MARTES + 3, 4,
                                      NULL, V_TORNEO);
        SGCD_PKG_TORNEOS.programar_torneo(V_TORNEO, 6, V_MARTES, '15:00', '16:00');

        SGCD_PKG_PAGOS.registrar_pago(V_R1, 'EFECTIVO', V_ADMIN);
        SGCD_PKG_PAGOS.registrar_pago(V_R4, 'DEBITO', V_ADMIN);

        C := NULL;
        SGCD_PKG_CONSULTAS.ingresos(TRUNC(SYSDATE), TRUNC(SYSDATE), C);
        FETCH C INTO V_DIA, V_PAGOS, V_TOTAL;
        COMPROBAR(V_PAGOS = V_PAGOS_PREV + 2 AND V_TOTAL = V_TOTAL_PREV + 34000
                  AND TRUNC(V_DIA) = TRUNC(SYSDATE),
                  'ingresos suma solo los pagos vigentes del dia');
        FETCH C INTO V_DIA, V_PAGOS, V_TOTAL;
        COMPROBAR(C%NOTFOUND, 'ingresos devuelve una fila por dia con movimiento');
        CLOSE C;

        SGCD_PKG_CONSULTAS.ingresos(TRUNC(SYSDATE) - 10, TRUNC(SYSDATE) - 10, C);
        FETCH C INTO V_DIA, V_PAGOS, V_TOTAL;
        COMPROBAR(C%NOTFOUND, 'ingresos sin movimientos devuelve el cursor vacio');
        CLOSE C;

        ESPERAR_ERROR(
            'DECLARE C SYS_REFCURSOR; BEGIN SGCD_PKG_CONSULTAS.ingresos(TRUNC(SYSDATE) + 5, TRUNC(SYSDATE) + 1, C); END;',
            -20080, 'rechaza un rango invertido');
        ESPERAR_ERROR(
            'DECLARE C SYS_REFCURSOR; BEGIN SGCD_PKG_CONSULTAS.ingresos(NULL, TRUNC(SYSDATE), C); END;',
            -20080, 'rechaza un rango sin fecha desde');
        ESPERAR_ERROR(
            'DECLARE C SYS_REFCURSOR; BEGIN SGCD_PKG_CONSULTAS.ingresos(TRUNC(SYSDATE), TRUNC(SYSDATE) + 400, C); END;',
            -20080, 'rechaza un rango de mas de 366 dias');

        V_FILAS := 0;
        V_SUMA_RES := 0;
        V_SUMA_HOR := 0;
        V_SUMA_IMP := 0;
        SGCD_PKG_CONSULTAS.reservas_por_cancha(V_MARTES, V_MARTES, NULL, C);
        LOOP
            FETCH C INTO V_CANCHA, V_MODALIDAD, V_RESERVAS, V_HORAS, V_IMPORTE;
            EXIT WHEN C%NOTFOUND;
            V_FILAS := V_FILAS + 1;
            V_SUMA_RES := V_SUMA_RES + V_RESERVAS;
            V_SUMA_HOR := V_SUMA_HOR + V_HORAS;
            V_SUMA_IMP := V_SUMA_IMP + V_IMPORTE;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_FILAS = 4 AND V_SUMA_RES = 4 AND V_SUMA_IMP = 74000,
                  'reservas por cancha cuenta las cuatro reservas vigentes y la del torneo');
        COMPROBAR(V_SUMA_HOR = 4, 'las horas suman un bloque por reserva');

        V_FILAS := 0;
        V_SUMA_RES := 0;
        V_SUMA_IMP := 0;
        SGCD_PKG_CONSULTAS.reservas_por_cancha(V_MARTES, V_MARTES, V_A, C);
        LOOP
            FETCH C INTO V_CANCHA, V_MODALIDAD, V_RESERVAS, V_HORAS, V_IMPORTE;
            EXIT WHEN C%NOTFOUND;
            V_FILAS := V_FILAS + 1;
            V_SUMA_RES := V_SUMA_RES + V_RESERVAS;
            V_SUMA_IMP := V_SUMA_IMP + V_IMPORTE;
        END LOOP;
        CLOSE C;
        COMPROBAR(V_FILAS = 2 AND V_SUMA_RES = 2 AND V_SUMA_IMP = 40000,
                  'el filtro de propiedad deja solo las reservas del cliente y excluye la cancelada');

        SGCD_PKG_CONSULTAS.clientes_por_reservas(V_MARTES, V_MARTES, NULL, C);
        FETCH C INTO V_ID, V_CLIENTE, V_RUT, V_RESERVAS, V_HORAS, V_IMPORTE;
        COMPROBAR(V_ID = V_A AND V_RESERVAS = 2 AND V_IMPORTE = 40000,
                  'clientes por reservas ordena primero al cliente con mas reservas');
        COMPROBAR(V_RUT = '36000001-K', 'el reporte muestra el RUT completo con digito');
        FETCH C INTO V_ID, V_CLIENTE, V_RUT, V_RESERVAS, V_HORAS, V_IMPORTE;
        COMPROBAR(V_ID = V_B AND V_RESERVAS = 1 AND V_IMPORTE = 16000,
                  'el segundo cliente trae su propia cuenta');
        FETCH C INTO V_ID, V_CLIENTE, V_RUT, V_RESERVAS, V_HORAS, V_IMPORTE;
        COMPROBAR(C%NOTFOUND,
                  'el bloque de torneo no entra en el reporte de clientes');
        CLOSE C;

        SGCD_PKG_CONSULTAS.clientes_por_reservas(V_MARTES, V_MARTES, V_B, C);
        FETCH C INTO V_ID, V_CLIENTE, V_RUT, V_RESERVAS, V_HORAS, V_IMPORTE;
        COMPROBAR(V_ID = V_B AND V_RESERVAS = 1,
                  'el filtro de propiedad funciona en el ranking de clientes');
        FETCH C INTO V_ID, V_CLIENTE, V_RUT, V_RESERVAS, V_HORAS, V_IMPORTE;
        COMPROBAR(C%NOTFOUND, 'el filtro devuelve una sola fila');
        CLOSE C;
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


-- =====================================================================
-- UNIDAD 11: mantenedor de recintos (etiqueta de interfaz: Sucursales)
-- =====================================================================
DECLARE
    V_FALLAS NUMBER := 0;
    V_ID NUMBER;
    V_CANTIDAD NUMBER;
    V_ENCONTRADA BOOLEAN := FALSE;
    V_NOMBRE SGCD_RECINTOS.NOMBRE_RECINTO%TYPE;
    V_DIRECCION SGCD_RECINTOS.DIRECCION_RECINTO%TYPE;
    V_ESTADO SGCD_RECINTOS.ESTADO_RECINTO%TYPE;
    L_ID SGCD_RECINTOS.ID_RECINTO%TYPE;
    L_NOMBRE SGCD_RECINTOS.NOMBRE_RECINTO%TYPE;
    L_DIRECCION SGCD_RECINTOS.DIRECCION_RECINTO%TYPE;
    L_ESTADO SGCD_RECINTOS.ESTADO_RECINTO%TYPE;
    C SYS_REFCURSOR;

    PROCEDURE COMPROBAR(P_CONDICION BOOLEAN, P_TEXTO VARCHAR2) IS
    BEGIN
        IF P_CONDICION THEN
            DBMS_OUTPUT.PUT_LINE('OK    ' || P_TEXTO);
        ELSE
            V_FALLAS := V_FALLAS + 1;
            DBMS_OUTPUT.PUT_LINE('FALLA ' || P_TEXTO);
        END IF;
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('--- UNIDAD 11: mantenedor de recintos');

    SGCD_CREAR_RECINTO('Sucursal Prueba Mantenedor', 'Direccion de prueba', 'ACTIVO', V_ID);
    SGCD_LISTAR_RECINTOS(C);
    LOOP
        FETCH C INTO L_ID, L_NOMBRE, L_DIRECCION, L_ESTADO;
        EXIT WHEN C%NOTFOUND;
        IF L_ID = V_ID AND L_NOMBRE = 'Sucursal Prueba Mantenedor'
           AND L_DIRECCION = 'Direccion de prueba' AND L_ESTADO = 'ACTIVO' THEN
            V_ENCONTRADA := TRUE;
        END IF;
    END LOOP;
    CLOSE C;
    COMPROBAR(V_ENCONTRADA, 'listar recintos devuelve la sucursal creada');

    SGCD_ACTUALIZAR_RECINTO(V_ID, 'Sucursal Prueba Editada', 'Nueva direccion de prueba', 'INACTIVO');
    SELECT NOMBRE_RECINTO, DIRECCION_RECINTO, ESTADO_RECINTO
    INTO V_NOMBRE, V_DIRECCION, V_ESTADO
    FROM SGCD_RECINTOS WHERE ID_RECINTO = V_ID;
    COMPROBAR(V_NOMBRE = 'Sucursal Prueba Editada' AND V_DIRECCION = 'Nueva direccion de prueba'
              AND V_ESTADO = 'INACTIVO', 'actualizar recinto cambia nombre, direccion y estado');

    SGCD_BORRAR_RECINTO(V_ID);
    SELECT COUNT(*) INTO V_CANTIDAD FROM SGCD_RECINTOS WHERE ID_RECINTO = V_ID;
    COMPROBAR(V_CANTIDAD = 0, 'borrar recinto elimina la sucursal sin dependencias');

    ROLLBACK;
    DBMS_OUTPUT.PUT_LINE('---');
    IF V_FALLAS = 0 THEN
        DBMS_OUTPUT.PUT_LINE('RESULTADO: todas las comprobaciones pasaron');
    ELSE
        DBMS_OUTPUT.PUT_LINE('RESULTADO: ' || V_FALLAS || ' fallas');
    END IF;
END;
/
