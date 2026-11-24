-- SQL Developer en modo script. Usar una reserva vigente sin pagos.
WHENEVER SQLERROR EXIT FAILURE ROLLBACK
DEFINE id_reserva = &1

DECLARE
    importe RESERVA.IMPORTE_ACORDADO%TYPE;
BEGIN
    SELECT IMPORTE_ACORDADO INTO importe
    FROM RESERVA WHERE ID_RESERVA = &id_reserva;

    SGCD_REGISTRAR_PAGO_RESERVA(&id_reserva, importe, ' transferencia ');

    IF SGCD_SALDO_RESERVA(&id_reserva) <> 0 THEN
        RAISE_APPLICATION_ERROR(-20900, 'El saldo debe quedar en cero');
    END IF;

    BEGIN
        SGCD_REGISTRAR_PAGO_RESERVA(&id_reserva, importe, 'EFECTIVO');
        RAISE_APPLICATION_ERROR(-20901, 'Se aceptó un segundo pago');
    EXCEPTION
        WHEN OTHERS THEN
            IF SQLCODE <> -20207 THEN RAISE; END IF;
    END;
END;
/
ROLLBACK;
UNDEFINE id_reserva
