-- =====================================================================
-- SGCD_PKG_CONSULTAS - los tres reportes del recinto
-- Requiere: 10_ddl_sgcd_19.sql y 12g_pkg_reservas.sql
--
-- Todos piden rango: p_desde se toma a las 00:00 y p_hasta a las 23:59:59,
-- ambos inclusive. Un rango nulo, invertido o de mas de 366 dias falla.
--
--  * ingresos: solo pagos PAGADO, agrupados por dia. Un pago ANULADO no suma.
--    Es un reporte de administracion y no recibe filtro de cliente: el portal
--    no lo expone al rol cliente.
--  * reservas_por_cancha: reservas no CANCELADA que empiezan en el rango, con
--    horas e importe acordado. Los bloques de torneo cuentan como ocupacion.
--  * clientes_por_reservas: reservas con cliente; las de torneo no tienen
--    cliente y quedan fuera. Ordena por cantidad de reservas.
--
-- El filtro de propiedad es p_id_cliente opcional: con ID restringe a ese
-- cliente, con NULL devuelve la vista de administracion.
--
-- Codigo unico: -20080 rango invalido.
--
-- Sin lineas en blanco dentro de cada unidad: SQL*Plus con SQLBLANKLINES OFF
-- corta la sentencia en la linea vacia.
-- =====================================================================


SET DEFINE OFF


CREATE OR REPLACE PACKAGE SGCD_PKG_CONSULTAS AS
    PROCEDURE ingresos(
        p_desde  DATE,
        p_hasta  DATE,
        p_cursor OUT SYS_REFCURSOR);
    PROCEDURE reservas_por_cancha(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR);
    PROCEDURE clientes_por_reservas(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR);
END SGCD_PKG_CONSULTAS;
/


CREATE OR REPLACE PACKAGE BODY SGCD_PKG_CONSULTAS AS

    PROCEDURE validar_rango(p_desde DATE, p_hasta DATE) IS
    BEGIN
        IF p_desde IS NULL OR p_hasta IS NULL THEN
            RAISE_APPLICATION_ERROR(-20080, 'El reporte necesita fecha desde y hasta');
        END IF;
        IF TRUNC(p_hasta) < TRUNC(p_desde) THEN
            RAISE_APPLICATION_ERROR(-20080, 'La fecha hasta no puede ser anterior a la desde');
        END IF;
        IF TRUNC(p_hasta) - TRUNC(p_desde) > 366 THEN
            RAISE_APPLICATION_ERROR(-20080, 'El rango no puede superar 366 dias');
        END IF;
    END validar_rango;

    PROCEDURE ingresos(
        p_desde  DATE,
        p_hasta  DATE,
        p_cursor OUT SYS_REFCURSOR) IS
    BEGIN
        validar_rango(p_desde, p_hasta);
        OPEN p_cursor FOR
            SELECT TRUNC(p.FECHA_PAGO) AS DIA,
                   COUNT(*) AS PAGOS,
                   SUM(p.IMPORTE_PAGO) AS TOTAL
            FROM   SGCD_PAGOS p
            WHERE  p.ESTADO_PAGO = 'PAGADO'
              AND  p.FECHA_PAGO >= TRUNC(p_desde)
              AND  p.FECHA_PAGO < TRUNC(p_hasta) + 1
            GROUP  BY TRUNC(p.FECHA_PAGO)
            ORDER  BY 1;
    END ingresos;

    PROCEDURE reservas_por_cancha(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR) IS
    BEGIN
        validar_rango(p_desde, p_hasta);
        OPEN p_cursor FOR
            SELECT c.NOMBRE_CANCHA AS CANCHA,
                   m.NOMBRE_MODALIDAD AS MODALIDAD,
                   COUNT(*) AS RESERVAS,
                   ROUND(SUM(r.TERMINO_RESERVA - r.INICIO_RESERVA) * 24, 2) AS HORAS,
                   SUM(r.IMPORTE_ACORDADO) AS IMPORTE
            FROM   SGCD_RESERVAS r
            JOIN   SGCD_CANCHAS c ON c.ID_CANCHA = r.ID_CANCHA
            JOIN   SGCD_MODALIDADES m ON m.ID_MODALIDAD = r.ID_MODALIDAD
            WHERE  r.ESTADO_RESERVA <> 'CANCELADA'
              AND  r.INICIO_RESERVA >= TRUNC(p_desde)
              AND  r.INICIO_RESERVA < TRUNC(p_hasta) + 1
              AND  (p_id_cliente IS NULL OR r.ID_CLIENTE = p_id_cliente)
            GROUP  BY c.NOMBRE_CANCHA, m.NOMBRE_MODALIDAD
            ORDER  BY 1, 2;
    END reservas_por_cancha;

    PROCEDURE clientes_por_reservas(
        p_desde      DATE,
        p_hasta      DATE,
        p_id_cliente NUMBER DEFAULT NULL,
        p_cursor     OUT SYS_REFCURSOR) IS
    BEGIN
        validar_rango(p_desde, p_hasta);
        OPEN p_cursor FOR
            SELECT cl.ID_CLIENTE AS ID_CLIENTE,
                   cl.NOMBRE_CLIENTE AS CLIENTE,
                   cl.RUT_CLIENTE || '-' || cl.DV_CLIENTE AS RUT,
                   COUNT(*) AS RESERVAS,
                   ROUND(SUM(r.TERMINO_RESERVA - r.INICIO_RESERVA) * 24, 2) AS HORAS,
                   SUM(r.IMPORTE_ACORDADO) AS IMPORTE
            FROM   SGCD_RESERVAS r
            JOIN   SGCD_CLIENTES cl ON cl.ID_CLIENTE = r.ID_CLIENTE
            WHERE  r.ESTADO_RESERVA <> 'CANCELADA'
              AND  r.INICIO_RESERVA >= TRUNC(p_desde)
              AND  r.INICIO_RESERVA < TRUNC(p_hasta) + 1
              AND  (p_id_cliente IS NULL OR r.ID_CLIENTE = p_id_cliente)
            GROUP  BY cl.ID_CLIENTE, cl.NOMBRE_CLIENTE, cl.RUT_CLIENTE, cl.DV_CLIENTE
            ORDER  BY 4 DESC, 2;
    END clientes_por_reservas;

END SGCD_PKG_CONSULTAS;
/
