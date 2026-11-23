-- =====================================================================
-- SISTEMA DE GESTION DE CENTROS DEPORTIVOS - SGCD
-- CAPA DE SERVICIOS - 6 paquetes PL/SQL sobre el esquema v3
--
-- Requiere: 04_ddl_v3.sql ya ejecutado en el mismo esquema.
-- Orden de compilacion (por dependencias, ya respetado en este archivo):
--   1 SGCD_PKG_CLIENTES  (sin dependencias)
--   2 SGCD_PKG_AUTH      (usa CLIENTES)
--   3 SGCD_PKG_TARIFAS   (sin dependencias)
--   4 SGCD_PKG_RESERVAS  (usa AUTH y TARIFAS)
--   5 SGCD_PKG_TORNEOS   (usa RESERVAS y CLIENTES)
--   6 SGCD_PKG_CONSULTAS (usa AUTH)
--
-- Toda regla de negocio vive aqui. La web solo presenta y llama.
--
-- Codigos de error propios (RAISE_APPLICATION_ERROR):
--   -20001 RUT invalido
--   -20002 cliente no encontrado
--   -20003 credencial inexistente, bloqueada o inactiva
--   -20004 cancha no disponible (mantencion o inactiva)
--   -20005 fuera del horario del recinto
--   -20006 sin tarifa vigente para ese bloque
--   -20007 la cancha ya esta ocupada en ese horario
--   -20008 reserva no encontrada
--   -20009 cambio de estado no permitido
--   -20010 sin permiso sobre la reserva
--   -20012 el torneo no esta en PLANIFICADO
--   -20013 cupos del torneo agotados
--   -20014 jugador ya inscrito en otro equipo del mismo torneo
--   -20015 equipo no encontrado o retirado
--   -20016 descuento fuera de rango (0-100)
--   -20017 correo ya registrado
--   -20018 login ya registrado
--   -20019 rango de tiempo invalido
--   -20020 falta quien crea la reserva (administrador o credencial)
--   -20021 falta el cliente de la reserva
--   -20022 el jugador ya esta en este equipo
--   -20023 la cuenta ya estaba verificada
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


-- =====================================================================
-- 1. SGCD_PKG_CLIENTES - ficha del cliente, RUT y busqueda
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_CLIENTES AS
    FUNCTION normalizar_dv(p_dv VARCHAR2) RETURN CHAR;
    FUNCTION dv_calculado(p_rut NUMBER) RETURN CHAR;
    FUNCTION rut_valido(p_rut NUMBER, p_dv VARCHAR2) RETURN BOOLEAN;
    FUNCTION obtener_por_rut(p_rut NUMBER, p_dv VARCHAR2) RETURN NUMBER;
    PROCEDURE crear_ficha(
        p_rut       NUMBER,
        p_dv        VARCHAR2,
        p_nombre    VARCHAR2,
        p_telefono  VARCHAR2 DEFAULT NULL,
        p_correo    VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER,
        p_creada     OUT BOOLEAN);
    PROCEDURE buscar_ficha(p_texto VARCHAR2, p_cursor OUT SYS_REFCURSOR);
END SGCD_PKG_CLIENTES;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_CLIENTES AS
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
        IF p_rut IS NULL OR p_rut < 1 OR p_rut > 99999999 THEN
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
    PROCEDURE crear_ficha(
        p_rut NUMBER, p_dv VARCHAR2, p_nombre VARCHAR2,
        p_telefono VARCHAR2 DEFAULT NULL, p_correo VARCHAR2 DEFAULT NULL,
        p_id_cliente OUT NUMBER, p_creada OUT BOOLEAN) IS
        v_dv     CHAR(1) := normalizar_dv(p_dv);
        v_existe NUMBER;
    BEGIN
        IF p_nombre IS NULL OR TRIM(p_nombre) IS NULL THEN
            RAISE_APPLICATION_ERROR(-20002, 'El nombre del cliente es obligatorio');
        END IF;
        IF NOT rut_valido(p_rut, v_dv) THEN
            RAISE_APPLICATION_ERROR(-20001, 'RUT invalido: ' || p_rut || '-' || v_dv);
        END IF;
        v_existe := obtener_por_rut(p_rut, v_dv);
        IF v_existe IS NOT NULL THEN
            p_id_cliente := v_existe;
            p_creada     := FALSE;
            RETURN;
        END IF;
        INSERT INTO SGCD_CLIENTES (RUT_CLIENTE, DV_CLIENTE, NOMBRE_CLIENTE, TELEFONO_CLIENTE, CORREO_CLIENTE)
        VALUES (p_rut, v_dv, TRIM(p_nombre), p_telefono, LOWER(TRIM(p_correo)))
        RETURNING ID_CLIENTE INTO p_id_cliente;
        p_creada := TRUE;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20017, 'El correo ya esta registrado en otra ficha');
    END crear_ficha;
    PROCEDURE buscar_ficha(p_texto VARCHAR2, p_cursor OUT SYS_REFCURSOR) IS
    BEGIN
        OPEN p_cursor FOR
            SELECT c.ID_CLIENTE, c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE,
                   c.TELEFONO_CLIENTE, c.CORREO_CLIENTE, c.ESTADO_CLIENTE
            FROM   SGCD_CLIENTES c
            WHERE  UPPER(c.NOMBRE_CLIENTE) LIKE '%' || UPPER(TRIM(p_texto)) || '%'
               OR  c.TELEFONO_CLIENTE LIKE '%' || TRIM(p_texto) || '%'
               OR  LOWER(c.CORREO_CLIENTE) LIKE '%' || LOWER(TRIM(p_texto)) || '%'
               OR  (TO_CHAR(c.RUT_CLIENTE) || c.DV_CLIENTE) LIKE '%' || UPPER(TRIM(p_texto)) || '%'
            ORDER BY c.NOMBRE_CLIENTE;
    END buscar_ficha;
END SGCD_PKG_CLIENTES;
/


-- =====================================================================
-- 2. SGCD_PKG_AUTH - credenciales y verificacion de cuentas
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_AUTH AS
    PROCEDURE crear_credencial(
        p_login          VARCHAR2,
        p_hash           VARCHAR2,
        p_rol            VARCHAR2,
        p_id_cliente     NUMBER   DEFAULT NULL,
        p_id_admin       NUMBER   DEFAULT NULL,
        p_id_credencial  OUT NUMBER);
    PROCEDURE verificar_cuenta(p_id_credencial NUMBER, p_id_admin_verificador NUMBER);
    FUNCTION cliente_de_credencial(p_id_credencial NUMBER) RETURN NUMBER;
    FUNCTION esta_verificada(p_id_credencial NUMBER) RETURN BOOLEAN;
    PROCEDURE obtener_credencial(
        p_login          VARCHAR2,
        p_id_credencial  OUT NUMBER,
        p_hash           OUT VARCHAR2,
        p_rol            OUT VARCHAR2,
        p_id_cliente     OUT NUMBER,
        p_verificada     OUT BOOLEAN);
END SGCD_PKG_AUTH;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_AUTH AS
    PROCEDURE crear_credencial(
        p_login VARCHAR2, p_hash VARCHAR2, p_rol VARCHAR2,
        p_id_cliente NUMBER DEFAULT NULL, p_id_admin NUMBER DEFAULT NULL,
        p_id_credencial OUT NUMBER) IS
        v_rol VARCHAR2(20) := UPPER(TRIM(p_rol));
    BEGIN
        IF v_rol NOT IN ('ADMINISTRADOR', 'OPERADOR', 'CLIENTE') THEN
            RAISE_APPLICATION_ERROR(-20024, 'Rol invalido: ' || p_rol);
        END IF;
        IF v_rol = 'CLIENTE' AND p_id_cliente IS NULL THEN
            RAISE_APPLICATION_ERROR(-20024, 'Una credencial CLIENTE necesita ID_CLIENTE');
        END IF;
        IF v_rol <> 'CLIENTE' AND p_id_admin IS NULL THEN
            RAISE_APPLICATION_ERROR(-20024, 'El personal necesita ID_ADMINISTRADOR');
        END IF;
        INSERT INTO SGCD_CREDENCIALES (
            LOGIN_CREDENCIAL, CLAVE_HASH_CREDENCIAL, ROL_CREDENCIAL, ESTADO_CREDENCIAL,
            ID_CLIENTE, ID_ADMINISTRADOR, FECHA_VERIFICACION_CREDENCIAL, ID_ADMINISTRADOR_VERIFICADOR)
        VALUES (
            UPPER(TRIM(p_login)), p_hash, v_rol, 'ACTIVA',
            p_id_cliente, p_id_admin,
            CASE WHEN v_rol = 'CLIENTE' THEN NULL ELSE SYSTIMESTAMP END,
            CASE WHEN v_rol = 'CLIENTE' THEN NULL ELSE p_id_admin END)
        RETURNING ID_CREDENCIAL INTO p_id_credencial;
    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            RAISE_APPLICATION_ERROR(-20018, 'El login ya esta registrado');
    END crear_credencial;
    PROCEDURE verificar_cuenta(p_id_credencial NUMBER, p_id_admin_verificador NUMBER) IS
    BEGIN
        UPDATE SGCD_CREDENCIALES
        SET    FECHA_VERIFICACION_CREDENCIAL = SYSTIMESTAMP,
               ID_ADMINISTRADOR_VERIFICADOR  = p_id_admin_verificador
        WHERE  ID_CREDENCIAL = p_id_credencial
        AND    ROL_CREDENCIAL = 'CLIENTE'
        AND    FECHA_VERIFICACION_CREDENCIAL IS NULL;
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20023, 'La cuenta no existe, no es de cliente o ya estaba verificada');
        END IF;
    END verificar_cuenta;
    FUNCTION cliente_de_credencial(p_id_credencial NUMBER) RETURN NUMBER IS
        v_cliente NUMBER;
        v_estado  VARCHAR2(10);
    BEGIN
        SELECT c.ID_CLIENTE, c.ESTADO_CREDENCIAL INTO v_cliente, v_estado
        FROM   SGCD_CREDENCIALES c
        WHERE  c.ID_CREDENCIAL = p_id_credencial;
        IF v_estado <> 'ACTIVA' THEN
            RAISE_APPLICATION_ERROR(-20003, 'La credencial no esta activa');
        END IF;
        RETURN v_cliente;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'La credencial no existe');
    END cliente_de_credencial;
    FUNCTION esta_verificada(p_id_credencial NUMBER) RETURN BOOLEAN IS
        v_fecha SGCD_CREDENCIALES.FECHA_VERIFICACION_CREDENCIAL%TYPE;
    BEGIN
        SELECT c.FECHA_VERIFICACION_CREDENCIAL INTO v_fecha
        FROM   SGCD_CREDENCIALES c
        WHERE  c.ID_CREDENCIAL = p_id_credencial;
        RETURN v_fecha IS NOT NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'La credencial no existe');
    END esta_verificada;
    PROCEDURE obtener_credencial(
        p_login VARCHAR2, p_id_credencial OUT NUMBER, p_hash OUT VARCHAR2,
        p_rol OUT VARCHAR2, p_id_cliente OUT NUMBER, p_verificada OUT BOOLEAN) IS
        v_fecha SGCD_CREDENCIALES.FECHA_VERIFICACION_CREDENCIAL%TYPE;
        v_estado SGCD_CREDENCIALES.ESTADO_CREDENCIAL%TYPE;
    BEGIN
        SELECT c.ID_CREDENCIAL, c.CLAVE_HASH_CREDENCIAL, c.ROL_CREDENCIAL,
               c.ID_CLIENTE, c.FECHA_VERIFICACION_CREDENCIAL, c.ESTADO_CREDENCIAL
        INTO   p_id_credencial, p_hash, p_rol, p_id_cliente, v_fecha, v_estado
        FROM   SGCD_CREDENCIALES c
        WHERE  c.LOGIN_CREDENCIAL = UPPER(TRIM(p_login));
        IF v_estado <> 'ACTIVA' THEN
            RAISE_APPLICATION_ERROR(-20003, 'La credencial no esta activa');
        END IF;
        p_verificada := v_fecha IS NOT NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20003, 'Login o clave incorrectos');
    END obtener_credencial;
END SGCD_PKG_AUTH;
/


-- =====================================================================
-- 3. SGCD_PKG_TARIFAS - precio por hora de un bloque
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_TARIFAS AS
    FUNCTION tarifa_vigente(p_id_cancha NUMBER, p_id_modalidad NUMBER, p_fecha TIMESTAMP) RETURN NUMBER;
    PROCEDURE obtener_tarifa(
        p_id_cancha     NUMBER,
        p_id_modalidad  NUMBER,
        p_fecha         TIMESTAMP,
        p_id_tarifa     OUT NUMBER,
        p_valor_hora    OUT NUMBER);
END SGCD_PKG_TARIFAS;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_TARIFAS AS
    PROCEDURE obtener_tarifa(
        p_id_cancha NUMBER, p_id_modalidad NUMBER, p_fecha TIMESTAMP,
        p_id_tarifa OUT NUMBER, p_valor_hora OUT NUMBER) IS
        v_dia   NUMBER(1);
        v_hora  CHAR(5);
        v_dia_d DATE := CAST(p_fecha AS DATE);
    BEGIN
        v_dia  := TRUNC(v_dia_d) - TRUNC(v_dia_d, 'IW') + 1;
        v_hora := TO_CHAR(p_fecha, 'HH24:MI');
        SELECT t.ID_TARIFA, t.VALOR_HORA_TARIFA INTO p_id_tarifa, p_valor_hora
        FROM   SGCD_TARIFAS t
        WHERE  t.ID_CANCHA = p_id_cancha
        AND    t.ID_MODALIDAD = p_id_modalidad
        AND    t.DIA_SEMANA_TARIFA = v_dia
        AND    t.ESTADO_TARIFA = 'ACTIVA'
        AND    t.HORA_DESDE_TARIFA <= v_hora
        AND    t.HORA_HASTA_TARIFA > v_hora
        AND    t.VIGENTE_DESDE_TARIFA <= v_dia_d
        AND    (t.VIGENTE_HASTA_TARIFA IS NULL OR t.VIGENTE_HASTA_TARIFA >= v_dia_d)
        ORDER BY t.VIGENTE_DESDE_TARIFA DESC
        FETCH FIRST 1 ROWS ONLY;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Sin tarifa vigente para cancha ' || p_id_cancha || ', modalidad ' || p_id_modalidad ||
                ', dia ' || v_dia || ' a las ' || v_hora);
    END obtener_tarifa;
    FUNCTION tarifa_vigente(p_id_cancha NUMBER, p_id_modalidad NUMBER, p_fecha TIMESTAMP) RETURN NUMBER IS
        v_id    NUMBER;
        v_valor NUMBER;
    BEGIN
        obtener_tarifa(p_id_cancha, p_id_modalidad, p_fecha, v_id, v_valor);
        RETURN v_valor;
    END tarifa_vigente;
END SGCD_PKG_TARIFAS;
/


-- =====================================================================
-- 4. SGCD_PKG_RESERVAS - el corazon: solape, tarifa y estados
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_RESERVAS AS
    FUNCTION esta_libre(p_id_cancha NUMBER, p_inicio TIMESTAMP, p_fin TIMESTAMP) RETURN BOOLEAN;
    PROCEDURE crear_reserva(
        p_id_cancha            NUMBER,
        p_id_modalidad         NUMBER,
        p_inicio               TIMESTAMP,
        p_fin                  TIMESTAMP,
        p_id_cliente           NUMBER   DEFAULT NULL,
        p_id_credencial        NUMBER   DEFAULT NULL,
        p_id_administrador     NUMBER   DEFAULT NULL,
        p_tipo_reserva         VARCHAR2 DEFAULT 'NORMAL',
        p_id_torneo            NUMBER   DEFAULT NULL,
        p_descuento_porcentaje NUMBER   DEFAULT 0,
        p_id_reserva           OUT NUMBER);
    PROCEDURE confirmar_reserva(p_id_reserva NUMBER, p_id_administrador NUMBER);
    PROCEDURE cancelar_reserva(
        p_id_reserva     NUMBER,
        p_id_credencial  NUMBER DEFAULT NULL,
        p_id_administrador NUMBER DEFAULT NULL);
    FUNCTION bloques_ocupados(p_id_cancha NUMBER, p_desde DATE, p_hasta DATE) RETURN SYS_REFCURSOR;
END SGCD_PKG_RESERVAS;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_RESERVAS AS
    FUNCTION hay_conflicto(p_id_cancha NUMBER, p_inicio TIMESTAMP, p_fin TIMESTAMP) RETURN BOOLEAN IS
        v_cnt NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_cnt
        FROM   SGCD_RESERVAS r
        WHERE  r.ID_CANCHA = p_id_cancha
        AND    r.ESTADO_RESERVA <> 'CANCELADA'
        AND    r.INICIO_RESERVA < p_fin
        AND    r.TERMINO_RESERVA > p_inicio;
        RETURN v_cnt > 0;
    END hay_conflicto;
    FUNCTION esta_libre(p_id_cancha NUMBER, p_inicio TIMESTAMP, p_fin TIMESTAMP) RETURN BOOLEAN IS
    BEGIN
        RETURN NOT hay_conflicto(p_id_cancha, p_inicio, p_fin);
    END esta_libre;
    PROCEDURE crear_reserva(
        p_id_cancha NUMBER, p_id_modalidad NUMBER, p_inicio TIMESTAMP, p_fin TIMESTAMP,
        p_id_cliente NUMBER DEFAULT NULL, p_id_credencial NUMBER DEFAULT NULL,
        p_id_administrador NUMBER DEFAULT NULL, p_tipo_reserva VARCHAR2 DEFAULT 'NORMAL',
        p_id_torneo NUMBER DEFAULT NULL, p_descuento_porcentaje NUMBER DEFAULT 0,
        p_id_reserva OUT NUMBER) IS
        v_estado_cancha SGCD_CANCHAS.ESTADO_CANCHA%TYPE;
        v_id_recinto    NUMBER;
        v_dia           NUMBER(1);
        v_apertura      CHAR(5);
        v_cierre        CHAR(5);
        v_cliente       NUMBER := p_id_cliente;
        v_origen        VARCHAR2(10);
        v_estado        VARCHAR2(20);
        v_descuento     NUMBER := NVL(p_descuento_porcentaje, 0);
        v_valor         NUMBER;
        v_importe       NUMBER;
        v_tipo          VARCHAR2(10) := UPPER(TRIM(p_tipo_reserva));
    BEGIN
        IF p_fin <= p_inicio THEN
            RAISE_APPLICATION_ERROR(-20019, 'El termino debe ser posterior al inicio');
        END IF;
        IF v_descuento < 0 OR v_descuento > 100 THEN
            RAISE_APPLICATION_ERROR(-20016, 'El descuento debe estar entre 0 y 100');
        END IF;
        IF v_tipo NOT IN ('NORMAL', 'TORNEO') THEN
            RAISE_APPLICATION_ERROR(-20019, 'Tipo de reserva invalido: ' || p_tipo_reserva);
        END IF;
        SELECT c.ESTADO_CANCHA, c.ID_RECINTO INTO v_estado_cancha, v_id_recinto
        FROM   SGCD_CANCHAS c
        WHERE  c.ID_CANCHA = p_id_cancha
        FOR UPDATE;
        IF v_estado_cancha <> 'DISPONIBLE' THEN
            RAISE_APPLICATION_ERROR(-20004, 'La cancha no esta disponible (' || v_estado_cancha || ')');
        END IF;
        v_dia := TRUNC(CAST(p_inicio AS DATE)) - TRUNC(CAST(p_inicio AS DATE), 'IW') + 1;
        BEGIN
            SELECT h.HORA_APERTURA_HORARIO, h.HORA_CIERRE_HORARIO INTO v_apertura, v_cierre
            FROM   SGCD_HORARIOS h
            WHERE  h.ID_RECINTO = v_id_recinto AND h.DIA_SEMANA_HORARIO = v_dia;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE_APPLICATION_ERROR(-20005, 'El recinto no abre el dia ' || v_dia);
        END;
        IF TRUNC(CAST(p_inicio AS DATE)) <> TRUNC(CAST(p_fin AS DATE)) THEN
            RAISE_APPLICATION_ERROR(-20005, 'Una reserva no puede cruzar la medianoche');
        END IF;
        IF TO_CHAR(p_inicio, 'HH24:MI') < v_apertura OR TO_CHAR(p_fin, 'HH24:MI') > v_cierre THEN
            RAISE_APPLICATION_ERROR(-20005,
                'Fuera del horario del recinto (' || v_apertura || '-' || v_cierre || ')');
        END IF;
        IF hay_conflicto(p_id_cancha, p_inicio, p_fin) THEN
            RAISE_APPLICATION_ERROR(-20007, 'La cancha ya esta ocupada en ese horario');
        END IF;
        IF p_id_credencial IS NOT NULL THEN
            v_cliente := SGCD_PKG_AUTH.cliente_de_credencial(p_id_credencial);
            v_origen  := 'WEB';
            v_estado  := 'PENDIENTE';
        ELSIF p_id_administrador IS NOT NULL THEN
            v_origen := 'MOSTRADOR';
            v_estado := 'CONFIRMADA';
        ELSE
            RAISE_APPLICATION_ERROR(-20020, 'Falta el administrador o la credencial que crea la reserva');
        END IF;
        IF v_tipo = 'NORMAL' AND v_cliente IS NULL THEN
            RAISE_APPLICATION_ERROR(-20021, 'Una reserva normal necesita cliente');
        END IF;
        IF v_tipo = 'TORNEO' AND p_id_torneo IS NULL THEN
            RAISE_APPLICATION_ERROR(-20021, 'Un bloque de torneo necesita ID_TORNEO');
        END IF;
        v_valor   := SGCD_PKG_TARIFAS.tarifa_vigente(p_id_cancha, p_id_modalidad, p_inicio);
        v_importe := ROUND(v_valor * (1 - v_descuento / 100), 2);
        INSERT INTO SGCD_RESERVAS (
            ID_CLIENTE, ID_ADMINISTRADOR, ID_CANCHA, ID_MODALIDAD, ID_TORNEO,
            TIPO_RESERVA, ORIGEN_RESERVA, INICIO_RESERVA, TERMINO_RESERVA,
            IMPORTE_ACORDADO_RESERVA, ESTADO_RESERVA)
        VALUES (
            v_cliente, p_id_administrador, p_id_cancha, p_id_modalidad, p_id_torneo,
            v_tipo, v_origen, p_inicio, p_fin, v_importe, v_estado)
        RETURNING ID_RESERVA INTO p_id_reserva;
    END crear_reserva;
    PROCEDURE confirmar_reserva(p_id_reserva NUMBER, p_id_administrador NUMBER) IS
        v_permitido NUMBER;
    BEGIN
        SELECT COUNT(*) INTO v_permitido
        FROM   SGCD_ADMINISTRADORES a
        JOIN   SGCD_CREDENCIALES c ON c.ID_ADMINISTRADOR = a.ID_ADMINISTRADOR
        WHERE  a.ID_ADMINISTRADOR = p_id_administrador
        AND    a.ESTADO_ADMINISTRADOR = 'ACTIVO'
        AND    c.ESTADO_CREDENCIAL = 'ACTIVA'
        AND    c.ROL_CREDENCIAL = 'ADMINISTRADOR';
        IF v_permitido = 0 THEN
            RAISE_APPLICATION_ERROR(-20010, 'Solo un administrador activo puede confirmar reservas');
        END IF;
        UPDATE SGCD_RESERVAS
        SET    ESTADO_RESERVA = 'CONFIRMADA'
        WHERE  ID_RESERVA = p_id_reserva AND ESTADO_RESERVA = 'PENDIENTE';
        IF SQL%ROWCOUNT = 0 THEN
            RAISE_APPLICATION_ERROR(-20009, 'Solo una reserva PENDIENTE puede confirmarse');
        END IF;
    END confirmar_reserva;
    PROCEDURE cancelar_reserva(
        p_id_reserva NUMBER, p_id_credencial NUMBER DEFAULT NULL,
        p_id_administrador NUMBER DEFAULT NULL) IS
        v_cliente NUMBER;
        v_estado  VARCHAR2(20);
        v_cred_cliente NUMBER;
    BEGIN
        SELECT r.ID_CLIENTE, r.ESTADO_RESERVA INTO v_cliente, v_estado
        FROM   SGCD_RESERVAS r
        WHERE  r.ID_RESERVA = p_id_reserva
        FOR UPDATE;
        IF v_estado IN ('CANCELADA', 'COMPLETADA') THEN
            RAISE_APPLICATION_ERROR(-20009, 'La reserva ya esta ' || v_estado);
        END IF;
        IF p_id_credencial IS NOT NULL THEN
            v_cred_cliente := SGCD_PKG_AUTH.cliente_de_credencial(p_id_credencial);
            IF v_cliente IS NULL OR v_cliente <> v_cred_cliente THEN
                RAISE_APPLICATION_ERROR(-20010, 'Esa reserva no es suya');
            END IF;
        ELSIF p_id_administrador IS NULL THEN
            RAISE_APPLICATION_ERROR(-20020, 'Falta quien cancela: credencial o administrador');
        END IF;
        UPDATE SGCD_RESERVAS SET ESTADO_RESERVA = 'CANCELADA' WHERE ID_RESERVA = p_id_reserva;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20008, 'Reserva no encontrada');
    END cancelar_reserva;
    FUNCTION bloques_ocupados(p_id_cancha NUMBER, p_desde DATE, p_hasta DATE) RETURN SYS_REFCURSOR IS
        v_cur SYS_REFCURSOR;
    BEGIN
        OPEN v_cur FOR
            SELECT r.ID_RESERVA, r.INICIO_RESERVA, r.TERMINO_RESERVA,
                   r.ESTADO_RESERVA, r.TIPO_RESERVA
            FROM   SGCD_RESERVAS r
            WHERE  r.ID_CANCHA = p_id_cancha
            AND    r.ESTADO_RESERVA <> 'CANCELADA'
            AND    r.INICIO_RESERVA < CAST(p_hasta AS TIMESTAMP)
            AND    r.TERMINO_RESERVA > CAST(p_desde AS TIMESTAMP)
            ORDER BY r.INICIO_RESERVA;
        RETURN v_cur;
    END bloques_ocupados;
END SGCD_PKG_RESERVAS;
/


-- =====================================================================
-- 5. SGCD_PKG_TORNEOS - torneos, equipos, jugadores y bloques
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_TORNEOS AS
    PROCEDURE crear_torneo(
        p_id_recinto    NUMBER,
        p_id_modalidad  NUMBER,
        p_nombre        VARCHAR2,
        p_fecha_inicio  DATE,
        p_fecha_fin     DATE,
        p_cupos         NUMBER,
        p_descuento     NUMBER DEFAULT 0,
        p_id_torneo     OUT NUMBER);
    PROCEDURE registrar_jugador(
        p_rut         NUMBER,
        p_dv          VARCHAR2,
        p_nombre      VARCHAR2,
        p_id_jugador  OUT NUMBER);
    PROCEDURE inscribir_equipo(
        p_id_torneo        NUMBER,
        p_nombre_equipo    VARCHAR2,
        p_id_cliente_capitan NUMBER,
        p_id_equipo        OUT NUMBER);
    PROCEDURE agregar_jugador(
        p_id_equipo  NUMBER,
        p_rut        NUMBER,
        p_dv         VARCHAR2,
        p_nombre     VARCHAR2);
    PROCEDURE arrendar_bloque(
        p_id_torneo       NUMBER,
        p_id_cancha       NUMBER,
        p_inicio          TIMESTAMP,
        p_fin             TIMESTAMP,
        p_id_administrador NUMBER,
        p_id_reserva      OUT NUMBER);
END SGCD_PKG_TORNEOS;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_TORNEOS AS
    PROCEDURE crear_torneo(
        p_id_recinto NUMBER, p_id_modalidad NUMBER, p_nombre VARCHAR2,
        p_fecha_inicio DATE, p_fecha_fin DATE, p_cupos NUMBER,
        p_descuento NUMBER DEFAULT 0, p_id_torneo OUT NUMBER) IS
    BEGIN
        IF p_descuento < 0 OR p_descuento > 100 THEN
            RAISE_APPLICATION_ERROR(-20016, 'El descuento debe estar entre 0 y 100');
        END IF;
        INSERT INTO SGCD_TORNEOS (
            ID_RECINTO, ID_MODALIDAD, NOMBRE_TORNEO, FECHA_INICIO_TORNEO,
            FECHA_FIN_TORNEO, CUPOS_EQUIPOS_TORNEO, DESCUENTO_PORCENTAJE_TORNEO, ESTADO_TORNEO)
        VALUES (
            p_id_recinto, p_id_modalidad, TRIM(p_nombre), p_fecha_inicio,
            p_fecha_fin, p_cupos, p_descuento, 'PLANIFICADO')
        RETURNING ID_TORNEO INTO p_id_torneo;
    END crear_torneo;
    PROCEDURE registrar_jugador(
        p_rut NUMBER, p_dv VARCHAR2, p_nombre VARCHAR2, p_id_jugador OUT NUMBER) IS
        v_dv     CHAR(1) := SGCD_PKG_CLIENTES.normalizar_dv(p_dv);
        v_existe NUMBER;
        v_cliente NUMBER;
        v_nombre_cliente SGCD_CLIENTES.NOMBRE_CLIENTE%TYPE;
    BEGIN
        IF NOT SGCD_PKG_CLIENTES.rut_valido(p_rut, v_dv) THEN
            RAISE_APPLICATION_ERROR(-20001, 'RUT de jugador invalido: ' || p_rut || '-' || v_dv);
        END IF;
        BEGIN
            SELECT j.ID_JUGADOR INTO v_existe
            FROM   SGCD_JUGADORES j
            WHERE  j.RUT_JUGADOR = p_rut AND j.DV_JUGADOR = v_dv;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN v_existe := NULL;
        END;
        IF v_existe IS NOT NULL THEN
            p_id_jugador := v_existe;
            RETURN;
        END IF;
        SELECT c.ID_CLIENTE, c.NOMBRE_CLIENTE INTO v_cliente, v_nombre_cliente
        FROM   SGCD_CLIENTES c
        WHERE  c.RUT_CLIENTE = p_rut AND c.DV_CLIENTE = v_dv;
        INSERT INTO SGCD_JUGADORES (RUT_JUGADOR, DV_JUGADOR, NOMBRE_JUGADOR, ID_CLIENTE)
        VALUES (p_rut, v_dv, v_nombre_cliente, v_cliente)
        RETURNING ID_JUGADOR INTO p_id_jugador;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            INSERT INTO SGCD_JUGADORES (RUT_JUGADOR, DV_JUGADOR, NOMBRE_JUGADOR, ID_CLIENTE)
            VALUES (p_rut, v_dv, TRIM(p_nombre), NULL)
            RETURNING ID_JUGADOR INTO p_id_jugador;
    END registrar_jugador;
    PROCEDURE inscribir_equipo(
        p_id_torneo NUMBER, p_nombre_equipo VARCHAR2,
        p_id_cliente_capitan NUMBER, p_id_equipo OUT NUMBER) IS
        v_estado  VARCHAR2(15);
        v_cupos   NUMBER;
        v_inscritos NUMBER;
        v_jugador NUMBER;
        v_rut     NUMBER;
        v_dv      CHAR(1);
        v_nombre  VARCHAR2(100);
    BEGIN
        SELECT t.ESTADO_TORNEO, t.CUPOS_EQUIPOS_TORNEO INTO v_estado, v_cupos
        FROM   SGCD_TORNEOS t
        WHERE  t.ID_TORNEO = p_id_torneo
        FOR UPDATE;
        IF v_estado <> 'PLANIFICADO' THEN
            RAISE_APPLICATION_ERROR(-20012, 'El torneo no esta en PLANIFICADO (esta ' || v_estado || ')');
        END IF;
        SELECT COUNT(*) INTO v_inscritos
        FROM   SGCD_EQUIPOS e
        WHERE  e.ID_TORNEO = p_id_torneo AND e.ESTADO_EQUIPO = 'INSCRITO';
        IF v_inscritos >= v_cupos THEN
            RAISE_APPLICATION_ERROR(-20013, 'No quedan cupos: ' || v_inscritos || '/' || v_cupos);
        END IF;
        INSERT INTO SGCD_EQUIPOS (ID_TORNEO, NOMBRE_EQUIPO, ID_CLIENTE_RESPONSABLE, ESTADO_EQUIPO)
        VALUES (p_id_torneo, TRIM(p_nombre_equipo), p_id_cliente_capitan, 'INSCRITO')
        RETURNING ID_EQUIPO INTO p_id_equipo;
        SELECT c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE INTO v_rut, v_dv, v_nombre
        FROM   SGCD_CLIENTES c
        WHERE  c.ID_CLIENTE = p_id_cliente_capitan;
        registrar_jugador(v_rut, v_dv, v_nombre, v_jugador);
        INSERT INTO SGCD_EQUIPO_JUGADORES (ID_EQUIPO, ID_JUGADOR) VALUES (p_id_equipo, v_jugador);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20002, 'El capitan no existe como cliente');
    END inscribir_equipo;
    PROCEDURE agregar_jugador(
        p_id_equipo NUMBER, p_rut NUMBER, p_dv VARCHAR2, p_nombre VARCHAR2) IS
        v_id_torneo NUMBER;
        v_estado_equipo VARCHAR2(10);
        v_estado_torneo VARCHAR2(15);
        v_jugador NUMBER;
        v_cnt     NUMBER;
    BEGIN
        SELECT e.ID_TORNEO, e.ESTADO_EQUIPO, t.ESTADO_TORNEO
        INTO   v_id_torneo, v_estado_equipo, v_estado_torneo
        FROM   SGCD_EQUIPOS e
        JOIN   SGCD_TORNEOS t ON t.ID_TORNEO = e.ID_TORNEO
        WHERE  e.ID_EQUIPO = p_id_equipo;
        IF v_estado_equipo <> 'INSCRITO' THEN
            RAISE_APPLICATION_ERROR(-20015, 'El equipo esta ' || v_estado_equipo);
        END IF;
        IF v_estado_torneo <> 'PLANIFICADO' THEN
            RAISE_APPLICATION_ERROR(-20012, 'El torneo ya no admite inscripciones (' || v_estado_torneo || ')');
        END IF;
        registrar_jugador(p_rut, p_dv, p_nombre, v_jugador);
        SELECT COUNT(*) INTO v_cnt
        FROM   SGCD_EQUIPO_JUGADORES ej
        WHERE  ej.ID_EQUIPO = p_id_equipo AND ej.ID_JUGADOR = v_jugador;
        IF v_cnt > 0 THEN
            RAISE_APPLICATION_ERROR(-20022, 'El jugador ya esta en este equipo');
        END IF;
        SELECT COUNT(*) INTO v_cnt
        FROM   SGCD_EQUIPO_JUGADORES ej
        JOIN   SGCD_EQUIPOS e ON e.ID_EQUIPO = ej.ID_EQUIPO
        WHERE  e.ID_TORNEO = v_id_torneo
        AND    ej.ID_JUGADOR = v_jugador
        AND    ej.ID_EQUIPO <> p_id_equipo;
        IF v_cnt > 0 THEN
            RAISE_APPLICATION_ERROR(-20014, 'El jugador ya esta inscrito en otro equipo de este torneo');
        END IF;
        INSERT INTO SGCD_EQUIPO_JUGADORES (ID_EQUIPO, ID_JUGADOR) VALUES (p_id_equipo, v_jugador);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20015, 'Equipo no encontrado');
    END agregar_jugador;
    PROCEDURE arrendar_bloque(
        p_id_torneo NUMBER, p_id_cancha NUMBER, p_inicio TIMESTAMP, p_fin TIMESTAMP,
        p_id_administrador NUMBER, p_id_reserva OUT NUMBER) IS
        v_modalidad NUMBER;
        v_estado    VARCHAR2(15);
        v_descuento NUMBER;
    BEGIN
        SELECT t.ID_MODALIDAD, t.ESTADO_TORNEO, t.DESCUENTO_PORCENTAJE_TORNEO
        INTO   v_modalidad, v_estado, v_descuento
        FROM   SGCD_TORNEOS t
        WHERE  t.ID_TORNEO = p_id_torneo;
        IF v_estado NOT IN ('PLANIFICADO', 'EN_CURSO') THEN
            RAISE_APPLICATION_ERROR(-20012, 'El torneo esta ' || v_estado || ' y no admite bloques');
        END IF;
        SGCD_PKG_RESERVAS.crear_reserva(
            p_id_cancha            => p_id_cancha,
            p_id_modalidad         => v_modalidad,
            p_inicio               => p_inicio,
            p_fin                  => p_fin,
            p_id_cliente           => NULL,
            p_id_credencial        => NULL,
            p_id_administrador     => p_id_administrador,
            p_tipo_reserva         => 'TORNEO',
            p_id_torneo            => p_id_torneo,
            p_descuento_porcentaje => v_descuento,
            p_id_reserva           => p_id_reserva);
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20015, 'Torneo no encontrado');
    END arrendar_bloque;
END SGCD_PKG_TORNEOS;
/


-- =====================================================================
-- 6. SGCD_PKG_CONSULTAS - lo que un cliente puede ver de si mismo
-- =====================================================================
CREATE OR REPLACE PACKAGE SGCD_PKG_CONSULTAS AS
    PROCEDURE historial_cliente(
        p_id_credencial  NUMBER,
        p_reservas       OUT SYS_REFCURSOR,
        p_pagos          OUT SYS_REFCURSOR);
    FUNCTION estado_cuenta(p_id_credencial NUMBER) RETURN SYS_REFCURSOR;
END SGCD_PKG_CONSULTAS;
/
CREATE OR REPLACE PACKAGE BODY SGCD_PKG_CONSULTAS AS
    PROCEDURE historial_cliente(
        p_id_credencial NUMBER, p_reservas OUT SYS_REFCURSOR, p_pagos OUT SYS_REFCURSOR) IS
        v_cliente NUMBER;
    BEGIN
        v_cliente := SGCD_PKG_AUTH.cliente_de_credencial(p_id_credencial);
        OPEN p_reservas FOR
            SELECT r.ID_RESERVA, r.INICIO_RESERVA, r.TERMINO_RESERVA, r.ESTADO_RESERVA,
                   r.TIPO_RESERVA, r.IMPORTE_ACORDADO_RESERVA, c.NOMBRE_CANCHA
            FROM   SGCD_RESERVAS r
            JOIN   SGCD_CANCHAS c ON c.ID_CANCHA = r.ID_CANCHA
            WHERE  r.ID_CLIENTE = v_cliente
            ORDER BY r.INICIO_RESERVA DESC;
        OPEN p_pagos FOR
            SELECT p.ID_PAGO, p.FECHA_PAGO, p.IMPORTE_PAGO, p.MEDIO_PAGO
            FROM   SGCD_PAGOS p
            JOIN   SGCD_RESERVAS r ON r.ID_RESERVA = p.ID_RESERVA
            WHERE  r.ID_CLIENTE = v_cliente
            ORDER BY p.FECHA_PAGO DESC;
    END historial_cliente;
    FUNCTION estado_cuenta(p_id_credencial NUMBER) RETURN SYS_REFCURSOR IS
        v_cliente NUMBER;
        v_cur SYS_REFCURSOR;
    BEGIN
        v_cliente := SGCD_PKG_AUTH.cliente_de_credencial(p_id_credencial);
        OPEN v_cur FOR
            SELECT c.ID_CLIENTE, c.RUT_CLIENTE, c.DV_CLIENTE, c.NOMBRE_CLIENTE,
                   c.CORREO_CLIENTE, c.TELEFONO_CLIENTE
            FROM   SGCD_CLIENTES c
            WHERE  c.ID_CLIENTE = v_cliente;
        RETURN v_cur;
    END estado_cuenta;
END SGCD_PKG_CONSULTAS;
/
