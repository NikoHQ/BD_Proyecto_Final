# Pago único por reserva

El procedimiento usa los nombres de la vista 3FN del UML. Para integrarlo,
el DDL de Oracle debe generar PAGO.ID_PAGO al insertar, admitir el estado
PAGADO y aplicar UNIQUE a PAGO.ID_RESERVA. Confirmar esos nombres y valores
con el DDL de Nico antes de compilar.

Registrar el importe acordado completo y un medio válido. El procedimiento
bloquea la reserva, rechaza cancelaciones y pagos previos, y deja el COMMIT
o ROLLBACK a quien lo llama.

Ejecutar los scripts 02 y 02b pasando como argumento el ID de una reserva de
prueba vigente, sin pago y con importe positivo.

Para probar concurrencia en Oracle, usar dos conexiones con autocommit
desactivado. Registrar el pago desde la primera sin confirmar. Intentar
registrarlo desde la segunda con el mismo ID y el mismo importe. Confirmar
la primera y verificar que la segunda devuelve -20207 y que hay un solo pago.
Repetir en otra reserva revirtiendo la primera. La segunda debe poder
registrar su pago. Usar datos desechables en ambas pruebas.
