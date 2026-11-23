# Conectar las reservas web con PHP y Oracle

El recorrido público va desde la disponibilidad hasta el comprobante. Recepción recibe y confirma la solicitud. Ambos paneles deben usar el calendario de `SGCD_RESERVAS`. La [guía general](INTEGRACION_BACKEND.md) indica cómo arrancar y qué partes del panel usan datos de demo.

## Puntos de conexión

| Operación | Entrada actual en PHP | Contrato para el servicio real |
| --- | --- | --- |
| Catálogo y duración | `web/cliente/vistas/buscar.php`, `web/includes/portal-duration.php` y `web/dashboardadmin/duraciones.php` | Devolver IDs y nombres activos de recintos y modalidades, canchas compatibles y la duración configurada por modalidad. Guardar la duración en Oracle mediante una operación exclusiva de `ADMINISTRADOR`. |
| Disponibilidad | `DemoPortal::availability()` y `handleReservationAction()` | Consulta por ID de modalidad, fecha local y recinto opcional. Devolver ID de cancha y recinto, fecha, inicio, término, duración y total CLP por alternativa. Ocultar datos de reservas ajenas. |
| Cotización y revisión | `DemoPortal::quote()` y `refreshSelection()` | Revalidar el bloque al elegirlo, volver del acceso y enviar. Derivar fecha, inicio, fin, duración y precio en el servidor. Informar los cambios antes de pedir nueva aceptación. |
| Cuenta de cliente | `web/cliente/index.php` y `DemoPortal::login()` / `register()` | Sustituir cuentas de sesión por credencial activa con rol `CLIENTE` y su ficha activa. Normalizar y validar RUT, vincular altas con la ficha correcta y evitar duplicados. Usar el ID del cliente de la sesión y no aceptar ese ID del formulario. |
| Enviar solicitud | `DemoPortal::create()` y acción `send` de `web/cliente/reservas.php` | Crear reserva normal de origen `WEB`, estado `PENDIENTE`. Recibir cancha, modalidad, inicio, cotización aceptada y clave de idempotencia. Devolver código estable, horario acordado, total y estado. |
| Comprobante e historial | `DemoPortal::receipt()`, `history()`, `detail()` y `web/cliente/vistas/reservas.php` | Entregar los datos propios desde que existe la reserva. Devolver estados `PENDIENTE`, `CONFIRMADA`, `COMPLETADA` y `CANCELADA`. Indicar si el cliente puede cancelar. Un ID ajeno debe dar el mismo resultado que uno inexistente. |
| Confirmar o cancelar | `web/dashboardadmin/solicitudes-web.php`, `web/includes/portal-inbox.php` y acción `cancel` de `web/cliente/reservas.php` | Usar `SGCD_PKG_RESERVAS.confirmar_reserva` y `cancelar_reserva` donde corresponda. Validar rol de personal o propiedad y estado de la reserva. La cancelación del cliente sólo está disponible para un bloque futuro. Integrar las solicitudes web al listado normal de Reservas. |

## Reglas que Oracle y PHP deben aplicar

1. **Duración administrada.** El catálogo v3 no guarda la duración de reserva por modalidad. Acordar y aplicar una migración incremental para persistirla. La demo usa 60 minutos inicialmente y opciones de 30 a 180 minutos en tramos de 30. La interfaz del cliente muestra la duración. PHP la aplica al generar horarios y cotizar. Las reservas ya guardadas conservan el inicio y término acordados.
2. **Calendario y tarifa.** Cruzar `SGCD_RECINTOS`, `SGCD_HORARIOS`, `SGCD_CANCHAS_MODALIDADES`, el catálogo activo y los bloques de `SGCD_RESERVAS`. Los bloques pendientes y confirmados ocupan el intervalo, incluidos los de torneo. Incluir mantenciones cuando tengan respaldo en el modelo. Usar intervalos de inicio inclusivo y término exclusivo. Definir el tratamiento de `24:00` como medianoche del día siguiente y usar `America/Santiago` en ida y vuelta. El paquete actual toma el valor por hora correspondiente al inicio. Extender la cotización a todas las franjas cubiertas y persistir el total acordado en `IMPORTE_ACORDADO_RESERVA`. Probar vigencia, tramo nocturno y redondeo en CLP.
3. **Primera solicitud.** Una cuenta nueva puede acceder a **Mis reservas** al iniciar sesión. Antes de su primera confirmación por recepción, puede tener una solicitud web pendiente. Cancelarla antes de la confirmación permite un reemplazo. Una confirmación exitosa desbloquea nuevas solicitudes, incluso si la reserva confirmada se cancela después. Persistir la primera confirmación o el evento de confirmación de forma durable. Coordinar alta, confirmación y cancelación con un bloqueo común por cliente y un orden de bloqueos consistente con el bloqueo de cancha de `crear_reserva`.
4. **Atomicidad e idempotencia.** Validar sesión y CSRF, derivar el cliente de la credencial y comprobar permisos en PHP. En una transacción, resolver primero un reintento por cliente y clave. Para una operación nueva, revalidar la primera solicitud, la duración, el precio y la disponibilidad bajo los bloqueos que correspondan. Escribir la reserva y el registro de idempotencia en la misma transacción. Distinguir los reintentos con el mismo contenido de los que reutilizan la clave con otro contenido. Confirmar sólo al terminar todas las escrituras.
5. **Consulta por propiedad.** `SGCD_PKG_CONSULTAS.historial_cliente` y `estado_cuenta` llaman a `cliente_verificado`. Reemplazar esa condición en los recorridos del portal por sesión activa y propiedad del dato. Se confirma la reserva en recepción. El registro de cuenta habilita historial, comprobante e inscripción a torneos desde el acceso.

Los puntos de partida son `SGCD_PKG_AUTH`, `SGCD_PKG_RESERVAS`, `SGCD_PKG_TARIFAS` y `SGCD_PKG_CONSULTAS`. Contrastar sus firmas y transacciones en [05_paquetes_plsql.sql](../../sql/oracle/05_paquetes_plsql.sql) y las restricciones en [04_ddl_v3.sql](../../sql/oracle/04_ddl_v3.sql).

## Resultados que debe reconocer la interfaz

| Resultado | Comportamiento esperado |
| --- | --- |
| `FIRST_RESERVATION_PENDING` | Llevar a Mis reservas con el aviso de espera. |
| `SLOT_TAKEN` | Conservar filtros y volver al listado de horarios. |
| `DURATION_CHANGED` | Volver a elegir un horario con la configuración vigente. |
| `PRICE_CHANGED` | Devolver la cotización vigente y pedir nueva aceptación. |
| `SESSION_EXPIRED` | Pedir acceso y retomar la selección para el mismo cliente. |
| `UNAVAILABLE` | Conservar el borrador y permitir reintento con la misma clave. |

## Pruebas de aceptación

- Dos clientes solicitan la misma cancha y uno sólo logra reservar. El mismo horario se mantiene disponible en otra cancha. Probar un bloque de torneo y su cancelación.
- Dos solicitudes distintas de la misma cuenta nueva llegan simultáneamente y sólo queda una pendiente. Confirmar desde recepción, actualizar el portal y enviar otra. Probar también la ruta de reemplazo por cancelación y el caso confirmado y posteriormente cancelado.
- Repetir con la misma clave después de una respuesta perdida y recuperar el código original. Verificar historial del propio cliente y rechazo para un ID ajeno.
- Cambiar precio o duración entre revisión y envío. Comprobar la nueva cotización y que las reservas previamente guardadas conserven su horario y total.
