-- =====================================================================
-- PRUEBAS DE INTEGRIDAD - SGCD
-- Ejecutar DESPUES de 01_ddl_sgcd_corregido.sql, sobre esquema vacio.
--
-- Cada prueba T-nn intenta una operacion que el DDL debe RECHAZAR.
--   OK   = rechazada con el ORA- esperado
--   FAIL = aceptada (o rechazada con otro codigo)
-- T-19 es la unica positiva: verifica que una reserva CANCELADA libera
-- el bloque para una nueva reserva (indice unico por funcion).
--
-- Al final: conteo de objetos y limpieza de los datos de prueba.
-- =====================================================================

SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET FEEDBACK OFF
SET LINESIZE 200

-- ---------------------------------------------------------------------
-- Helper
-- ---------------------------------------------------------------------
CREATE OR REPLACE PROCEDURE TEST_EXPECT (
    p_nombre   IN VARCHAR2,
    p_sql      IN VARCHAR2,
    p_sqlcode  IN NUMBER
) AS
BEGIN
    EXECUTE IMMEDIATE p_sql;
    DBMS_OUTPUT.PUT_LINE('FAIL  ' || p_nombre || '  -> paso sin error');
    ROLLBACK;
EXCEPTION
    WHEN OTHERS THEN
        IF SQLCODE = p_sqlcode THEN
            DBMS_OUTPUT.PUT_LINE('OK    ' || p_nombre || '  -> ORA-' || LPAD(ABS(SQLCODE), 5, '0'));
        ELSE
            DBMS_OUTPUT.PUT_LINE('FAIL  ' || p_nombre || '  -> esperaba ' || p_sqlcode
                                 || ', obtuvo ' || SQLCODE || ' ' || SUBSTR(SQLERRM, 1, 90));
        END IF;
END;
/

-- ---------------------------------------------------------------------
-- Datos base (deben pasar sin error)
-- ---------------------------------------------------------------------
INSERT INTO SGCD_RECINTOS (NOMBRE_RECINTO, DIRECCION_RECINTO, COMUNA_RECINTO)
VALUES ('Complejo Las Rastras', 'Av. San Miguel 1234', 'Talca');

INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (1, 'Cancha Futbol 7', 'CANCHA', 1200);

INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA)
VALUES (1, 'Piscina Temperada', 'PISCINA');

INSERT INTO SGCD_DEPORTES (NOMBRE_DEPORTE) VALUES ('Futbol');

INSERT INTO SGCD_MODALIDADES (ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (1, 'Futbol 7');

INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (1, 1);

INSERT INTO SGCD_HORARIOS (ID_RECINTO, DIA_SEMANA_HORARIO, HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO)
VALUES (1, 1, '08:00', '22:00');

INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
                          HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VALOR_HORA_TARIFA)
VALUES (1, 1, 1, '08:00', '18:00', DATE '2026-01-01', 18000);

INSERT INTO SGCD_CLIENTES (NOMBRE_CLIENTE, TELEFONO_CLIENTE, CORREO_CLIENTE)
VALUES ('Ana Soto', '+56911111111', 'ana@correo.cl');

INSERT INTO SGCD_ADMINISTRADORES (NOMBRE_ADMINISTRADOR, USUARIO_ADMINISTRADOR, CLAVE_HASH_ADMINISTRADOR)
VALUES ('Niko', 'niko', 'pbkdf2$hash$de$prueba');

INSERT INTO SGCD_PLANES_MEMBRESIA (NOMBRE_PLAN, DURACION_DIAS_PLAN, DESCUENTO_PORCENTAJE_PLAN)
VALUES ('Mensual', 30, 10);

INSERT INTO SGCD_MEMBRESIAS (ID_CLIENTE, ID_PLAN, FECHA_INICIO_MEMBRESIA, FECHA_TERMINO_MEMBRESIA)
VALUES (1, 1, DATE '2026-11-01', DATE '2026-12-01');

INSERT INTO SGCD_ARTICULOS (NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
                            EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES ('Balon Futbol 5', 10, 4, 25000, 3000);

INSERT INTO SGCD_OPERACIONES_IMPLEMENTOS (ID_CLIENTE, TIPO_OPERACION, IMPORTE_TOTAL_OPERACION)
VALUES (1, 'ARRIENDO', 3000);

INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_ADMINISTRADOR, ID_CANCHA, ID_MODALIDAD,
                           INICIO_RESERVA, TERMINO_RESERVA, IMPORTE_ACORDADO_RESERVA, ESTADO_RESERVA)
VALUES (1, 1, 1, 1, TIMESTAMP '2026-12-01 10:00:00', TIMESTAMP '2026-12-01 11:00:00', 18000, 'CONFIRMADA');

COMMIT;

-- ---------------------------------------------------------------------
-- Pruebas negativas
-- ---------------------------------------------------------------------
BEGIN
    TEST_EXPECT('T-01 PAGO con dos origenes (XOR)',
        q'[INSERT INTO SGCD_PAGOS (ID_RESERVA, ID_OPERACION, IMPORTE_PAGO, MEDIO_PAGO)
           VALUES (1, 1, 1000, 'EFECTIVO')]', -2290);

    TEST_EXPECT('T-02 PAGO sin ningun origen (XOR)',
        q'[INSERT INTO SGCD_PAGOS (IMPORTE_PAGO, MEDIO_PAGO)
           VALUES (1000, 'EFECTIVO')]', -2290);

    TEST_EXPECT('T-03 PAGO con medio invalido',
        q'[INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO)
           VALUES (1, 1000, 'BITCOIN')]', -2290);

    TEST_EXPECT('T-04 PAGO con importe negativo',
        q'[INSERT INTO SGCD_PAGOS (ID_RESERVA, IMPORTE_PAGO, MEDIO_PAGO)
           VALUES (1, -500, 'EFECTIVO')]', -2290);

    TEST_EXPECT('T-05 HORARIO hora con formato invalido',
        q'[INSERT INTO SGCD_HORARIOS (ID_RECINTO, DIA_SEMANA_HORARIO, HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO)
           VALUES (1, 2, '99:99', '22:00')]', -2290);

    TEST_EXPECT('T-06 HORARIO apertura posterior al cierre',
        q'[INSERT INTO SGCD_HORARIOS (ID_RECINTO, DIA_SEMANA_HORARIO, HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO)
           VALUES (1, 3, '20:00', '08:00')]', -2290);

    TEST_EXPECT('T-07 HORARIO dia de semana fuera de 1..7',
        q'[INSERT INTO SGCD_HORARIOS (ID_RECINTO, DIA_SEMANA_HORARIO, HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO)
           VALUES (1, 9, '08:00', '12:00')]', -2290);

    TEST_EXPECT('T-08 TARIFA con valor cero',
        q'[INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
                                     HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VALOR_HORA_TARIFA)
           VALUES (1, 1, 2, '08:00', '12:00', DATE '2026-01-01', 0)]', -2290);

    TEST_EXPECT('T-09 TARIFA duplicada (misma banda y vigencia)',
        q'[INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
                                     HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VALOR_HORA_TARIFA)
           VALUES (1, 1, 1, '08:00', '18:00', DATE '2026-01-01', 20000)]', -1);

    TEST_EXPECT('T-10 TARIFA con vigencia invertida',
        q'[INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
                                     HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VIGENTE_HASTA_TARIFA, VALOR_HORA_TARIFA)
           VALUES (1, 1, 3, '08:00', '12:00', DATE '2026-06-01', DATE '2026-01-01', 10000)]', -2290);

    TEST_EXPECT('T-11 RESERVA con termino anterior al inicio',
        q'[INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                      IMPORTE_ACORDADO_RESERVA)
           VALUES (1, 1, 1, TIMESTAMP '2026-12-02 11:00:00', TIMESTAMP '2026-12-02 10:00:00', 18000)]', -2290);

    TEST_EXPECT('T-12 RESERVA con estado inexistente',
        q'[INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                      IMPORTE_ACORDADO_RESERVA, ESTADO_RESERVA)
           VALUES (1, 1, 1, TIMESTAMP '2026-12-03 10:00:00', TIMESTAMP '2026-12-03 11:00:00', 18000, 'RESERVADA')]', -2290);

    TEST_EXPECT('T-13 RESERVA de modalidad que la cancha no ofrece (FK compuesta)',
        q'[INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                      IMPORTE_ACORDADO_RESERVA)
           VALUES (1, 2, 1, TIMESTAMP '2026-12-04 10:00:00', TIMESTAMP '2026-12-04 11:00:00', 18000)]', -2291);

    TEST_EXPECT('T-14 RESERVA duplicada en el mismo bloque de cancha',
        q'[INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD, INICIO_RESERVA, TERMINO_RESERVA,
                                      IMPORTE_ACORDADO_RESERVA)
           VALUES (1, 1, 1, TIMESTAMP '2026-12-01 10:00:00', TIMESTAMP '2026-12-01 11:00:00', 18000)]', -1);

    TEST_EXPECT('T-15 CANCHA con superficie negativa',
        q'[INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
           VALUES (1, 'Cancha Fantasma', 'CANCHA', -5)]', -2290);

    TEST_EXPECT('T-16 CANCHA con tipo inexistente',
        q'[INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA)
           VALUES (1, 'Cancha Rara', 'ESTADIO')]', -2290);

    TEST_EXPECT('T-17 CANCHA sin nombre (NOT NULL)',
        q'[INSERT INTO SGCD_CANCHAS (ID_RECINTO, NOMBRE_CANCHA) VALUES (1, NULL)]', -1400);

    TEST_EXPECT('T-18 MEMBRESIA con termino anterior al inicio',
        q'[INSERT INTO SGCD_MEMBRESIAS (ID_CLIENTE, ID_PLAN, FECHA_INICIO_MEMBRESIA, FECHA_TERMINO_MEMBRESIA)
           VALUES (1, 1, DATE '2026-12-01', DATE '2026-11-01')]', -2290);

    TEST_EXPECT('T-19 PLAN con descuento mayor a 100',
        q'[INSERT INTO SGCD_PLANES_MEMBRESIA (NOMBRE_PLAN, DURACION_DIAS_PLAN, DESCUENTO_PORCENTAJE_PLAN)
           VALUES ('Anual', 365, 150)]', -2290);

    TEST_EXPECT('T-20 DETALLE con cantidad cero',
        q'[INSERT INTO SGCD_DETALLES_IMPLEMENTOS (ID_OPERACION, ID_ARTICULO, CANTIDAD_DETALLE,
                                                  PRECIO_ACORDADO_DETALLE, ENTREGA_DETALLE)
           VALUES (1, 1, 0, 3000, TIMESTAMP '2026-12-01 12:00:00')]', -2290);

    TEST_EXPECT('T-21 DETALLE devuelto antes de entregado',
        q'[INSERT INTO SGCD_DETALLES_IMPLEMENTOS (ID_OPERACION, ID_ARTICULO, CANTIDAD_DETALLE,
                                                  PRECIO_ACORDADO_DETALLE, ENTREGA_DETALLE, DEVOLUCION_REAL_DETALLE)
           VALUES (1, 1, 1, 3000, TIMESTAMP '2026-12-01 12:00:00', TIMESTAMP '2026-12-01 09:00:00')]', -2290);

    TEST_EXPECT('T-22 MOVIMIENTO_PUNTOS con cantidad cero',
        q'[INSERT INTO SGCD_MOVIMIENTOS_PUNTOS (ID_CLIENTE, TIPO_MOVIMIENTO, CANTIDAD_MOVIMIENTO)
           VALUES (1, 'GANADO', 0)]', -2290);

    TEST_EXPECT('T-23 ADMINISTRADOR con perfil inexistente',
        q'[INSERT INTO SGCD_ADMINISTRADORES (NOMBRE_ADMINISTRADOR, USUARIO_ADMINISTRADOR,
                                             CLAVE_HASH_ADMINISTRADOR, PERFIL_ADMINISTRADOR)
           VALUES ('X', 'x', 'hash', 'SUPERUSER')]', -2290);

    TEST_EXPECT('T-24 MODALIDAD duplicada para el mismo deporte',
        q'[INSERT INTO SGCD_MODALIDADES (ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (1, 'Futbol 7')]', -1);
END;
/

-- ---------------------------------------------------------------------
-- T-25 (positiva): una reserva CANCELADA libera el bloque
-- ---------------------------------------------------------------------
UPDATE SGCD_RESERVAS SET ESTADO_RESERVA = 'CANCELADA' WHERE ID_RESERVA = 1;

INSERT INTO SGCD_RESERVAS (ID_CLIENTE, ID_CANCHA, ID_MODALIDAD,
                           INICIO_RESERVA, TERMINO_RESERVA, IMPORTE_ACORDADO_RESERVA)
VALUES (1, 1, 1, TIMESTAMP '2026-12-01 10:00:00', TIMESTAMP '2026-12-01 11:00:00', 18000);

DECLARE
    v_n NUMBER;
BEGIN
    SELECT COUNT(*) INTO v_n
      FROM SGCD_RESERVAS
     WHERE ID_CANCHA = 1 AND INICIO_RESERVA = TIMESTAMP '2026-12-01 10:00:00';
    IF v_n = 2 THEN
        DBMS_OUTPUT.PUT_LINE('OK    T-25 reserva cancelada libera el bloque  -> 2 filas, 1 vigente');
    ELSE
        DBMS_OUTPUT.PUT_LINE('FAIL  T-25 reserva cancelada libera el bloque  -> filas=' || v_n);
    END IF;
END;
/

-- ---------------------------------------------------------------------
-- T-26 (positiva): PK autogenerada por IDENTITY
-- ---------------------------------------------------------------------
DECLARE
    v_id NUMBER;
BEGIN
    INSERT INTO SGCD_PAGOS (ID_MEMBRESIA, IMPORTE_PAGO, MEDIO_PAGO)
    VALUES (1, 19990, 'DEBITO')
    RETURNING ID_PAGO INTO v_id;
    DBMS_OUTPUT.PUT_LINE('OK    T-26 IDENTITY entrega PK automatica      -> ID_PAGO=' || v_id);
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('FAIL  T-26 IDENTITY -> ' || SQLERRM);
END;
/

-- ---------------------------------------------------------------------
-- Resumen de objetos
-- ---------------------------------------------------------------------
PROMPT
PROMPT ===== OBJETOS CREADOS =====
SELECT 'TABLAS' AS concepto, COUNT(*) AS total FROM user_tables
UNION ALL
SELECT 'INDICES', COUNT(*) FROM user_indexes WHERE index_name LIKE 'IX_SGCD%' OR index_name LIKE 'UX_SGCD%'
UNION ALL
SELECT 'CHECK', COUNT(*) FROM user_constraints WHERE constraint_type = 'C' AND table_name LIKE 'SGCD%'
UNION ALL
SELECT 'FK', COUNT(*) FROM user_constraints WHERE constraint_type = 'R' AND table_name LIKE 'SGCD%'
UNION ALL
SELECT 'UNIQUE', COUNT(*) FROM user_constraints WHERE constraint_type = 'U' AND table_name LIKE 'SGCD%';

-- ---------------------------------------------------------------------
-- Limpieza de datos de prueba (deja el esquema vacio)
-- ---------------------------------------------------------------------
DELETE FROM SGCD_PAGOS;
DELETE FROM SGCD_DETALLES_IMPLEMENTOS;
DELETE FROM SGCD_RESERVAS;
DELETE FROM SGCD_OPERACIONES_IMPLEMENTOS;
DELETE FROM SGCD_MOVIMIENTOS_PUNTOS;
DELETE FROM SGCD_MEMBRESIAS;
DELETE FROM SGCD_TARIFAS;
DELETE FROM SGCD_CANCHAS_MODALIDADES;
DELETE FROM SGCD_HORARIOS;
DELETE FROM SGCD_CANCHAS;
DELETE FROM SGCD_MODALIDADES;
DELETE FROM SGCD_DEPORTES;
DELETE FROM SGCD_PLANES_MEMBRESIA;
DELETE FROM SGCD_ADMINISTRADORES;
DELETE FROM SGCD_ARTICULOS;
DELETE FROM SGCD_CLIENTES;
DELETE FROM SGCD_RECINTOS;
COMMIT;

DROP PROCEDURE TEST_EXPECT;

PROMPT
PROMPT ===== FIN DE PRUEBAS =====
EXIT
