# Clientes, Pagos y Recintos

1. Compartir filtros, tamaño de página y selección entre las tres vistas nuevas. Reservas conserva su búsqueda y acciones.
2. Editar fichas, movimientos y recintos con los campos del esquema. Usar referencias estables para conservar el vínculo con Agenda y Reservas.
3. Simular administrador y operador. Probar edición de pagos, recálculo de saldos, borrado confirmado y protección de dependencias.
4. Comparar la maqueta con el esquema Oracle y registrar lo que falta para integrar lecturas y escrituras.

## Flujo de recintos y precios

1. Seleccionar un recinto en la tabla. Su ficha muestra el horario semanal y da acceso a la agenda y las canchas del recinto.
2. Editar apertura y cierre de cada día. Los dos campos vacíos indican cierre. El prototipo comprueba el orden y advierte si un bloque activo quedaría fuera del horario.
3. En **Administrar canchas**, agregar una instalación con tipo, estado y superficie opcional. Marcar una o más modalidades del catálogo. La cancha usa un identificador estable y sus modalidades alimentan Reservas y Torneos.
4. Abrir **Tarifas** desde la navegación o desde una cancha. Cada banda define cancha, modalidad, día, franja, vigencia, valor por hora y estado. **Dividir franja** permite fijar otra tarifa desde una hora del mismo día. Ambos tramos conservan su vigencia y el primero mantiene el precio anterior. Las bandas activas de una misma cancha, modalidad y día no pueden superponerse durante la misma vigencia.
5. En **Nueva reserva**, el precio automático prorratea por minutos y suma las bandas cubiertas. Si falta cobertura, se pide configurar la tarifa o introducir un total manual y su motivo. En edición se conserva por defecto el importe acordado. Un cambio de horario, cancha o modalidad exige cotizar otra vez. El nuevo total debe cubrir los pagos registrados.

### Hallazgos al cotejar con Oracle

- `SGCD_HORARIOS` admite una ventana por día y recinto. Un día cerrado se representa mediante la ausencia de una fila. La agenda y el cobro deben compartir la zona horaria del recinto. La maqueta usa HH:MM en formato de 24 horas y admite `24:00` sólo como fin del día. Antes de persistir ese límite, hay que adaptar las restricciones de horario y tarifa y la regla de reserva que impide terminar en el día siguiente.
- `SGCD_DEPORTES`, `SGCD_MODALIDADES` y `SGCD_CANCHAS_MODALIDADES` separan deporte, modalidad y compatibilidad. La maqueta permite elegir modalidades del catálogo de demostración y conserva las previamente asignadas. La integración deberá resolver cada modalidad a su ID y ofrecer la administración de deportes.
- `SGCD_PKG_TARIFAS.obtener_tarifa` devuelve una banda para la hora de inicio y ordena por vigencia descendente. `SGCD_PKG_RESERVAS.crear_reserva` aplica el descuento al valor por hora y guarda ese valor como importe acordado. Debe revisarse el cálculo para aplicar duración y cambios de franja, y comparar la vigencia como fecha civil para incluir todo el día de término. Hay que acordar si las vigencias solapadas se rechazan como en la maqueta o se permite prelación explícita.
- Oracle guarda el importe acordado, pero el procedimiento no recibe un precio manual ni su justificación. PHP debe comprobar el rol, recalcular o validar el total dentro de la transacción y registrar el motivo y responsable del ajuste. La cotización de torneos y su descuento requieren el mismo criterio de duración y una política de cobro propia.
- PHP y Oracle deben revalidar horario, modalidad, franjas vigentes, solapes, permisos e importe al guardar. El precio calculado en el navegador sirve para evaluar el flujo.

## Cobertura de Oracle

| Tablas | Cobertura y siguiente paso |
| --- | --- |
| `SGCD_CLIENTES` | La maqueta edita nombre, RUT/DV, correo, teléfono y estado. Persona/Organización es una clasificación local. PHP debe usar `SGCD_PKG_CLIENTES` para las operaciones disponibles y añadir edición y baja lógica con validación de unicidad. |
| `SGCD_PAGOS` | La maqueta muestra pagos de reservas y permite editar fecha, importe y medio o anular con motivo. Oracle exige un único origen entre reserva, membresía e implementos. Faltan operaciones transaccionales y auditoría de anulación. PHP debe exigir una sesión con rol `ADMINISTRADOR`. |
| `SGCD_RECINTOS`, `SGCD_CANCHAS` | Consulta conectada desde Recintos. Las ediciones son locales. Falta persistirlas con validación de agenda y dependencias. |
| `SGCD_HORARIOS`, `SGCD_DEPORTES`, `SGCD_MODALIDADES`, `SGCD_CANCHAS_MODALIDADES`, `SGCD_TARIFAS` | Hay formularios de demostración para horarios, compatibilidades y bandas. La consulta real muestra horarios, modalidades por cancha y conteo de tarifas activas. Falta conectar la edición y la cotización con PHP/Oracle. |
| `SGCD_RESERVAS` | Agenda y reservas operan con datos locales. La integración debe usar los procedimientos de creación, confirmación y cancelación y añadir edición transaccional. |
| `SGCD_TORNEOS`, `SGCD_EQUIPOS`, `SGCD_JUGADORES`, `SGCD_EQUIPO_JUGADORES` | Hay flujos de maqueta. Falta conectar los procedimientos Oracle y completar las operaciones de cambio de estado. |
| `SGCD_ADMINISTRADORES`, `SGCD_CREDENCIALES` | El acceso y la administración de personal usan sesiones PHP y roles de Oracle. Pagos toma el rol de la sesión para su interfaz. Falta autorizar cada operación de pago en el servidor cuando se conecte su persistencia. |
| `SGCD_PLANES_MEMBRESIA`, `SGCD_MEMBRESIAS`, `SGCD_MOVIMIENTOS_PUNTOS` | Falta el módulo de membresía y movimientos, junto con el vínculo de sus pagos. El saldo de puntos debe derivarse de movimientos. |
| `SGCD_ARTICULOS`, `SGCD_OPERACIONES_IMPLEMENTOS`, `SGCD_DETALLES_IMPLEMENTOS` | Falta el módulo de inventario e implementos y la integración con Pagos. Las cantidades y movimientos requieren una transacción. |

La consulta desde PHP/OCI8 encontró 2 recintos, 7 canchas, 14 horarios, 10 compatibilidades y 80 tarifas. Clientes, reservas, pagos, torneos, equipos, jugadores, sus relaciones, membresías, puntos y operaciones y detalles de implementos estaban vacíos. Las altas de demostración se guardan en el navegador. Oracle necesita datos de prueba relacionados para ejercitar estos flujos.

En las listas conectadas, PHP debe aplicar los filtros y la paginación, validar el rol contra la sesión y conservar el historial de los registros vinculados. Los IDs, importes derivados y fechas de creación se generan o validan en el servidor.
