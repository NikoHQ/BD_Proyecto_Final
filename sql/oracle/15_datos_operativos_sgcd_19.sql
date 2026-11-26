-- Datos operativos ficticios para el recorrido de entrega del 27-11-2026.
-- Requiere el DDL 10, los catalogos 11 y los paquetes 12a a 12j.
-- Ejecutar en un esquema de demostracion. Una sola transaccion agrega los
-- datos. La ficha 30901016 identifica una carga previa de este lote.
-- Los huecos de secuencia despues de un rollback son normales.

SET DEFINE OFF
SET SERVEROUTPUT ON
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE
    c_referencia CONSTANT DATE := DATE '2026-11-27';
    c_rut_base   CONSTANT NUMBER := 30901000;
    c_lote       CONSTANT VARCHAR2(80) := 'equipo16@sgcd.example';
    v_admin      NUMBER;
    v_lote       SGCD_CLIENTES.CORREO_CLIENTE%TYPE;
    v_creada     BOOLEAN;
    v_id         NUMBER;
    v_cliente    SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
    v_nombres    SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Valentina Muñoz', 'Benjamín Castro', 'Isidora Fuentes', 'Matías González',
        'Catalina Silva', 'Vicente Herrera', 'Antonia Sepúlveda', 'Tomás Riquelme',
        'Florencia Morales', 'Joaquín Alarcón', 'Emilia Rivas', 'Felipe Araya',
        'Sofía Leiva', 'Martín Olivares', 'Fernanda Cárdenas', 'Nicolás Valdés');
    v_rut_control NUMBER := c_rut_base + v_nombres.COUNT;
    v_medios     SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'DEBITO', 'TRANSFERENCIA', 'EFECTIVO', 'CREDITO');
    v_torneo     SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
    v_canchas    SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
    v_modalidad  SYS.ODCINUMBERLIST := SYS.ODCINUMBERLIST();
    v_nombres_t  SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
        'Copa Primavera Fútbol 6', 'Torneo Pádel Mixto', 'Copa de Tenis Las Rastras');
    v_fecha_t    DATE;
    v_demoweb    NUMBER;
    v_nuevoweb   NUMBER;
    v_dia        DATE;

    FUNCTION id_cancha(p_nombre VARCHAR2) RETURN NUMBER IS
        v_resultado NUMBER;
    BEGIN
        SELECT ID_CANCHA INTO v_resultado
        FROM   SGCD_CANCHAS
        WHERE  NOMBRE_CANCHA = p_nombre;
        RETURN v_resultado;
    END id_cancha;

    FUNCTION cliente_web(p_login VARCHAR2) RETURN NUMBER IS
        v_resultado NUMBER;
    BEGIN
        SELECT c.ID_CLIENTE INTO v_resultado
        FROM   SGCD_CLIENTES c
        JOIN   SGCD_USUARIOS u ON u.ID_USUARIO = c.ID_USUARIO
        WHERE  u.LOGIN = p_login AND u.ROL = 'CLIENTE'
          AND  u.ESTADO_USUARIO = 'ACTIVO' AND c.ESTADO_CLIENTE = 'ACTIVO';
        RETURN v_resultado;
    END cliente_web;

    PROCEDURE reserva(
        p_cliente NUMBER, p_cancha NUMBER, p_categoria NUMBER, p_fecha DATE,
        p_hora NUMBER, p_horas NUMBER, p_origen VARCHAR2, p_estado VARCHAR2,
        p_medio VARCHAR2 DEFAULT NULL, p_torneo NUMBER DEFAULT NULL) IS
        v_inicio  DATE := TRUNC(p_fecha) + p_hora / 24;
        v_termino DATE := v_inicio + p_horas / 24;
        v_hora    VARCHAR2(5) := TO_CHAR(v_inicio, 'HH24:MI');
        v_estado  VARCHAR2(15) := p_estado;
        v_id_res  NUMBER;
        v_precio  NUMBER := 0;
        v_n       NUMBER;
        v_horario NUMBER;
    BEGIN
        IF v_inicio > SYSDATE THEN
            IF p_torneo IS NOT NULL THEN
                SGCD_PKG_RESERVAS.crear_reserva_torneo(
                    p_torneo, p_cancha, p_fecha, v_hora, p_horas, v_id_res);
            ELSIF p_origen = 'WEB' THEN
                SGCD_PKG_RESERVAS.crear_solicitud_web(
                    p_cliente, p_cancha, p_categoria, p_fecha, v_hora, p_horas, v_id_res);
                IF p_estado = 'CONFIRMADA' THEN
                    SGCD_PKG_RESERVAS.confirmar_reserva(v_id_res);
                END IF;
            ELSE
                SGCD_PKG_RESERVAS.crear_reserva(p_cliente, v_admin, p_cancha, p_categoria,
                    p_fecha, v_hora, p_horas, p_origen, v_id_res);
            END IF;
            IF p_estado = 'CANCELADA' THEN
                SGCD_PKG_RESERVAS.cancelar_reserva(v_id_res);
            END IF;
            IF p_medio IS NOT NULL AND p_estado = 'CONFIRMADA' THEN
                SGCD_PKG_PAGOS.registrar_pago(v_id_res, p_medio, v_admin);
            END IF;
            RETURN;
        END IF;

        -- La API comercial rechaza fechas pasadas. Las filas historicas
        -- usan los mismos catalogos, tarifa por hora y regla de solapes.
        SELECT h.ID_HORARIO INTO v_horario
        FROM   SGCD_CANCHAS c
        JOIN   SGCD_CANCHAS_MODALIDADES cm ON cm.ID_CANCHA = c.ID_CANCHA
        JOIN   SGCD_HORARIOS h ON h.ID_RECINTO = c.ID_RECINTO
        WHERE  c.ID_CANCHA = p_cancha AND c.ESTADO_CANCHA = 'DISPONIBLE'
          AND  cm.ID_MODALIDAD = p_categoria
          AND  h.DIA_SEMANA = SGCD_PKG_TARIFAS.dia_semana(p_fecha);
        FOR i IN 0 .. p_horas - 1 LOOP
            SELECT COUNT(*) INTO v_n
            FROM   SGCD_BLOQUES_HORARIOS b
            WHERE  b.ID_HORARIO = v_horario
              AND  b.HORA_INICIO = TO_CHAR(v_inicio + i / 24, 'HH24:MI')
              AND  b.HORA_TERMINO = TO_CHAR(v_inicio + (i + 1) / 24, 'HH24:MI');
            IF v_n <> 1 THEN
                RAISE_APPLICATION_ERROR(-20981, 'Bloque de demo fuera del horario o ausente');
            END IF;
            v_precio := v_precio + SGCD_PKG_TARIFAS.valor_bloque(
                p_cancha, p_categoria, p_fecha, TO_CHAR(v_inicio + i / 24, 'HH24:MI'));
        END LOOP;
        -- Serializa la comprobacion con las mismas canchas que la API.
        FOR c IN (
            SELECT ID_CANCHA FROM SGCD_CANCHAS
            WHERE ID_CANCHA = p_cancha
               OR ID_CANCHA IN (SELECT ID_CANCHA_PEQUENA FROM SGCD_CANCHAS_COMPONENTES
                                WHERE ID_CANCHA_GRANDE = p_cancha)
               OR ID_CANCHA IN (SELECT ID_CANCHA_GRANDE FROM SGCD_CANCHAS_COMPONENTES
                                WHERE ID_CANCHA_PEQUENA = p_cancha)
            ORDER BY ID_CANCHA
            FOR UPDATE
        ) LOOP
            NULL;
        END LOOP;
        IF p_estado = 'PENDIENTE' THEN
            v_estado := 'CANCELADA';
        ELSIF p_estado = 'CONFIRMADA' AND v_termino <= SYSDATE THEN
            v_estado := 'COMPLETADA';
        END IF;
        IF v_estado <> 'CANCELADA' THEN
            SELECT COUNT(*) INTO v_n
            FROM   SGCD_RESERVAS r
            WHERE  r.ESTADO_RESERVA <> 'CANCELADA'
              AND  r.INICIO_RESERVA < v_termino AND r.TERMINO_RESERVA > v_inicio
              AND  (r.ID_CANCHA = p_cancha
                OR  r.ID_CANCHA IN (SELECT ID_CANCHA_PEQUENA FROM SGCD_CANCHAS_COMPONENTES
                                    WHERE ID_CANCHA_GRANDE = p_cancha)
                OR  r.ID_CANCHA IN (SELECT ID_CANCHA_GRANDE FROM SGCD_CANCHAS_COMPONENTES
                                    WHERE ID_CANCHA_PEQUENA = p_cancha));
            IF v_n > 0 THEN
                RAISE_APPLICATION_ERROR(-20982, 'La carga de demo se cruza con una reserva existente');
            END IF;
        END IF;
        INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_ADMINISTRADOR, ID_CANCHA, ID_MODALIDAD,
                                   ID_TORNEO, INICIO_RESERVA, TERMINO_RESERVA,
                                   IMPORTE_ACORDADO, ORIGEN_RESERVA, ESTADO_RESERVA)
        VALUES (p_cliente, CASE WHEN p_origen = 'MOSTRADOR' THEN v_admin END,
                p_cancha, p_categoria, p_torneo, v_inicio, v_termino,
                v_precio, p_origen, v_estado)
        RETURNING ID_RESERVA INTO v_id_res;
        IF p_medio IS NOT NULL THEN
            INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, FECHA_PAGO, MEDIO_PAGO, ESTADO_PAGO)
            VALUES (v_id_res, v_precio, v_inicio - 1 / 24, p_medio,
                    CASE WHEN v_estado = 'CANCELADA' THEN 'ANULADO' ELSE 'PAGADO' END);
        END IF;
    END reserva;

    PROCEDURE equipo(
        p_categoria PLS_INTEGER, p_numero PLS_INTEGER, p_capitan NUMBER,
        p_nombre VARCHAR2, p_jugadores PLS_INTEGER, p_retirado BOOLEAN DEFAULT FALSE) IS
        v_inscripcion NUMBER;
        v_rut         NUMBER;
        v_nombres_j   SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Gabriel', 'Elisa', 'Diego', 'Paula', 'Lucas', 'Camila', 'Bruno', 'Amanda', 'Ignacio');
        v_apellidos_j SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST(
            'Pavez', 'Guzmán', 'Acuña', 'Cáceres', 'Vera', 'Navarrete', 'Arriagada', 'Vidal', 'Carrasco');
    BEGIN
        SGCD_PKG_TORNEOS.inscribir_equipo(
            v_torneo(p_categoria), p_capitan, p_nombre, v_inscripcion);
        FOR i IN 2 .. p_jugadores LOOP
            v_rut := 30902000 + p_categoria * 100 + p_numero * 10 + i;
            SGCD_PKG_TORNEOS.agregar_jugador(v_inscripcion, v_rut,
                SGCD_PKG_CLIENTES.dv_calculado(v_rut),
                v_nombres_j(i - 1) || ' ' || v_apellidos_j(MOD(i + p_numero + p_categoria, 9) + 1));
        END LOOP;
        UPDATE SGCD_INSCRIPCIONES_TORNEO
        SET    FECHA_INSCRIPCION = c_referencia - 7 + p_numero + (p_categoria - 1) / 24
        WHERE  ID_INSCRIPCION = v_inscripcion;
        IF p_retirado THEN
            SGCD_PKG_TORNEOS.retirar_equipo(v_inscripcion);
        END IF;
    END equipo;
BEGIN
    -- El candado del administrador de laboratorio serializa dos cargas.
    SELECT a.ID_ADMINISTRADOR INTO v_admin
    FROM   SGCD_ADMINISTRADORES a
    JOIN   SGCD_USUARIOS u ON u.ID_USUARIO = a.ID_USUARIO
    WHERE  u.LOGIN = 'admin' AND u.ROL = 'ADMINISTRADOR'
      AND  u.ESTADO_USUARIO = 'ACTIVO' AND a.ESTADO_ADMINISTRADOR = 'ACTIVO'
    FOR UPDATE OF a.ID_ADMINISTRADOR;

    BEGIN
        SELECT CORREO_CLIENTE INTO v_lote
        FROM   SGCD_CLIENTES
        WHERE  RUT_CLIENTE = v_rut_control;
        IF v_lote IS NULL OR v_lote <> c_lote THEN
            RAISE_APPLICATION_ERROR(-20983, 'RUT de control ocupado por una ficha ajena a la carga');
        END IF;
        DBMS_OUTPUT.PUT_LINE('Datos operativos ya cargados. Se conservan los cambios posteriores.');
        RETURN;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN NULL;
    END;

    v_demoweb := cliente_web('demo');
    v_nuevoweb := cliente_web('nuevo');
    v_canchas.EXTEND(10);
    FOR i IN 1 .. 6 LOOP
        v_canchas(i) := id_cancha('Fútbol 6 · Cancha ' || i);
    END LOOP;
    v_canchas(7) := id_cancha('Cancha grande');
    v_canchas(8) := id_cancha('Pádel 1');
    v_canchas(9) := id_cancha('Pádel 2');
    v_canchas(10) := id_cancha('Tenis 1');
    v_torneo.EXTEND(3);
    v_modalidad.EXTEND(3);
    FOR i IN 1 .. 3 LOOP
        SELECT ID_TORNEO, ID_MODALIDAD INTO v_torneo(i), v_modalidad(i)
        FROM   SGCD_TORNEOS
        WHERE  NOMBRE_TORNEO = v_nombres_t(i);
    END LOOP;

    v_cliente.EXTEND(v_nombres.COUNT);
    FOR i IN 1 .. v_nombres.COUNT LOOP
        v_id := c_rut_base + i;
        SGCD_PKG_CLIENTES.crear_ficha(v_id, SGCD_PKG_CLIENTES.dv_calculado(v_id),
            v_nombres(i), '+56 9 0000 ' || TO_CHAR(i, 'FM0000'),
            'equipo' || TO_CHAR(i, 'FM00') || '@sgcd.example', v_cliente(i), v_creada);
        IF NOT v_creada THEN
            RAISE_APPLICATION_ERROR(-20983, 'Un RUT de la carga ya pertenece a otra ficha');
        END IF;
    END LOOP;
    SGCD_PKG_CLIENTES.cambiar_estado(v_cliente(15), 'INACTIVO');

    -- Tres semanas de actividad previa en distintos dias y canchas.
    FOR i IN 1 .. 3 LOOP
        v_dia := c_referencia - 7 * i - 2;
        reserva(v_cliente(i), v_canchas(1), v_modalidad(1), v_dia, 17, 2,
                'MOSTRADOR', 'COMPLETADA', v_medios(i));
        reserva(v_cliente(i + 3), v_canchas(9), v_modalidad(2), v_dia, 19, 1,
                'MOSTRADOR', 'COMPLETADA', v_medios(i + 1));
        reserva(v_demoweb, v_canchas(10), v_modalidad(3), v_dia, 18, 1,
                'WEB', 'COMPLETADA', 'TRANSFERENCIA');
        v_dia := c_referencia - 7 * i;
        reserva(v_cliente(i + 6), v_canchas(7), v_modalidad(1), v_dia, 18, 2,
                'MOSTRADOR', 'COMPLETADA', v_medios(i + 1));
        reserva(v_cliente(i + 9), v_canchas(4), v_modalidad(1), v_dia, 19, 1,
                'MOSTRADOR', 'COMPLETADA', v_medios(i));
        reserva(v_demoweb, v_canchas(8), v_modalidad(2), v_dia, 17, 1,
                'WEB', 'COMPLETADA', 'DEBITO');
        v_dia := c_referencia - 7 * i + 1;
        reserva(v_cliente(i + 11), v_canchas(5), v_modalidad(1), v_dia, 11, 1,
                'MOSTRADOR', 'COMPLETADA', v_medios(i));
        reserva(v_nuevoweb, v_canchas(9), v_modalidad(2), v_dia, 12, 2,
                'WEB', 'COMPLETADA', 'CREDITO');
        reserva(v_cliente(16), v_canchas(10), v_modalidad(3), v_dia, 14, 1,
                'MOSTRADOR', 'COMPLETADA', 'EFECTIVO');
    END LOOP;
    reserva(v_cliente(4), v_canchas(2), v_modalidad(1), c_referencia - 3,
            18, 1, 'MOSTRADOR', 'CANCELADA', 'DEBITO');

    -- Agenda de la grabacion y dias siguientes: por confirmar, con y sin pago.
    reserva(v_demoweb, v_canchas(8), v_modalidad(2), c_referencia, 17, 2, 'WEB', 'PENDIENTE');
    reserva(v_nuevoweb, v_canchas(10), v_modalidad(3), c_referencia, 18, 1, 'WEB', 'PENDIENTE');
    reserva(v_cliente(1), v_canchas(7), v_modalidad(1), c_referencia, 18, 2,
            'MOSTRADOR', 'CONFIRMADA', 'TRANSFERENCIA');
    reserva(v_cliente(2), v_canchas(4), v_modalidad(1), c_referencia, 18, 1,
            'MOSTRADOR', 'CONFIRMADA');
    reserva(v_cliente(3), v_canchas(5), v_modalidad(1), c_referencia, 20, 1,
            'MOSTRADOR', 'CONFIRMADA', 'EFECTIVO');
    reserva(v_demoweb, v_canchas(9), v_modalidad(2), c_referencia + 1, 13, 1, 'WEB', 'CONFIRMADA');
    reserva(v_nuevoweb, v_canchas(8), v_modalidad(2), c_referencia + 2, 10, 2, 'WEB', 'PENDIENTE');
    reserva(v_cliente(5), v_canchas(3), v_modalidad(1), c_referencia + 2, 11, 2,
            'MOSTRADOR', 'CONFIRMADA', 'CREDITO');
    reserva(v_cliente(6), v_canchas(1), v_modalidad(1), c_referencia + 2, 11, 1,
            'MOSTRADOR', 'CONFIRMADA');
    reserva(v_demoweb, v_canchas(10), v_modalidad(3), c_referencia + 4, 18, 1, 'WEB', 'CANCELADA');
    reserva(v_cliente(11), v_canchas(6), v_modalidad(1), c_referencia + 4, 18, 2,
            'MOSTRADOR', 'CONFIRMADA', 'DEBITO');
    reserva(v_nuevoweb, v_canchas(9), v_modalidad(2), c_referencia + 5, 18, 1, 'WEB', 'PENDIENTE');

    -- Los bloques del torneo ocupan reservas sin ficha de cliente.
    SELECT FECHA_INICIO INTO v_fecha_t FROM SGCD_TORNEOS WHERE ID_TORNEO = v_torneo(1);
    reserva(NULL, v_canchas(7), v_modalidad(1), v_fecha_t, 9, 3, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(1));
    reserva(NULL, v_canchas(4), v_modalidad(1), v_fecha_t, 9, 2, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(1));
    reserva(NULL, v_canchas(6), v_modalidad(1), v_fecha_t + 1, 10, 3, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(1));
    SELECT FECHA_INICIO INTO v_fecha_t FROM SGCD_TORNEOS WHERE ID_TORNEO = v_torneo(2);
    reserva(NULL, v_canchas(8), v_modalidad(2), v_fecha_t, 9, 3, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(2));
    reserva(NULL, v_canchas(9), v_modalidad(2), v_fecha_t, 10, 2, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(2));
    reserva(NULL, v_canchas(8), v_modalidad(2), v_fecha_t + 1, 13, 2, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(2));
    SELECT FECHA_INICIO INTO v_fecha_t FROM SGCD_TORNEOS WHERE ID_TORNEO = v_torneo(3);
    reserva(NULL, v_canchas(10), v_modalidad(3), v_fecha_t, 10, 3, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(3));
    reserva(NULL, v_canchas(10), v_modalidad(3), v_fecha_t + 1, 14, 2, 'TORNEO', 'CONFIRMADA', NULL, v_torneo(3));

    equipo(1, 1, v_demoweb,    'Los Halcones del Maule', 8);
    equipo(1, 2, v_cliente(1), 'Deportivo Cordillera', 10);
    equipo(1, 3, v_cliente(4), 'Rayo Talquino', 6);
    equipo(1, 4, v_cliente(6), 'Atlético Oriente', 7, TRUE);
    equipo(2, 1, v_demoweb,    'Doble Rebote', 2);
    equipo(2, 2, v_cliente(5), 'Red Cruzada', 2);
    equipo(2, 3, v_cliente(8), 'Punto de Oro', 2);
    equipo(3, 1, v_nuevoweb,   'Álex Soto', 1);
    equipo(3, 2, v_cliente(9), 'Florencia Morales', 1);
    equipo(3, 3, v_cliente(16),'Nicolás Valdés', 1);
    DBMS_OUTPUT.PUT_LINE('Carga completada: 16 fichas, 48 reservas y 10 inscripciones.');
END;
/
COMMIT;

PROMPT Ventana recomendada para reportes: 01-11-2026 a 13-12-2026.
SELECT ORIGEN_RESERVA, ESTADO_RESERVA, COUNT(*) AS RESERVAS
FROM   SGCD_RESERVAS
WHERE  INICIO_RESERVA >= DATE '2026-11-01' AND INICIO_RESERVA < DATE '2026-12-14'
GROUP  BY ORIGEN_RESERVA, ESTADO_RESERVA
ORDER  BY ORIGEN_RESERVA, ESTADO_RESERVA;
SELECT ESTADO_PAGO, COUNT(*) AS PAGOS, SUM(IMPORTE_PAGO) AS IMPORTE
FROM   SGCD_PAGOS
WHERE  FECHA_PAGO >= DATE '2026-11-01' AND FECHA_PAGO < DATE '2026-12-14'
GROUP  BY ESTADO_PAGO
ORDER  BY ESTADO_PAGO;
SELECT t.NOMBRE_TORNEO, i.ESTADO_INSCRIPCION, COUNT(*) AS EQUIPOS
FROM   SGCD_INSCRIPCIONES_TORNEO i
JOIN   SGCD_TORNEOS t ON t.ID_TORNEO = i.ID_TORNEO
GROUP  BY t.NOMBRE_TORNEO, i.ESTADO_INSCRIPCION
ORDER  BY t.NOMBRE_TORNEO, i.ESTADO_INSCRIPCION;

WHENEVER SQLERROR CONTINUE NONE
