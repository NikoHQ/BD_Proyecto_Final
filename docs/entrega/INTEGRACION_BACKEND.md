# Guía de integración de SGCD para el equipo y sus agentes de IA

**El modelo oficial es el [UML del equipo](../modelo/uml-equipo-19/UML_objetivo.mdj), vista 03 Tercera forma normal, con 19 tablas.** El [PlantUML](../modelo/uml-equipo-19/SGCD_objetivo.puml) permite revisar el mismo modelo como texto. Ambos son copias de referencia. Mantenerlos intactos y adaptar el DDL, las consultas, los paquetes, los DTO y el frontend existente a ese contrato. El [mapa de las 19 tablas](MODELO_OBJETIVO.md) explica la equivalencia con v3.

El [DDL v3](../../sql/oracle/04_ddl_v3.sql) crea 16 tablas y todavía sirve al acceso de personal y a la consulta de catálogos de la demo. Sus nombres, columnas, roles y reglas anteriores son referencias de transición. Preparar la base objetivo en un esquema de pruebas separado. El script 04 reconstruye las tablas y se usa para inicializar una base vacía de la demostración.

## Qué leer y en qué orden

| Archivo | Qué resuelve |
| --- | --- |
| [MODELO_OBJETIVO.md](MODELO_OBJETIVO.md) | Nombres, claves, cardinalidades y mapeo de las 19 tablas; criterios para adaptar SQL y datos previos. |
| [RESERVAS_ORACLE.md](RESERVAS_ORACLE.md) | Catálogo, disponibilidad, cotización, cancha grande, calendario compartido, confirmación y pago. |
| [TORNEOS_ORACLE.md](TORNEOS_ORACLE.md) | Programación, inscripción, propietario, RUT de integrantes, cupos, máximo del equipo y concurrencia. |
| [ACCESO_DEMO.md](ACCESO_DEMO.md) y [PORTAL_CLIENTE.md](PORTAL_CLIENTE.md) | Inicio local, credenciales de desarrollo y recorridos reproducibles en ambos paneles. |

Los documentos históricos de diseño y los planes describen etapas previas. Ante una discrepancia, aplicar primero el UML y las decisiones de negocio descritas aquí. Si un dato de la interfaz falta en el UML, intentar obtenerlo de relaciones existentes, derivarlo en un DTO o simplificar la pantalla. Llevar al equipo cualquier caso que requiera cambiar el modelo antes de introducir objetos persistentes.

## Entradas y ubicación del código

- `/` sirve el portal PHP y Bootstrap. `web/cliente/index.php` define rutas, sesión y CSRF. `http.php` contiene los helpers. `reservas.php` y `torneos.php` gestionan acciones, y `vistas/` contiene el HTML.
- `/dashboardadmin/` sirve el panel PHP y AdminLTE. `web/dashboardadmin/index.php` define el orden de carga de scripts clásicos con `defer`. `web/assets/js/app.js` monta las rutas por hash. Las pantallas están en `web/assets/js/pages/` y comparten filtros, formularios y componentes en `shared/`.
- `web/includes/auth.php`, `web/dashboardadmin/login.php` y `account.php` usan OCI8 y el esquema v3 del personal. `catalogo-oracle.php` es una consulta autenticada de sólo lectura a ese mismo esquema.
- `web/cliente/demo.php`, `web/includes/portal-inbox.php` y `tournament-store.php` permiten verificar los flujos antes de conectar el modelo objetivo. `web/assets/js/demo/` contiene las semillas y adaptadores del panel.

## Superficies y fuente real que debe reemplazar la demo

| Módulo | Frontend y fuente actual | Adaptación con el UML |
| --- | --- | --- |
| Recintos, horario y canchas | `pages/recintos.js`, `demo/store.js`; catálogo local y consulta v3 aparte. | Servir el recinto y sus horarios desde `RECINTO`, `HORARIO` y `BLOQUE_HORARIO`. Editar la grilla semanal en la misma operación que su ventana. Consultar deportes, modalidades, compatibilidades y composición con `DEPORTE`, `MODALIDAD`, `CANCHA`, `CANCHA_MODALIDAD` y `CANCHA_COMPONENTE`. La demo contiene un recinto, seis canchas de Fútbol 6 y la grande. Los datos de tenis y pádel son muestras provisionales. |
| Tarifas | `pages/tarifas.js`; catálogo y vista previa locales. | Usar `TARIFA` por cancha, modalidad, día, franja y vigencia. Aceptar cambios de precio dentro de un día en límites de bloque. Validar que cada bloque cotizado tenga una tarifa aplicable y devolver el importe por hora. El total histórico sale de `RESERVA.IMPORTE_ACORDADO`. |
| Portal de reservas | `cliente/reservas.php` y `cliente/demo.php`; cuenta y recibo de sesión, solicitudes web en una bandeja temporal. | Alimentar la misma búsqueda, revisión y comprobante con los IDs reales. Cada selección es uno o más bloques consecutivos de una hora, guardados como una sola `RESERVA`. El cliente autenticado puede solicitar más de un horario libre. Cada solicitud web se confirma por separado. |
| Agenda, Reservas y solicitudes web | `pages/agenda.js`, `pages/reservas.js`, `solicitudes-web.php`; mostrador local, bandeja web y torneos en fuentes temporales distintas. | Devolver una proyección de la misma tabla `RESERVA` para todo origen y para torneos. Aplicar en backend los cruces de la grande con 1–3 y la confirmación de administrador. Usar `ID_TORNEO` para los bloques de evento. Reemplazar borrados de maqueta por cancelación o por la operación acordada. Mostrar estado real y actualizar listas después de mutar. |
| Clientes y auditoría | `pages/clientes.js` y buscadores en reserva/torneo; fichas locales. | Consultar y editar `CLIENTE`, con RUT normalizado y ficha presencial sin cuenta. Aplicar auditoría transaccional en `AUDITORIA_CLIENTE` de altas, cambios y bajas definidas por backend. La columna histórica de cliente permite conservar eventos de una ficha que se retire. La auditoría se genera en Oracle, con datos de ficha y actor cuando exista. |
| Pagos | `pages/pagos.js`; registro manual simulado. | Una reserva admite cero o un `PAGO`. Usar fecha, importe, medio y estado; validar permisos e importe. Editar o anular la misma fila. La confirmación de la reserva es independiente del pago. |
| Torneos y equipos | `pages/torneos.js`, `cliente/torneos.php`, `tournaments-data.php`; snapshot PHP compartido. | Leer `TORNEO` y bloques en `RESERVA`. Crear equipo, jugador y plantilla con `INSCRIPCION_TORNEO`, `JUGADOR` y `EQUIPO_JUGADOR`. La inscripción completa consume un cupo. Cada jugador actual tiene nombre y RUT. La cantidad incluye al capitán y respeta el máximo vigente del torneo. Sustituir la escritura de todo el snapshot por operaciones por ID. |
| Sesión, registro y perfil | `cliente/index.php`, `includes/auth.php` y `dashboardadmin/account.php`; login real de personal v3 y cliente de demo. | Autenticar en `USUARIO` y resolver el mismo perfil activo por `CLIENTE.ID_USUARIO` o `ADMINISTRADOR.ID_USUARIO`. El alta web habilita sesionar, consultar reservas propias e inscribirse. Los administradores tienen el mismo perfil de autorización en el objetivo; el operador de v3 es de transición. |
| Recuperación de cuenta | Panel de personal con aviso informativo. | Acordar la recuperación por preguntas como entrega separada. El UML oficial carece de campos de preguntas o respuestas. Mantener el flujo informativo mientras esa decisión siga pendiente. |
| Buscador y métricas | `shared/search.js` y vistas de listados; consultas locales. | Usar permisos y límites del servidor. Buscar por ID, RUT, nombre y cancha según el módulo. Calcular totales a partir de la consulta filtrada, con APIs de lista y detalle. La interfaz recibe los resultados del alcance autorizado. |

## Contratos comunes para PHP y la interfaz

- Transportar IDs de Oracle como identificadores estables. Los índices de arrays, los alias de canchas, los RUT ficticios y los códigos de ejemplo existen sólo en la demo. Los códigos de presentación pueden derivarse del ID.
- Las listas consumen filtros explícitos y devuelven elementos, total, página y tamaño. Usar orden estable e imponer un máximo por consulta. En detalle devolver los campos visibles y acciones permitidas según estado y actor. El selector de fichas por nombre/RUT tiene un resultado acotado.
- Las mutaciones comprueban sesión, rol o propiedad y CSRF en PHP. Obtener usuario, cliente y administrador de la sesión. Usar binds, una conexión Oracle por transacción y rollback si falla un paso. Los controles JavaScript permiten revisar el formulario antes de enviarlo.
- Preservar fecha local, formato de 24 horas y moneda CLP en los DTO. Validar los estados de catálogo y de negocio contra el DDL definitivo. Mapear errores a códigos y mensajes accionables, con respuesta uniforme para un recurso privado inexistente o ajeno. Devolver datos actualizados tras guardar para evitar reconstituir el resultado en el navegador.
- El traslado requiere sustituir `sgcd-reservas-demo-v2` y `sgcd-catalogos-demo-v2` de localStorage, los torneos y las solicitudes temporales de PHP, y las cuentas de cliente en sesión de demostración. La clave `sgcd-torneos-demo-v1` permite recuperar una copia de prueba anterior. Conservar preferencias de presentación locales si siguen siendo útiles. Poblar la base objetivo desde las fuentes autorizadas del equipo.
- La demo verifica conflictos entre solicitudes web bajo su propio bloqueo y lee la programación de torneos disponible. Los cambios del catálogo y las reservas de mostrador viven en el navegador. La consistencia concurrente entre mostrador, web y torneo forma parte de la integración Oracle.

## Orden para conectar y criterio de cierre

1. **Modelo y sesión.** Verificar las 19 tablas y sus claves. Adaptar login, alta y perfil con las FK de `USUARIO`. Comprobar cierre de sesión, permisos y propiedad con dos cuentas distintas.
2. **Catálogos y fichas.** Entregar IDs y compatibilidades. Validar bloques editables, la grande y las canchas 1–3, franjas, buscadores y auditoría de clientes.
3. **Calendario y caja.** Usar una consulta común para agenda/reservas; probar una hora, varias consecutivas y solapes simultáneos de la cancha grande. Confirmar cada reserva web por separado. Verificar un pago por reserva y la conservación del precio pactado.
4. **Torneos.** Integrar creación, programación, inscripción y administración del plantel. Probar registro de 1 al máximo, duplicados por RUT, cupos en dos sesiones, vínculo opcional de jugador con cliente y retiro sin borrar historial.
5. **Prueba integral.** Repetir los recorridos en ambas interfaces, desde diferentes sesiones y tras recargar. Retirar el aviso de demo por módulo cuando lecturas y escrituras usen el backend real. Revisar logs y discrepancias de Oracle antes de cerrar la integración.

Pruebas PHP de la maqueta desde la raíz del repositorio.

```sh
php tests/portal-cliente.php
php tests/torneos-cliente.php
```

## Encargo para el agente de backend

> Usa `docs/modelo/uml-equipo-19/UML_objetivo.mdj`, vista 03 Tercera forma normal, como fuente de verdad de las 19 tablas. Conserva el UML. Lee este documento y el mapa `MODELO_OBJETIVO.md`. Compara el DDL y PL/SQL actuales con el modelo y prepara sus cambios en un esquema aislado. Sustituye las fuentes de demostración por operaciones PHP/Oracle siguiendo los contratos de reservas y torneos. Si la interfaz necesita un dato que no está modelado, mapea las relaciones, derívalo o adapta la pantalla. Entrega los cambios con pruebas de ambos paneles, autorización, concurrencia y trazabilidad.
