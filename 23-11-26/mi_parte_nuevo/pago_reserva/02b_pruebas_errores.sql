-- Usar una reserva vigente sin pagos y con importe mayor que cero.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
DEFINE id_reserva = &1

DECLARE
    importe RESERVA.IMPORTE_ACORDADO%TYPE;
BEGIN
    SELECT IMPORTE_ACORDADO INTO importe
    FROM RESERVA WHERE ID_RESERVA = &id_reserva;

    BEGIN
        SGCD_REGISTRAR_PAGO_RESERVA(&id_reserva, importe / 2, 'EFECTIVO');
        RAISE_APPLICATION_ERROR(-20902, 'Se aceptó un pago parcial');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20206 THEN RAISE; END IF;
    END;
END;
/
ROLLBACK;
UNDEFINE id_reserva
