-- =====================================================================
-- CARGA DE CATALOGOS - SGCD v3
-- Ejecutar DESPUES de 04_ddl_v3.sql y 05_paquetes_plsql.sql.
--
-- Contenido:
--   2 recintos · 7 instalaciones · 5 deportes · 6 modalidades
--   10 pares cancha-modalidad · 14 horarios · 78 tarifas
--   3 planes de membresia · 8 articulos de implementos
--   2 administradores + 2 credenciales de personal (acceso demo)
--   2 tarifas de temporada alta (ejemplo de vigencia, desde 2026-12-01)
--
-- Los recintos son provisorios: la ubicacion real esta en discusion.
--
-- Re-ejecutable: purga el catalogo si no hay datos transaccionales.
--   Guarda: aborta si RESERVAS, PAGOS, MEMBRESIAS, OPERACIONES_IMPLEMENTOS
--   o TORNEOS tienen filas.
--
-- IDs: se insertan explicitos para que el archivo se lea y las referencias
-- sean estables. Al final se reposicionan las secuencias de las tablas
-- cargadas con ALTER SEQUENCE ... RESTART START WITH max+1, porque un INSERT
-- con ID explicito no consume la secuencia y el siguiente insert automatico
-- chocaria con la PK.
--
-- Credenciales demo, solo para laboratorio: ADMIN/admin y OPERADOR/Demo1234.
-- Los dos hashes son bcrypt y estan verificados; las cuentas de personal
-- nacen verificadas. No reutilizar estas claves fuera de este equipo.
-- =====================================================================

SET SERVEROUTPUT ON
SET DEFINE OFF
SET SQLBLANKLINES ON
SET FEEDBACK OFF
SET LINESIZE 120
WHENEVER SQLERROR EXIT FAILURE


-- ---------------------------------------------------------------------
-- 0. Guarda: no purgar el catalogo si hay datos transaccionales
-- ---------------------------------------------------------------------
DECLARE
    v_n NUMBER;
BEGIN
    SELECT (SELECT COUNT(*) FROM SGCD_RESERVAS)
         + (SELECT COUNT(*) FROM SGCD_PAGOS)
         + (SELECT COUNT(*) FROM SGCD_MEMBRESIAS)
         + (SELECT COUNT(*) FROM SGCD_OPERACIONES_IMPLEMENTOS)
         + (SELECT COUNT(*) FROM SGCD_TORNEOS)
      INTO v_n FROM dual;
    IF v_n > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Hay datos transaccionales: no se purga el catalogo');
    END IF;
END;
/

-- Purga en orden inverso de dependencia: primero el hijo, despues el padre.
DELETE FROM SGCD_CREDENCIALES;
DELETE FROM SGCD_TARIFAS;
DELETE FROM SGCD_CANCHAS_MODALIDADES;
DELETE FROM SGCD_HORARIOS;
DELETE FROM SGCD_CANCHAS;
DELETE FROM SGCD_MODALIDADES;
DELETE FROM SGCD_DEPORTES;
DELETE FROM SGCD_RECINTOS;
DELETE FROM SGCD_ARTICULOS;
DELETE FROM SGCD_PLANES_MEMBRESIA;
DELETE FROM SGCD_ADMINISTRADORES;
COMMIT;

-- ---------------------------------------------------------------------
-- 0.1 Reiniciar las secuencias a 1 antes de cargar. Las tablas acaban de
--     quedar vacias, asi que los IDs del catalogo salen continuos (1..n) y
--     las capturas no muestran huecos. Al final se reposicionan en MAX+1.
-- ---------------------------------------------------------------------
ALTER SEQUENCE SGCD_SEQ_RECINTOS            RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_CANCHAS             RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_DEPORTES            RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_MODALIDADES         RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_HORARIOS            RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_TARIFAS             RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_PLANES_MEMBRESIA    RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_ARTICULOS           RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_ADMINISTRADORES     RESTART START WITH 1;
ALTER SEQUENCE SGCD_SEQ_CREDENCIALES        RESTART START WITH 1;

-- ---------------------------------------------------------------------
-- 1. RECINTOS
-- ---------------------------------------------------------------------
INSERT INTO SGCD_RECINTOS (ID_RECINTO, NOMBRE_RECINTO, DIRECCION_RECINTO, COMUNA_RECINTO, TELEFONO_RECINTO)
VALUES (1, 'Complejo Deportivo Las Rastras', 'Av. San Miguel 1234', 'Talca', '+56712334455');

INSERT INTO SGCD_RECINTOS (ID_RECINTO, NOMBRE_RECINTO, DIRECCION_RECINTO, COMUNA_RECINTO, TELEFONO_RECINTO)
VALUES (2, 'Club Deportivo La Florida', '4 Norte 567', 'Talca', '+56712334466');

-- ---------------------------------------------------------------------
-- 2. INSTALACIONES (tabla SGCD_CANCHAS, con TIPO_CANCHA)
-- ---------------------------------------------------------------------
INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (1, 1, 'Cancha Futbol 7', 'CANCHA', 1200);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (2, 1, 'Cancha Futbol 5', 'CANCHA', 800);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (3, 1, 'Cancha Padel 1', 'CANCHA', 200);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (4, 1, 'Gimnasio Multiuso', 'GIMNASIO', 600);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (5, 2, 'Cancha Basquetbol', 'CANCHA', 420);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (6, 2, 'Cancha Voleibol', 'CANCHA', 360);

INSERT INTO SGCD_CANCHAS (ID_CANCHA, ID_RECINTO, NOMBRE_CANCHA, TIPO_CANCHA, SUPERFICIE_CANCHA)
VALUES (7, 2, 'Sala de Entrenamiento', 'SALA', 120);

-- ---------------------------------------------------------------------
-- 3. DEPORTES
-- ---------------------------------------------------------------------
INSERT INTO SGCD_DEPORTES (ID_DEPORTE, NOMBRE_DEPORTE) VALUES (1, 'Futbol');
INSERT INTO SGCD_DEPORTES (ID_DEPORTE, NOMBRE_DEPORTE) VALUES (2, 'Padel');
INSERT INTO SGCD_DEPORTES (ID_DEPORTE, NOMBRE_DEPORTE) VALUES (3, 'Basquetbol');
INSERT INTO SGCD_DEPORTES (ID_DEPORTE, NOMBRE_DEPORTE) VALUES (4, 'Voleibol');
INSERT INTO SGCD_DEPORTES (ID_DEPORTE, NOMBRE_DEPORTE) VALUES (5, 'Acondicionamiento fisico');

-- ---------------------------------------------------------------------
-- 4. MODALIDADES
-- ---------------------------------------------------------------------
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (1, 1, 'Futbol 5');
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (2, 1, 'Futbol 7');
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (3, 2, 'Padel dobles');
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (4, 3, 'Basquetbol 5x5');
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (5, 4, 'Voleibol 6x6');
INSERT INTO SGCD_MODALIDADES (ID_MODALIDAD, ID_DEPORTE, NOMBRE_MODALIDAD) VALUES (6, 5, 'Entrenamiento funcional');

-- ---------------------------------------------------------------------
-- 5. QUE MODALIDAD OFRECE CADA INSTALACION
-- ---------------------------------------------------------------------
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (1, 2);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (2, 1);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (3, 3);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (4, 1);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (4, 4);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (4, 5);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (4, 6);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (5, 4);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (6, 5);
INSERT INTO SGCD_CANCHAS_MODALIDADES (ID_CANCHA, ID_MODALIDAD) VALUES (7, 6);

-- ---------------------------------------------------------------------
-- 6. HORARIOS (por recinto: 2 x 7 = 14 filas)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_hor IS RECORD (id_recinto NUMBER, dia NUMBER, ini CHAR(5), fin CHAR(5));
    TYPE t_hors IS TABLE OF t_hor;
    h t_hors := t_hors(
        t_hor(1, 1, '07:00', '23:00'), t_hor(1, 2, '07:00', '23:00'),
        t_hor(1, 3, '07:00', '23:00'), t_hor(1, 4, '07:00', '23:00'),
        t_hor(1, 5, '07:00', '23:00'), t_hor(1, 6, '09:00', '20:00'),
        t_hor(1, 7, '09:00', '20:00'),
        t_hor(2, 1, '07:00', '22:00'), t_hor(2, 2, '07:00', '22:00'),
        t_hor(2, 3, '07:00', '22:00'), t_hor(2, 4, '07:00', '22:00'),
        t_hor(2, 5, '07:00', '22:00'), t_hor(2, 6, '09:00', '20:00'),
        t_hor(2, 7, '09:00', '20:00'));
BEGIN
    FOR i IN 1 .. h.COUNT LOOP
        INSERT INTO SGCD_HORARIOS (ID_RECINTO, DIA_SEMANA_HORARIO,
                                   HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO)
        VALUES (h(i).id_recinto, h(i).dia, h(i).ini, h(i).fin);
    END LOOP;
END;
/

-- ---------------------------------------------------------------------
-- 7. TARIFAS (21 bandas del prototipo, expandidas por dia = 78 filas)
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_banda IS RECORD (id_cancha NUMBER, id_modalidad NUMBER,
                            dia_desde NUMBER, dia_hasta NUMBER,
                            hora_desde CHAR(5), hora_hasta CHAR(5),
                            valor NUMBER);
    TYPE t_bandas IS TABLE OF t_banda;
    b t_bandas := t_bandas(
        t_banda(1, 2, 1, 5, '08:00', '18:00', 18000),
        t_banda(1, 2, 1, 5, '18:00', '23:00', 25000),
        t_banda(1, 2, 6, 7, '09:00', '20:00', 28000),
        t_banda(2, 1, 1, 5, '08:00', '18:00', 15000),
        t_banda(2, 1, 1, 5, '18:00', '23:00', 20000),
        t_banda(2, 1, 6, 7, '09:00', '20:00', 23000),
        t_banda(3, 3, 1, 5, '08:00', '23:00', 12000),
        t_banda(3, 3, 6, 7, '09:00', '20:00', 15000),
        t_banda(4, 1, 1, 5, '08:00', '23:00', 20000),
        t_banda(4, 4, 1, 5, '08:00', '23:00', 20000),
        t_banda(4, 4, 6, 7, '09:00', '20:00', 22000),
        t_banda(4, 5, 1, 5, '08:00', '23:00', 18000),
        t_banda(4, 5, 6, 7, '09:00', '20:00', 20000),
        t_banda(4, 6, 1, 5, '07:00', '22:00',  6000),
        t_banda(4, 6, 6, 7, '09:00', '14:00',  6000),
        t_banda(5, 4, 1, 5, '08:00', '22:00', 16000),
        t_banda(5, 4, 6, 7, '09:00', '20:00', 18000),
        t_banda(6, 5, 1, 5, '08:00', '22:00', 14000),
        t_banda(6, 5, 6, 7, '09:00', '20:00', 16000),
        t_banda(7, 6, 1, 5, '07:00', '22:00',  8000),
        t_banda(7, 6, 6, 7, '09:00', '14:00',  8000));
BEGIN
    FOR i IN 1 .. b.COUNT LOOP
        FOR d IN b(i).dia_desde .. b(i).dia_hasta LOOP
            INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA,
                                      HORA_DESDE_TARIFA, HORA_HASTA_TARIFA,
                                      VIGENTE_DESDE_TARIFA, VALOR_HORA_TARIFA)
            VALUES (b(i).id_cancha, b(i).id_modalidad, d,
                    b(i).hora_desde, b(i).hora_hasta, DATE '2026-01-01', b(i).valor);
        END LOOP;
    END LOOP;
END;
/

COMMIT;

-- ---------------------------------------------------------------------
-- 8. PLANES DE MEMBRESIA
-- ---------------------------------------------------------------------
INSERT INTO SGCD_PLANES_MEMBRESIA (ID_PLAN, NOMBRE_PLAN, DURACION_DIAS_PLAN, BENEFICIO_PLAN, DESCUENTO_PORCENTAJE_PLAN)
VALUES (1, 'Mensual', 30, 'Acceso a horario valle', 0);

INSERT INTO SGCD_PLANES_MEMBRESIA (ID_PLAN, NOMBRE_PLAN, DURACION_DIAS_PLAN, BENEFICIO_PLAN, DESCUENTO_PORCENTAJE_PLAN)
VALUES (2, 'Trimestral', 90, '10% de descuento en arriendos', 10);

INSERT INTO SGCD_PLANES_MEMBRESIA (ID_PLAN, NOMBRE_PLAN, DURACION_DIAS_PLAN, BENEFICIO_PLAN, DESCUENTO_PORCENTAJE_PLAN)
VALUES (3, 'Anual', 365, '15% de descuento y reserva prioritaria', 15);

-- ---------------------------------------------------------------------
-- 9. ARTICULOS DE IMPLEMENTOS (venta y/o arriendo)
-- ---------------------------------------------------------------------
INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (1, 'Balon de futbol', 15, 8, 12000, 3000);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (2, 'Peto de entrenamiento', 40, 40, 5000, 1000);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (3, 'Paleta de padel', 10, 10, 45000, 6000);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (4, 'Pelota de padel', 60, 30, 3500, 1500);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (5, 'Red de voleibol', 5, 5, 25000, 4000);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (6, 'Balon de basquetbol', 12, 6, 18000, 3000);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (7, 'Cono de entrenamiento', 50, 20, 2500, 500);

INSERT INTO SGCD_ARTICULOS (ID_ARTICULO, NOMBRE_ARTICULO, EXISTENCIAS_VENTA_ARTICULO,
    EXISTENCIAS_ARRIENDO_ARTICULO, PRECIO_VENTA_ARTICULO, PRECIO_ARRIENDO_ARTICULO)
VALUES (8, 'Silbato de arbitro', 20, 0, 3000, NULL);

-- ---------------------------------------------------------------------
-- 10. ADMINISTRADORES (personal del recinto, sin acceso: el acceso va abajo)
-- ---------------------------------------------------------------------
INSERT INTO SGCD_ADMINISTRADORES (ID_ADMINISTRADOR, NOMBRE_ADMINISTRADOR)
VALUES (1, 'Camila Rojas Fuentes');

INSERT INTO SGCD_ADMINISTRADORES (ID_ADMINISTRADOR, NOMBRE_ADMINISTRADOR)
VALUES (2, 'Diego Aravena Munoz');

-- ---------------------------------------------------------------------
-- 11. CREDENCIALES DE PERSONAL (laboratorio: ADMIN/admin, OPERADOR/Demo1234)
--     El personal nace verificado; el verificador es el propio administrador.
-- ---------------------------------------------------------------------
INSERT INTO SGCD_CREDENCIALES (ID_CREDENCIAL, LOGIN_CREDENCIAL, CLAVE_HASH_CREDENCIAL,
    ROL_CREDENCIAL, ESTADO_CREDENCIAL, ID_CLIENTE, ID_ADMINISTRADOR,
    FECHA_VERIFICACION_CREDENCIAL, ID_ADMINISTRADOR_VERIFICADOR)
VALUES (1, 'ADMIN', '$2y$12$MpPV8fTOj3Bjs9KcaNLDKOiM6WVMH1ZcnhHEAdEVjQq3fLt6wPF6y',
    'ADMINISTRADOR', 'ACTIVA', NULL, 1, SYSTIMESTAMP, 1);

INSERT INTO SGCD_CREDENCIALES (ID_CREDENCIAL, LOGIN_CREDENCIAL, CLAVE_HASH_CREDENCIAL,
    ROL_CREDENCIAL, ESTADO_CREDENCIAL, ID_CLIENTE, ID_ADMINISTRADOR,
    FECHA_VERIFICACION_CREDENCIAL, ID_ADMINISTRADOR_VERIFICADOR)
VALUES (2, 'OPERADOR', '$2y$12$K9jB5X2EHPjF9LC1fTdJdOc3SMHziE1S4gN.9hYEEn3ffnBDhzLpG',
    'OPERADOR', 'ACTIVA', NULL, 2, SYSTIMESTAMP, 1);

-- ---------------------------------------------------------------------
-- 12. TARIFA DE TEMPORADA ALTA (ejemplo de vigencia)
--     Padel dobles, fin de semana, 09:00-20:00: 15.000 -> 18.000 desde
--     el 2026-12-01. SGCD_PKG_TARIFAS toma la vigencia mas reciente que
--     aplique, asi que las reservas anteriores a esa fecha mantienen su precio.
-- ---------------------------------------------------------------------
INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
    HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VIGENTE_HASTA_TARIFA, VALOR_HORA_TARIFA)
VALUES (3, 3, 6, '09:00', '20:00', DATE '2026-12-01', NULL, 18000);

INSERT INTO SGCD_TARIFAS (ID_CANCHA, ID_MODALIDAD, DIA_SEMANA_TARIFA, HORA_DESDE_TARIFA,
    HORA_HASTA_TARIFA, VIGENTE_DESDE_TARIFA, VIGENTE_HASTA_TARIFA, VALOR_HORA_TARIFA)
VALUES (3, 3, 7, '09:00', '20:00', DATE '2026-12-01', NULL, 18000);

COMMIT;

-- ---------------------------------------------------------------------
-- 13. Reposicionar las secuencias de las tablas cargadas con ID explicito.
--     Sin esto, el primer INSERT automatico pediria 1 y chocaria con la PK.
-- ---------------------------------------------------------------------
DECLARE
    TYPE t_par IS RECORD (tabla VARCHAR2(30), columna VARCHAR2(30), secuencia VARCHAR2(40));
    TYPE t_pares IS TABLE OF t_par;
    p t_pares := t_pares(
        t_par('SGCD_RECINTOS',            'ID_RECINTO',      'SGCD_SEQ_RECINTOS'),
        t_par('SGCD_CANCHAS',             'ID_CANCHA',       'SGCD_SEQ_CANCHAS'),
        t_par('SGCD_DEPORTES',            'ID_DEPORTE',      'SGCD_SEQ_DEPORTES'),
        t_par('SGCD_MODALIDADES',         'ID_MODALIDAD',    'SGCD_SEQ_MODALIDADES'),
        t_par('SGCD_HORARIOS',            'ID_HORARIO',      'SGCD_SEQ_HORARIOS'),
        t_par('SGCD_TARIFAS',             'ID_TARIFA',       'SGCD_SEQ_TARIFAS'),
        t_par('SGCD_PLANES_MEMBRESIA',    'ID_PLAN',         'SGCD_SEQ_PLANES_MEMBRESIA'),
        t_par('SGCD_ARTICULOS',           'ID_ARTICULO',     'SGCD_SEQ_ARTICULOS'),
        t_par('SGCD_ADMINISTRADORES',     'ID_ADMINISTRADOR','SGCD_SEQ_ADMINISTRADORES'),
        t_par('SGCD_CREDENCIALES',        'ID_CREDENCIAL',   'SGCD_SEQ_CREDENCIALES'));
    v_max  NUMBER;
    v_next NUMBER;
BEGIN
    FOR i IN 1 .. p.COUNT LOOP
        EXECUTE IMMEDIATE 'SELECT NVL(MAX(' || p(i).columna || '), 0) FROM ' || p(i).tabla INTO v_max;
        v_next := v_max + 1;
        EXECUTE IMMEDIATE 'ALTER SEQUENCE ' || p(i).secuencia || ' RESTART START WITH ' || v_next;
    END LOOP;
    DBMS_OUTPUT.PUT_LINE('Secuencias reposicionadas: ' || p.COUNT);
END;
/

-- ---------------------------------------------------------------------
-- 14. Verificacion
-- ---------------------------------------------------------------------
PROMPT
PROMPT ===== CATALOGOS CARGADOS (v3) =====
SELECT 'RECINTOS' AS TABLA, COUNT(*) AS FILAS FROM SGCD_RECINTOS
UNION ALL SELECT 'CANCHAS',        COUNT(*) FROM SGCD_CANCHAS
UNION ALL SELECT 'DEPORTES',       COUNT(*) FROM SGCD_DEPORTES
UNION ALL SELECT 'MODALIDADES',    COUNT(*) FROM SGCD_MODALIDADES
UNION ALL SELECT 'CANCHA_MOD',     COUNT(*) FROM SGCD_CANCHAS_MODALIDADES
UNION ALL SELECT 'HORARIOS',       COUNT(*) FROM SGCD_HORARIOS
UNION ALL SELECT 'TARIFAS',        COUNT(*) FROM SGCD_TARIFAS
UNION ALL SELECT 'PLANES',         COUNT(*) FROM SGCD_PLANES_MEMBRESIA
UNION ALL SELECT 'ARTICULOS',      COUNT(*) FROM SGCD_ARTICULOS
UNION ALL SELECT 'ADMINISTRADORES', COUNT(*) FROM SGCD_ADMINISTRADORES
UNION ALL SELECT 'CREDENCIALES',   COUNT(*) FROM SGCD_CREDENCIALES;

PROMPT
PROMPT ===== VIGENCIA DE TARIFA (Padel fin de semana, 09:00-20:00) =====
SELECT t.DIA_SEMANA_TARIFA AS DIA, t.VIGENTE_DESDE_TARIFA AS DESDE,
       t.VALOR_HORA_TARIFA AS VALOR
  FROM SGCD_TARIFAS t
 WHERE t.ID_CANCHA = 3 AND t.ID_MODALIDAD = 3 AND t.DIA_SEMANA_TARIFA = 6
 ORDER BY t.VIGENTE_DESDE_TARIFA;

PROMPT
PROMPT ===== SIGUIENTE ID QUE ENTREGARIA CADA SECUENCIA =====
SELECT s.SEQUENCE_NAME || ' -> ' || s.LAST_NUMBER AS SIGUIENTE
  FROM ALL_SEQUENCES s
 WHERE s.SEQUENCE_OWNER = SYS_CONTEXT('USERENV', 'CURRENT_SCHEMA')
   AND s.SEQUENCE_NAME LIKE 'SGCD\_SEQ\_%' ESCAPE '\'
 ORDER BY s.SEQUENCE_NAME;
