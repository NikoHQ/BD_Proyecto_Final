-- =====================================================================
-- SGCD_PKG_TARIFAS - cotizacion por bloque de una hora
-- Requiere: 10_ddl_sgcd_19.sql y 11_catalogos_sgcd_19.sql
--
-- Solo lee: no escribe, no bloquea y no decide nada del calendario. Para cada
-- bloque busca UNA tarifa activa de esa cancha y modalidad cuyo dia y franja
-- cubran la hora, y cuya vigencia cubra la fecha de la reserva. La fecha manda:
-- una tarifa programada para diciembre no cotiza una reserva de noviembre.
--
-- El dia de la semana se calcula como ISO (lunes = 1) sin depender de
-- NLS_TERRITORY, para que coincida con SGCD_TARIFAS.DIA_SEMANA.
--
-- Si para un bloque no hay tarifa, falla: no se cotiza a medias. Si aparece
-- mas de una tarifa activa para el mismo bloque, tambien falla: prefiero un
-- error a elegir un precio.
--
-- Codigos: -20006 sin tarifa vigente para el bloque, -20019 rango de tiempo o
-- de bloques invalido, -20033 mas de una tarifa activa para el mismo bloque.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_TARIFAS AS
    FUNCTION dia_semana(p_fecha DATE) RETURN NUMBER;
    FUNCTION valor_bloque(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_inicio  VARCHAR2) RETURN NUMBER;
    PROCEDURE cotizar(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER,
        p_total        OUT NUMBER,
        p_detalle      OUT SYS_REFCURSOR);
END SGCD_PKG_TARIFAS;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_TARIFAS AS

    PROCEDURE validar_hora(p_hora VARCHAR2) IS
    BEGIN
        IF p_hora IS NULL
           OR NOT REGEXP_LIKE(TRIM(p_hora), '^([01][0-9]|2[0-3]):[0-5][0-9]$') THEN
            RAISE_APPLICATION_ERROR(-20019, 'La hora debe venir en formato HH:MI');
        END IF;
    END validar_hora;

    FUNCTION dia_semana(p_fecha DATE) RETURN NUMBER IS
    BEGIN
        IF p_fecha IS NULL THEN
            RAISE_APPLICATION_ERROR(-20019, 'Falta la fecha de la reserva');
        END IF;
        RETURN TRUNC(p_fecha) - TRUNC(p_fecha, 'IW') + 1;
    END dia_semana;

    FUNCTION valor_bloque(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_inicio  VARCHAR2) RETURN NUMBER
    IS
        v_valor NUMBER(12,2);
        v_hora  VARCHAR2(5) := TRIM(p_hora_inicio);
        v_dia   NUMBER;
    BEGIN
        validar_hora(v_hora);
        v_dia := dia_semana(p_fecha);
        SELECT t.VALOR_HORA INTO v_valor
        FROM   SGCD_TARIFAS t
        WHERE  t.ID_CANCHA = p_id_cancha
          AND  t.ID_MODALIDAD = p_id_modalidad
          AND  t.ESTADO_TARIFA = 'ACTIVA'
          AND  t.DIA_SEMANA = v_dia
          AND  v_hora >= t.HORA_DESDE
          AND  v_hora <  t.HORA_HASTA
          AND  TRUNC(p_fecha) >= TRUNC(t.VIGENTE_DESDE)
          AND  (t.VIGENTE_HASTA IS NULL OR TRUNC(p_fecha) <= TRUNC(t.VIGENTE_HASTA));
        RETURN v_valor;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE_APPLICATION_ERROR(-20006,
                'Sin tarifa vigente para la cancha ' || p_id_cancha
                || ', modalidad ' || p_id_modalidad || ' a las ' || v_hora);
        WHEN TOO_MANY_ROWS THEN
            RAISE_APPLICATION_ERROR(-20033,
                'Hay mas de una tarifa activa para la cancha ' || p_id_cancha
                || ', modalidad ' || p_id_modalidad || ' a las ' || v_hora);
    END valor_bloque;

    PROCEDURE cotizar(
        p_id_cancha    NUMBER,
        p_id_modalidad NUMBER,
        p_fecha        DATE,
        p_hora_desde   VARCHAR2,
        p_bloques      NUMBER,
        p_total        OUT NUMBER,
        p_detalle      OUT SYS_REFCURSOR)
    IS
        v_hora   VARCHAR2(5) := TRIM(p_hora_desde);
        v_dia    NUMBER;
        v_inicio DATE;
        v_bloque VARCHAR2(5);
    BEGIN
        validar_hora(v_hora);
        IF p_bloques IS NULL OR p_bloques < 1 OR p_bloques > 14
           OR p_bloques <> TRUNC(p_bloques) THEN
            RAISE_APPLICATION_ERROR(-20019, 'La cantidad de bloques debe ser un entero entre 1 y 14');
        END IF;
        v_dia := dia_semana(p_fecha);
        v_inicio := TO_DATE(v_hora, 'HH24:MI');
        p_total := 0;
        FOR i IN 1 .. p_bloques LOOP
            v_bloque := TO_CHAR(v_inicio + (i - 1) / 24, 'HH24:MI');
            p_total := p_total + valor_bloque(p_id_cancha, p_id_modalidad, p_fecha, v_bloque);
        END LOOP;
        OPEN p_detalle FOR
            SELECT b.HORA_INICIO, b.HORA_TERMINO, t.VALOR_HORA
            FROM   (SELECT TO_CHAR(v_inicio + (n.n - 1) / 24, 'HH24:MI') AS HORA_INICIO,
                           TO_CHAR(v_inicio + n.n / 24, 'HH24:MI') AS HORA_TERMINO
                    FROM   (SELECT LEVEL AS n FROM DUAL CONNECT BY LEVEL <= p_bloques) n) b
            JOIN   SGCD_TARIFAS t
              ON   t.ID_CANCHA = p_id_cancha
             AND   t.ID_MODALIDAD = p_id_modalidad
             AND   t.ESTADO_TARIFA = 'ACTIVA'
             AND   t.DIA_SEMANA = v_dia
             AND   b.HORA_INICIO >= t.HORA_DESDE
             AND   b.HORA_INICIO <  t.HORA_HASTA
             AND   TRUNC(p_fecha) >= TRUNC(t.VIGENTE_DESDE)
             AND   (t.VIGENTE_HASTA IS NULL OR TRUNC(p_fecha) <= TRUNC(t.VIGENTE_HASTA))
            ORDER  BY b.HORA_INICIO;
    END cotizar;

END SGCD_PKG_TARIFAS;
/
