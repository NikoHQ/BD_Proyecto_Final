# Flujo de administración de torneos

## Orden de trabajo

1. **Configurar.** Crear un torneo planificado con nombre, recinto, modalidad, fechas, cupos de equipos, jugadores por equipo (capitán incluido) y descuento opcional para la cancha. Permitir corregir la configuración antes de comprometer horarios o inscribir equipos.
2. **Programar.** Añadir bloques por fecha, cancha compatible, inicio y término. El bloque aparece en la agenda general y ocupa la cancha; dos intervalos se pueden tocar, pero no solapar. La maqueta pide al menos un bloque activo antes de habilitar la inscripción.
3. **Inscribir.** Buscar y seleccionar al capitán desde un mismo campo por RUT o nombre, con un máximo de cinco resultados. Cuando un RUT válido completo no tiene coincidencia exacta, ofrecer crear la ficha con ese RUT y seleccionarla sin perder el avance. Capturar exactamente el resto de la plantilla con nombre y RUT con DV. Un torneo individual tiene un jugador y el capitán ocupa ese lugar.
4. **Administrar.** Consultar nombres, capitanes y planteles en **Ver equipos**. Un equipo inscrito de un torneo planificado o en curso se puede editar. El editor conserva el tamaño del plantel y permite cambiar nombre, capitán e integrantes. Retirar un equipo planificado libera su cupo. Al cancelar un torneo, la maqueta libera los bloques que aún no terminan.

## Oracle y PHP

| Operación | Base disponible y trabajo de integración |
|---|---|
| Configurar | `SGCD_PKG_TORNEOS.crear_torneo` guarda recinto, modalidad, nombre, fechas, cupos (2–128) y descuento (0–100). Para guardar el tamaño exacto de la plantilla se necesita extender el DDL y el paquete. Revisar si la edición se limita a torneos sin actividad y definir su operación. |
| Programar | `arrendar_bloque` crea una fila en `SGCD_RESERVAS` mediante `SGCD_PKG_RESERVAS`. PHP comprueba política de recinto, modalidad y fechas del torneo, y Oracle resuelve horarios del recinto, disponibilidad y concurrencia. La maqueta utiliza la ventana visible de la agenda (08:00–22:00). El texto de actividad requeriría un campo si se decide persistir. |
| Elegir capitán | `SGCD_PKG_CLIENTES.buscar_ficha` / `crear_ficha`. PHP normaliza búsquedas por RUT y verifica autorización. La ficha requiere nombre y RUT con DV; teléfono y correo son opcionales. El alta reutiliza la ficha existente por RUT. La ficha es independiente de una cuenta web. |
| Inscribir | `inscribir_equipo` incorpora al capitán automáticamente; `agregar_jugador` recibe RUT, DV y nombre. PHP valida estado, plantilla completa, cupos y duplicados, incluido el capitán, con las garantías de concurrencia correspondientes. Guardar equipo y plantilla en una sola transacción y revertir todo ante un fallo. |
| Editar equipo | Falta la operación para actualizar `SGCD_EQUIPOS` y `SGCD_EQUIPO_JUGADORES` en una sola transacción. PHP debe validar permisos, estado, tamaño del plantel, capitán activo, RUT válidos y duplicados, excluyendo de la comparación el equipo que se edita. El cambio de capitán debe actualizar también su vínculo como jugador. |
| Administrar | Oracle define `PLANIFICADO`, `EN_CURSO`, `FINALIZADO`, `CANCELADO` y equipos `INSCRITO` / `RETIRADO`. Hacen falta operaciones de transición y retiro con validaciones y una política explícita de liberación de bloques, historial y pagos al cancelar. |

Toda verificación de negocio debe ejecutarse en el backend PHP con apoyo de Oracle. La maqueta guarda torneos, fichas y equipos en el navegador. Las llaves, estados y errores reales deben venir del servidor.

Llaves, fixture de resultados y clasificación requieren diseño de competición y estructura de datos propia. El alcance actual cubre la operación previa y la administración del torneo.

## Verificación del flujo

- Crear torneo y comprobar que sólo ofrece modalidades del recinto y canchas compatibles.
- Reservar un bloque, verlo en Agenda, intentar un solape y comprobar el rechazo simulado.
- Buscar capitán por nombre y RUT, crear una ficha y comprobar que queda seleccionada.
- Inscribir una plantilla de dos jugadores y otra individual. Comprobar los cupos y el detalle del equipo.
- Retirar un equipo, iniciar o finalizar un torneo y cancelar otro para comprobar las acciones y la disponibilidad de cancha.
