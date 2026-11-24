-- Ejecutar en una sesion de pruebas con un horario vacio que admita 18:00 a 20:00.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK

DECLARE

    id_bloque NUMBER;
    id_otro NUMBER;
    id_leido NUMBER;
    inicio VARCHAR2(5);
    termino VARCHAR2(5);
    bloques SYS_REFCURSOR;

BEGIN

    SGCD_CREAR_BLOQUE_HORARIO(&1, '18:00', '19:00', id_bloque);

    BEGIN
        SGCD_CREAR_BLOQUE_HORARIO(&1, '18:30', '19:30', id_otro);
        RAISE_APPLICATION_ERROR(-20901, 'Se aceptó un bloque solapado');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20824 THEN RAISE; END IF;
    END;

    SGCD_ACTUALIZAR_BLOQUE_HORARIO(id_bloque, '19:00', '20:00');
    SGCD_LISTAR_BLOQUES_HORARIOS(&1, bloques);
    FETCH bloques INTO id_leido, inicio, termino;
    IF bloques%NOTFOUND OR id_leido <> id_bloque
       OR inicio <> '19:00' OR termino <> '20:00' THEN
        RAISE_APPLICATION_ERROR(-20902, 'El listado no muestra el bloque editado');
    END IF;
    CLOSE bloques;

    SGCD_BORRAR_BLOQUE_HORARIO(id_bloque);
    SGCD_LISTAR_BLOQUES_HORARIOS(&1, bloques);
    FETCH bloques INTO id_leido, inicio, termino;
    IF bloques%FOUND THEN
        RAISE_APPLICATION_ERROR(-20903, 'El bloque permanece después del borrado');
    END IF;
    CLOSE bloques;
END;
/
ROLLBACK;
