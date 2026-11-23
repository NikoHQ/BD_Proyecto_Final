# Guía para el agente de integración de backend de SGCD

## Punto de partida

Integra el portal de clientes y el panel administrativo existente con Oracle v3. El portal abre en `/`. El panel PHP, AdminLTE y Bootstrap abre en `/dashboardadmin/`. Lee primero el DDL y las especificaciones de los paquetes en [04_ddl_v3.sql](../../sql/oracle/04_ddl_v3.sql) y [05_paquetes_plsql.sql](../../sql/oracle/05_paquetes_plsql.sql). Contrasta los procedimientos existentes antes de diseñar endpoints o añadir columnas. Los catálogos y las credenciales iniciales están en [06_catalogos_v3.sql](../../sql/oracle/06_catalogos_v3.sql).

Mantén la navegación, formularios, estados visibles y acciones del panel. Implementa por flujo y sustituye cada lectura y escritura ficticia por una operación real en PHP. Todos los controles del navegador sirven para dar respuesta inmediata. PHP debe aplicar permisos y reglas de negocio con las garantías transaccionales de Oracle.

## Qué leer para cada tarea

| Guía | Cuándo usarla |
| --- | --- |
| [Acceso a la demo](ACCESO_DEMO.md) | Levantar Docker, probar ambos accesos y autenticar personal y clientes de prueba. |
| [Recorrido del portal](PORTAL_CLIENTE.md) | Reproducir los flujos de reserva, revisión por recepción, duración e inscripción a torneos. |
| [Reservas web con Oracle](RESERVAS_ORACLE.md) | Implementar cuenta del cliente, disponibilidad, cotización, primera solicitud y confirmación. |
| [Inscripciones a torneos con Oracle](TORNEOS_ORACLE.md) | Migrar el tamaño del equipo, unificar programación y cupos y conectar la inscripción. |

## Dónde trabajar

| Archivo o carpeta | Responsabilidad |
| --- | --- |
| `web/index.php`, `web/cliente/index.php` y `http.php` del portal | Entrada, sesión de cliente, navegación, CSRF y respuestas. |
| `web/cliente/reservas.php`, `torneos.php` y `vistas/` | Acciones PHP de reservas y torneos y plantillas por flujo. `portal.php` contiene el marco de navegación. |
| `web/cliente/demo.php` | Cuentas, tarifas, disponibilidad y reservas simuladas. |
| `web/includes/portal-duration.php`, `portal-inbox.php` y `tournament-store.php` | Persistencia temporal de duración, solicitudes web y torneos en la instancia PHP. |
| `web/dashboardadmin/index.php` | Entrada autenticada del panel y orden de carga de scripts. |
| `web/dashboardadmin/` y `web/includes/auth.php` | Sesión de personal, perfil, contraseña y gestión de usuarios conectados a Oracle. La recuperación por preguntas queda pendiente. |
| `web/dashboardadmin/catalogo-oracle.php` | Ejemplo autenticado de consulta real del catálogo. Sólo lectura. |
| `web/assets/js/app.js` | Navegación, rutas, montaje de vistas y delegación de eventos. |
| `web/assets/js/pages/` | Agenda, reservas, clientes, pagos, recintos, tarifas y torneos, un archivo por página. |
| `web/assets/js/shared/` | Formateadores, componentes, listas y buscador global. |
| `web/assets/js/demo/fixtures.js` y `store.js` | Datos ficticios de reservas de mostrador, clientes, recintos y tarifas y su persistencia local. |
| `web/assets/js/demo/tournaments.js` y `web/dashboardadmin/tournaments-data.php` | Adaptador del panel a la programación y las inscripciones compartidas en demo. Sustituir el guardado de toda la maqueta por operaciones reales de dominio con IDs de Oracle. |
| `web/assets/css/` | Estilos base, cuenta, agenda, listados y torneos. |

Los scripts del panel son clásicos con `defer`, sin compilación. Conserva el orden definido en `index.php` si se añaden archivos. `app.js` monta el panel luego de cargar las páginas. Las páginas también contienen mutaciones y validaciones simuladas. Quitar el almacenamiento local por sí solo deja esos flujos incompletos.

## Inventario de la maqueta

| Flujo | Comportamiento local que hay que reemplazar | Integración |
| --- | --- | --- |
| Agenda | Reservas y bloques de torneo generados localmente, conflictos y métricas en memoria, vencimientos simulados y selector de fecha. | Consultar datos por fecha, recinto y cancha con una proyección común de bloques. Oracle debe decidir disponibilidad, expiración y solapes. Evitar doble reserva concurrente. |
| Reservas | IDs incrementales, clientes y canchas de demo, cancelación, confirmación, edición, borrado local y cotización en navegador. | Usar `SGCD_PKG_RESERVAS` donde corresponda. Completar edición y estados faltantes. Conservar historial y sustituir el borrado de demo por una operación de negocio trazable. |
| Solicitudes web | El portal y la bandeja de recepción comparten el estado mediante un archivo temporal. | Integrar en Reservas con Oracle y aplicar el límite temporal de la primera solicitud según [Reservas web con Oracle](RESERVAS_ORACLE.md). |
| Clientes | Fichas ficticias, altas desde reserva y capitán, normalización local y clasificación Persona/Organización. | Usar `SGCD_CLIENTES` y `SGCD_PKG_CLIENTES`. Normalizar RUT y validar unicidad. Confirmar si la clasificación de la maqueta tiene respaldo en el modelo. Ficha y cuenta son entidades distintas. |
| Pagos | Movimientos anidados en reservas, estados y saldos derivados, corrección y anulación local. | Integrar `SGCD_PAGOS`, asegurando un único origen válido entre reserva, membresía e implementos. Validar `ADMINISTRADOR` en PHP para editar o anular. Diseñar auditoría e idempotencia y recalcular saldos en transacción. |
| Recintos y canchas | Índices de arrays como claves, horarios semanales y modalidades locales, dependencias simuladas. | Usar identificadores reales, `SGCD_RECINTOS`, `SGCD_CANCHAS`, `SGCD_HORARIOS`, `SGCD_DEPORTES`, `SGCD_MODALIDADES` y sus compatibilidades. Validar cambios contra reservas y torneos. |
| Tarifas | Franjas ficticias, división local de bandas y cálculo por minutos con opción de total manual más motivo. | Cotizar y persistir en PHP/Oracle. Confirmar política de vigencia, franja y redondeo. El paquete actual consulta la franja inicial y guarda el valor por hora sin multiplicar por duración. Resolver las reservas que cruzan franjas y el término a `24:00`. Registrar responsable y motivo de ajustes manuales. |
| Torneos | Portal y administración comparten torneos, bloques y equipos de demostración en el servidor PHP. | Conectar con Oracle usando la migración del tamaño de plantilla y las transacciones descritas en [Torneos con Oracle](TORNEOS_ORACLE.md). |
| Buscador | Filtra los arrays locales por nombre, RUT, correo, ID y cancha. | Crear búsqueda con permisos, resultados acotados por tipo, filtros parametrizados e IDs reales. |
| Cuenta y recuperación | Login, logout y gestión de personal ya conectados a la sesión y a Oracle. **Olvidé mi contraseña** y el apartado de preguntas son pantallas informativas. | Diseñar recuperación mediante preguntas de seguridad sin correo. Definir persistencia, alta autenticada de respuestas, hashes, límite de intentos, errores sin enumeración y revocación de sesiones tras el cambio de clave. La entrega carece de migración de recuperación. |
| Módulos aún sin pantalla | Membresías, puntos e implementos/inventario. | Programar su integración de forma separada. Revisar sus vínculos con pagos e historial. |

Las claves de almacenamiento local de demostración son `sgcd-reservas-demo-v1`, `sgcd-demo-last-reservation`, `sgcd-catalogos-demo-v1` y `sgcd-torneos-demo-v1`. La clave de torneos sólo se lee para recuperar una copia anterior en una instancia nueva. Los demás datos de esas claves son ficticios. En el modo conectado, carga el estado desde el servidor y retira el indicador **Modo demostración** cuando la pantalla ya no use esa fuente.

Las identidades de cliente de la maqueta viven en sesiones PHP. Los archivos `sgcd-portal-durations-*.json`, `sgcd-portal-inbox-*.json` y `sgcd-tournaments-*.json` son temporales y propios de la instancia PHP. En el modo conectado, lee y escribe en Oracle mediante servicios PHP. Usa los IDs de cliente de la sesión autenticada y evita importar los ejemplos al esquema real.

Si trabajas con el volumen local donde se probó la recuperación anterior, podría existir una tabla `SGCD_RECUPERACION` residual. El panel entregado no la consulta. Revisa su existencia antes de nombrar la migración definitiva.

## Orden recomendado y criterios de aceptación

1. Conserva la sesión PHP y los roles de Oracle como referencia de autorización. Responde con errores consistentes para sesión vencida, permiso, validación y conflicto. Las mutaciones deben comprobar sesión, autorización y CSRF del lado servidor.
2. Integra catálogos, clientes y tarifas. Usa IDs de Oracle en selects y DTOs. Para listas devuelve elementos, total, página y tamaño. Deja que el servidor normalice y aplique búsqueda y filtros.
3. Integra reserva web, agenda, recepción y pagos como un conjunto. Sigue el contrato de reservas para configurar la duración y retirar la condición histórica de cuenta verificada. La cotización de pantalla puede ser previa. La respuesta de la operación debe devolver precio y estado confirmados. Prueba dos reservas simultáneas para la misma cancha, cambios con abonos registrados y rechazo de pagos fuera de saldo.
4. Aplica la migración de tamaño de plantilla en un Oracle v3 de desarrollo e integra torneos. Prueba que su bloqueo de cancha se vea en Agenda, que un RUT no se pueda inscribir dos veces y que editar un equipo no consuma otro cupo.
5. Conecta recuperación por preguntas. Verifica configuración, intentos fallidos, cambio de contraseña e invalidación de sesiones. Completa los módulos fuera de la demo según el orden acordado por el equipo.
6. Valida una instalación limpia con una base de desarrollo, un administrador y un operador. Comprueba que las altas y cambios se vean en otra sesión y que un operador no pueda editar pagos invocando el endpoint directamente.

Pruebas rápidas de regresión de la maqueta desde la raíz del repositorio.

```sh
php tests/portal-cliente.php
php tests/torneos-cliente.php
```

Consulta también los flujos de [reservas](../diseno/flujo-administracion-reservas.md), [torneos](../diseno/flujo-administracion-torneos.md) y [catálogos y pagos](../diseno/flujo-catalogos-y-pagos.md).
