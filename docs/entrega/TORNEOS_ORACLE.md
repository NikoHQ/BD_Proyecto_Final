# Integración Oracle de torneos y plantillas

El portal y el panel administrativo comparten programación, cupos e inscripciones en la demo. El contrato de esta guía apunta al [UML oficial de 19 tablas](../modelo/uml-equipo-19/SGCD_objetivo.puml). El [DDL v3](../../sql/oracle/04_ddl_v3.sql) y los [paquetes v3](../../sql/oracle/05_paquetes_plsql.sql) sirven como referencia de transición.

## Datos del UML objetivo

| Dato de la interfaz | Origen y regla |
| --- | --- |
| Torneo | `TORNEO` guarda modalidad, nombre, fecha de inicio y término, estado, `CUPOS_TORNEO` y `MAX_JUGADORES_POR_EQUIPO`. Al crear, copiar el máximo inicial de `MODALIDAD.MAX_JUGADORES_POR_EQUIPO`. El administrador puede ajustarlo por torneo siempre que ninguna plantilla activa supere el nuevo máximo. En la demo se ajusta mientras el torneo está planificado. |
| Programación | Cada bloque corresponde a una `RESERVA` vinculada mediante `ID_TORNEO`. Se obtiene el recinto desde `RESERVA.ID_CANCHA → CANCHA.ID_RECINTO`. El selector de recinto del panel ayuda a elegir canchas compatibles. El UML guarda los recintos por bloque y el portal conectado debe mostrarlos aunque un torneo tenga más de uno. El bloque de torneo puede prescindir de cliente. |
| Inscripción | `INSCRIPCION_TORNEO` guarda `ID_TORNEO`, `ID_CLIENTE` del responsable, `NOMBRE_EQUIPO`, `CANTIDAD_JUGADORES`, `FECHA_INSCRIPCION` y `ESTADO_INSCRIPCION`. Cada inscripción activa ocupa un cupo de equipo. Una plantilla válida contiene desde un jugador hasta el máximo del torneo, incluido siempre el capitán. |
| Jugadores | `JUGADOR` guarda nombre, RUT y DV. Validar y normalizar el dígito a 0–9 o K, y aplicar unicidad a `(RUT_JUGADOR, DV_JUGADOR)`. Si hay una ficha `CLIENTE` con ese RUT, vincular de forma opcional y única mediante `JUGADOR.ID_CLIENTE`. Cada miembro corresponde a un vínculo `EQUIPO_JUGADOR(ID_INSCRIPCION, ID_JUGADOR)`. |
| Cuenta | Inscribir desde el portal con un `USUARIO` activo de rol cliente y su ficha `CLIENTE` activa. Obtener el capitán de esa sesión. El personal autenticado puede seleccionar una ficha activa desde administración. Los compañeros sólo requieren nombre completo y RUT. |

La demo ofrece Fútbol 6 con máximo inicial 10, Pádel dobles con 2 y Tenis con 1. El número representa el límite del plantel total. El equipo puede tener menos integrantes. `CANTIDAD_JUGADORES` registra los vínculos reales que resultan del guardado.

## Contrato PHP

| Operación | Entrada y resultado |
| --- | --- |
| Ver torneos | Filtros de modalidad, recinto e inscripción abierta. Devuelve ID, nombre, modalidad, programación publicada, máximo, cupos, estado del torneo y estado de inscripción. |
| Mis inscripciones | Sesión de cliente e ID de inscripción para consultar un detalle. Filtrar por `INSCRIPCION_TORNEO.ID_CLIENTE`. La respuesta incluye los miembros reales, la programación y las acciones válidas. Responder igual ante un ID inexistente y uno ajeno. |
| Inscribir | POST con ID de torneo, nombre de equipo para modalidades colectivas, máximo mostrado, compañeros con nombre y RUT, y clave de idempotencia. El responsable sale de la sesión. Crear la relación del capitán y todas las relaciones de compañeros. Devolver el comprobante y el ID estable de la inscripción. Para un torneo individual, la demo asigna el nombre de inscripción a partir del titular. |
| Editar | POST con ID de inscripción, nombre y lista completa de compañeros actuales. El cliente conserva al capitán. El personal puede corregir el responsable con autorización. La inscripción conserva su ID y su cupo. |
| Retirar | POST con ID de inscripción. Conservar inscripción, plantilla e historial. Cambiar a retirado y liberar cupo y RUT para otra inscripción en ese torneo. Repetir el retiro de una inscripción propia devuelve el mismo estado. |
| Ajustar máximo | POST de personal con ID de torneo y nuevo máximo. Validar entero positivo y comprobar las plantillas activas bajo el mismo bloqueo que usa la inscripción. Las plantillas retiradas se conservan aunque excedan un nuevo máximo. |

PHP autentica y autoriza estas operaciones y valida CSRF en las mutaciones. La navegación conserva el torneo al registrar la cuenta o iniciar sesión. En el portal, mostrar campos sólo después de agregar compañeros. Cada compañero agregado requiere ambos datos. Los RUT y nombres de equipos ajenos se mantienen privados. El descuento de cancha que traía v3 queda fuera del formulario objetivo.

## Inscripción en una transacción

1. Derivar el responsable de la sesión autenticada. Normalizar y comprobar identificadores, nombres y RUT de todos los participantes, incluido el capitán. Aplicar los límites efectivos de los campos `VARCHAR2` del esquema.
2. Bloquear la fila del `TORNEO` con `SELECT ... FOR UPDATE`. Tanto web como administración deben adquirir ese bloqueo antes de cambiar cupo, programación, estado o máximo, o de escribir inscripciones y plantillas. Mantener el mismo orden de bloqueo si se requiere bloquear equipo o cancha.
3. Revisar un reintento idempotente antes de volver a contar los cupos. La misma clave y los mismos datos deben devolver el comprobante previo incluso con torneo lleno o cerrado. Asociar la clave al actor, operación y torneo y resolver su persistencia durante la integración sin añadir una entidad al UML por cuenta propia.
4. Para un alta, volver a comprobar que el torneo está planificado, cuenta con un bloque publicado y queda al menos un cupo. El portal cierra la inscripción al inicio del primer bloque vigente, en la zona `America/Santiago`. Edición y retiro del equipo propio están habilitados antes del cierre aunque todos los cupos estén ocupados. Después, el cliente conserva acceso al historial.
5. Comprobar que el equipo tiene entre 1 y `TORNEO.MAX_JUGADORES_POR_EQUIPO` participantes. Si el máximo cambió tras cargar el formulario, mostrar el valor vigente, conservar el borrador y pedir una nueva revisión. Prohibir duplicados por RUT normalizado dentro de la plantilla y en equipos activos del mismo torneo. Revisar el nombre de equipo con un criterio común en ambos paneles.
6. Reutilizar o crear `JUGADOR` por RUT y DV. Vincular a `CLIENTE` si corresponde. Conservar el nombre canónico de una ficha existente al reutilizarla. Procesar identidades de manera estable y resolver colisiones concurrentes con la fila existente.
7. Guardar la inscripción y todos sus vínculos en una sola transacción. Calcular `CANTIDAD_JUGADORES` a partir de la plantilla persistida. Ante un fallo, revertir la operación completa. La inscripción no crea reservas ni pagos. Los bloques publicados provienen de la programación del personal.

## Diferencias con Oracle v3

- `SGCD_TORNEOS` pasa a `TORNEO`, `SGCD_EQUIPOS` a `INSCRIPCION_TORNEO`, `SGCD_JUGADORES` a `JUGADOR` y `SGCD_EQUIPO_JUGADORES` a `EQUIPO_JUGADOR`. El pivote ahora referencia `ID_INSCRIPCION`. La cuenta del cliente se vincula mediante `CLIENTE.ID_USUARIO`.
- La [migración v3 de tamaño](../../sql/oracle/09_torneos_tamano_plantilla.sql) agrega `JUGADORES_POR_EQUIPO_TORNEO` al esquema legado. El objetivo usa el máximo de torneo y el número real por inscripción. Para poblar los datos existentes, contar los vínculos, comprobar que el capitán figura en la plantilla y revisar límites con administración.
- `SGCD_PKG_TORNEOS.inscribir_equipo` ya bloquea el torneo y agrega al capitán. Sus procedimientos legados se adaptan a la operación completa del modelo objetivo, incluida la comprobación de RUT en equipos activos. El guardado de un compañero por llamada queda como implementación de transición.
- El adaptador demo mantiene `teamSize` como nombre de almacenamiento del máximo. Las plantillas previas del archivo temporal PHP se conservan. Los torneos de ejemplo del catálogo renovado se siembran al iniciar un almacenamiento vacío.

## Verificación

- Probar un capitán solo en una modalidad colectiva, una plantilla en el máximo, otra que lo supere y un compañero con un dato faltante.
- Aumentar y reducir el máximo con equipos inscritos. Rechazar una reducción por debajo del equipo activo más numeroso. Conservar plantillas retiradas más grandes.
- Verificar un RUT repetido dentro del equipo y entre dos equipos activos, reintento idempotente, fallo en el último vínculo y concurrencia por el último cupo.
- Comparar cupos, integrantes y programación entre portal y panel. Confirmar edición y retiro antes del cierre e historial disponible después.
