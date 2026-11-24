# Aportes PL/SQL para integrar al backend

Carpeta de trabajo para adaptar y probar nuestros procedimientos antes de
integrarlos al backend de Nico. El modelo de referencia está en
[03 Tercera forma normal](../tablas/UML_objetivo.mdj).

- `pago_reserva/` contiene el registro de pagos y sus pruebas.
- `clientes_auditoria_reportes/` contiene los procedimientos de fichas,
  los triggers de auditoría, las consultas de reportes y sus pruebas.
- `mantenedor_tarifas/` contiene el mantenedor y sus pruebas.
Los SQL de referencia incluidos en el paquete vienen del esquema anterior
y requieren adaptar nombres, columnas y dependencias al DDL de 19 tablas.

| Aporte | Integración y prueba |
|---|---|
| Pago de reserva | Adaptar el registro de pago al importe acordado y a la restricción UNIQUE de PAGO.ID_RESERVA. Validar el estado de la reserva y comprobar que dos intentos de pago dejen un solo registro. |
| Auditoría de clientes | Integrar los triggers con SGCD_PKG_CLIENTES. Guardar valores anteriores y nuevos al editar, y solo anteriores al borrar. Conservar el ID histórico y verificar que un rollback revierta también la auditoría. |
| Mantenedor de tarifas | Integrar crear, editar, cambiar estado, borrar y listar con SGCD_PKG_TARIFAS. Usar los mismos criterios de cancha, modalidad, día, franja y vigencia que la consulta de tarifa vigente. |
| Reportes | Usar nuestras consultas como referencia para contrastar los tres reportes existentes en SGCD_PKG_CONSULTAS. |

En los paquetes de Nico quedan dos ajustes de integración prioritarios.
En reservas, comprobar los cruces entre la cancha grande y sus componentes
1, 2 y 3 dentro de la operación de guardado. En torneos, conservar el bloqueo
del torneo al contar cupos y guardar la inscripción con su nómina completa
en una transacción. La nómina debe tener exactamente la cantidad configurada
e incluir al responsable como capitán. Probar ambos flujos con dos sesiones
de Oracle disputando el mismo horario o el último cupo.

Orden sugerido para integrar nuestros aportes: pago, auditoría, tarifas y
comparación de reportes. Compilar y ejecutar las pruebas contra el DDL
definitivo de Nico.

## Inventario de los diez mantenedores

| Mantenedor | Base para integrar |
|---|---|
| Tarifas | SQL local en mantenedor_tarifas |
| Bloques horarios | SQL local en mantenedor_bloques_horarios |
| Deportes | SQL local en mantenedor_deportes |
| Modalidades | SQL local en mantenedor_modalidades |
| Horarios del recinto | SQL local en mantenedor_horarios |
| Cancha–modalidad | SQL local en mantenedor_cancha_modalidad |
| Canchas | SQL local en mantenedor_canchas |
| Administradores | SQL local en mantenedor_administradores |
| Clientes | Reusar SGCD_PKG_CLIENTES de Nico |
| Torneos | Reusar y adaptar el alta de Nico e integrar el SQL de mantenedor_torneos |

Confirmar los nombres del DDL final y compilar en Oracle. Canchas y
administradores usan los IDs que asigna Oracle. El alta de administrador
vincula una cuenta existente con rol ADMINISTRADOR. La edición conserva el
vínculo de cuenta y los permisos del panel deben respetar el estado de la
ficha. El DDL debe aplicar unicidad al vínculo y preservar el historial
referenciado al borrar canchas, perfiles o torneos. Probar las cuatro
operaciones con datos descartables y comprobar el rechazo al borrar una
fila en uso.
