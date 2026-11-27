-- =====================================================================
-- CARGA DE CATALOGOS - SGCD
-- Portado a Oracle desde el prototipo SQLite histórico.
-- Ejecutar DESPUES de 01_ddl_sgcd_corregido.sql.
--
-- Contenido: 2 recintos, 7 instalaciones, 5 deportes, 6 modalidades,
-- 10 pares cancha-modalidad, 14 horarios y 78 tarifas (21 bandas
-- expandidas por dia, igual que el prototipo).
--
-- OJO - HORARIOS: el modelo cuelga HORARIO de RECINTO, no de cancha.
-- El prototipo SQLite tenia 49 horarios (7 instalaciones x 7 dias);
-- en Oracle solo se pueden cargar 14 (2 recintos x 7 dias). Si se
-- necesita el horario por instalacion, hay que aplicar D-3.
--
-- Re-ejecutable: purga el catalogo si no hay datos transaccionales.
-- =====================================================================

SET SERVEROUTPUT ON
SET DEFINE OFF
SET SQLBLANKLINES ON
SET FEEDBACK OFF
SET LINESIZE 120

-- ---------------------------------------------------------------------
-- Guarda: no purgar si ya hay reservas o pagos
-- ---------------------------------------------------------------------
DECLARE
    v_n NUMBER;
BEGIN
    SELECT (SELECT COUNT(*) FROM SGCD_RESERVAS) + (SELECT COUNT(*) FROM SGCD_PAGOS) INTO v_n FROM dual;
    IF v_n > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Hay datos transaccionales: no se purga el catalogo');
    END IF;
END;
/

DELETE FROM SGCD_TARIFAS;
DELETE FROM SGCD_CANCHAS_MODALIDADES;
DELETE FROM SGCD_HORARIOS;
DELETE FROM SGCD_CANCHAS;
DELETE FROM SGCD_MODALIDADES;
DELETE FROM SGCD_DEPORTES;
DELETE FROM SGCD_RECINTOS;
COMMIT;

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
-- 8. Alinear los contadores IDENTITY al maximo insertado
--    (los INSERT con ID explicito no avanzan la secuencia interna)
-- ---------------------------------------------------------------------
ALTER TABLE SGCD_RECINTOS   MODIFY (ID_RECINTO   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE SGCD_CANCHAS    MODIFY (ID_CANCHA    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE SGCD_DEPORTES   MODIFY (ID_DEPORTE   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE SGCD_MODALIDADES MODIFY (ID_MODALIDAD GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE SGCD_HORARIOS   MODIFY (ID_HORARIO   GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));
ALTER TABLE SGCD_TARIFAS    MODIFY (ID_TARIFA    GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE));

-- ---------------------------------------------------------------------
-- 9. Verificacion
-- ---------------------------------------------------------------------
PROMPT
PROMPT ===== CATALOGOS CARGADOS =====
SELECT 'RECINTOS' AS tabla, COUNT(*) AS filas FROM SGCD_RECINTOS
UNION ALL SELECT 'CANCHAS',    COUNT(*) FROM SGCD_CANCHAS
UNION ALL SELECT 'DEPORTES',   COUNT(*) FROM SGCD_DEPORTES
UNION ALL SELECT 'MODALIDADES', COUNT(*) FROM SGCD_MODALIDADES
UNION ALL SELECT 'CANCHA_MOD', COUNT(*) FROM SGCD_CANCHAS_MODALIDADES
UNION ALL SELECT 'HORARIOS',   COUNT(*) FROM SGCD_HORARIOS
UNION ALL SELECT 'TARIFAS',    COUNT(*) FROM SGCD_TARIFAS;

PROMPT
PROMPT ===== TARIFAS POR INSTALACION =====
SELECT c.NOMBRE_CANCHA, d.NOMBRE_DEPORTE, m.NOMBRE_MODALIDAD,
       COUNT(t.ID_TARIFA) AS dias_tarifados,
       MIN(t.VALOR_HORA_TARIFA) AS valor_min,
       MAX(t.VALOR_HORA_TARIFA) AS valor_max
  FROM SGCD_CANCHAS c
  JOIN SGCD_CANCHAS_MODALIDADES cm ON cm.ID_CANCHA = c.ID_CANCHA
  JOIN SGCD_MODALIDADES m ON m.ID_MODALIDAD = cm.ID_MODALIDAD
  JOIN SGCD_DEPORTES d ON d.ID_DEPORTE = m.ID_DEPORTE
  LEFT JOIN SGCD_TARIFAS t ON t.ID_CANCHA = cm.ID_CANCHA AND t.ID_MODALIDAD = cm.ID_MODALIDAD
 GROUP BY c.ID_CANCHA, c.NOMBRE_CANCHA, d.NOMBRE_DEPORTE, m.NOMBRE_MODALIDAD
 ORDER BY c.ID_CANCHA, m.NOMBRE_MODALIDAD;

EXIT
