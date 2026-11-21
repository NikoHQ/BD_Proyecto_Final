# Flujo de administración de reservas

## Recorrido del administrador

1. **Encontrar.** Abrir Reservas y filtrar por día, ID, cliente, RUT del cliente, cancha, estado u origen. La tabla muestra un número de filas configurable (5, 10, 20 o 50), con paginación, y permite seleccionar una fila.
2. **Revisar.** El panel lateral reúne cliente, cancha, fecha, horario, modalidad, origen, importe, pago y alertas de cruce. El menú de tres puntos da acceso a las acciones de la fila.
3. **Actuar.** Confirmar pendientes sin conflicto, editar reservas pendientes o confirmadas, registrar uno o más pagos y cancelar mientras no esté completada o cancelada. Al crear o editar, el cliente se busca por nombre o RUT; si un RUT válido no tiene ficha se puede crear y seleccionar. Los bloques de torneo se administran desde Torneos.
4. **Comprobar.** Cada cambio debe devolver al listado actualizado y reflejarse en Agenda, disponibilidad y detalle.

## Reglas que aplicará PHP y Oracle

| Acción | Regla de negocio |
|---|---|
| Consultar y filtrar | PHP obtiene la lista paginada. Los filtros incluyen periodo, ID, cliente, RUT del cliente, cancha, estado y origen; recibe además el tamaño de página permitido. El navegador sólo aplica filtros de demostración. |
| Crear | `SGCD_PKG_RESERVAS.crear_reserva` exige cliente para una reserva normal, cancha y modalidad compatibles, horario del recinto, intervalo dentro del mismo día y disponibilidad. Una reserva web nace `PENDIENTE`; una de mostrador nace `CONFIRMADA`. |
| Confirmar | `confirmar_reserva` acepta exclusivamente una reserva `PENDIENTE`. PHP envía el administrador autenticado y vuelve a leer el resultado. |
| Editar | El paquete actual no expone edición. Se debe definir una operación transaccional que impida editar canceladas o completadas, valide cliente, cancha, modalidad, horario, tarifa y solapes, y conserve trazabilidad del cambio. |
| Buscar o crear cliente | PHP debe buscar por nombre o RUT, limitar las coincidencias y usar una transacción para crear la ficha sólo cuando el RUT no exista. Oracle conserva la unicidad de RUT y valida los datos requeridos. |
| Cancelar | `cancelar_reserva` bloquea la fila, rechaza canceladas o completadas y exige credencial propietaria o administrador. La cancelación libera el horario. |
| Cobrar | `SGCD_PAGOS` recibe importe y medio `EFECTIVO`, `DEBITO`, `CREDITO` o `TRANSFERENCIA`. Falta un paquete de pago que valide saldo, estado de reserva y permisos. El panel de ahora permite abonos sólo como maqueta. |
| Completar | La tabla admite `COMPLETADA`, pero falta un procedimiento de transición. Definir cuándo se puede completar y cómo se relaciona con el pago total antes de habilitarlo en PHP. |

## Estados y acciones visibles

| Estado | Acciones |
|---|---|
| Pendiente | Confirmar, editar, registrar pago, cancelar. |
| Confirmada | Editar, registrar pago, cancelar. |
| Completada | Consultar historial. |
| Cancelada | Consultar historial. |
| Bloque de torneo | Abrir el torneo que lo administra. |

La opción **Borrar de la maqueta** existe únicamente para probar el prototipo. En producción se reemplaza por cancelación o anulación trazable; no debe eliminar una reserva físicamente desde el panel.

PHP debe ejecutar todas las verificaciones y traducir los errores de Oracle en mensajes de interfaz. La maqueta sólo conserva sus cambios de reserva y pago en el navegador hasta que se recarga.
