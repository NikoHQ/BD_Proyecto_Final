# Integración Oracle de inscripciones a torneos

El portal público y el panel de personal deben leer la misma programación, cupos y plantillas. Este documento define el contrato que sustituye al almacenamiento de la demo. [Plan del flujo de clientes](../superpowers/plans/2026-11-22-inscripcion-torneos-cliente.md) · [DDL v3](../../sql/oracle/04_ddl_v3.sql) · [Paquetes v3](../../sql/oracle/05_paquetes_plsql.sql)

## Migración del tamaño del equipo

1. Aplicar [09_torneos_tamano_plantilla.sql](../../sql/oracle/09_torneos_tamano_plantilla.sql) una sola vez como propietario de las tablas v3. Para una instalación nueva, aplicarla después de cargar v3. El DDL tiene commit implícito en Oracle y se ejecuta en una sesión sin escrituras pendientes.
2. Revisar los torneos con `JUGADORES_POR_EQUIPO_TORNEO IS NULL`. Confirmar el tamaño con la administración. En torneos con equipos activos, comparar todas las plantillas contando también al capitán. Si tienen tamaños distintos o falta el capitán, resolver los registros antes de habilitar cambios o nuevas altas. Conservar visibles las inscripciones existentes.
3. Extender la creación/configuración administrativa para escribir un entero de 1 a 50. La aplicación debe exigirlo para torneos nuevos. Un torneo legado con tamaño pendiente de configurar tiene inscripciones cerradas. Un torneo con equipos inscritos conserva el tamaño definido hasta que ya no tenga inscripciones activas.

La migración agrega una columna nullable con restricción de rango entero. Las filas y los paquetes v3 se conservan. El relleno se realiza por decisión administrativa, ya que el tamaño configurado no se puede deducir de forma fiable de la modalidad ni de un equipo existente.

## Contrato PHP

| Operación | Entrada y respuesta |
| --- | --- |
| Listado y detalle público | Filtros de modalidad, recinto e inscripción abierta, e ID de torneo en el detalle. Devuelve ID, nombre, modalidad, recinto, fechas, bloques publicados, tamaño, cupos totales y ocupados, estado del torneo y disponibilidad de inscripción. |
| Mis inscripciones y detalle | Sesión de cliente y, para detalle, ID de inscripción. Devuelve identificador de equipo, torneo, fechas, estado, plantilla y acciones disponibles. Filtrar siempre por `SGCD_EQUIPOS.ID_CLIENTE_RESPONSABLE`. Para un ID inexistente o ajeno, devolver el mismo resultado de no encontrado. |
| Inscribir equipo | POST con ID de torneo, nombre de equipo cuando sea colectivo, tamaño mostrado, compañeros con nombre y RUT, y clave de idempotencia. El capitán sale de la sesión y la ficha del cliente. Devuelve ID de equipo, estado `INSCRITO` y el comprobante. |
| Corregir inscripción | POST con ID de torneo, ID de equipo, tamaño mostrado, nombre y lista completa de compañeros. El portal conserva al capitán. El personal usa una operación autenticada que puede actualizarlo y mantenerlo en la plantilla. Una edición conserva ID y cupo. |
| Retirar inscripción | POST con ID de torneo e ID de equipo. Cambia a `RETIRADO`, conserva jugadores e historial y libera cupo. Repetir un retiro propio ya aplicado devuelve el estado actual. |

La sesión de cliente debe corresponder a una credencial `ACTIVA` con rol `CLIENTE` y a una ficha `ACTIVO`. PHP valida CSRF en cada mutación, controla el acceso a los datos y usa bind variables. Recepción deriva del servidor su credencial y permiso, y selecciona una ficha de capitán activa. Las cuentas de compañeros, las credenciales verificadas y el historial de reservas de cancha quedan fuera de los requisitos de inscripción. Datos personales como RUT y nombre de compañeros se entregan sólo al capitán y a personal autorizado. Las validaciones por campo pueden indicar la fila con un error sin exponer nombres de otras fichas o equipos.

## Operación transaccional

La capa PHP debe invocar una única operación de inscripción completa, o ejecutar los pasos siguientes con una sola conexión OCI8 y `OCI_NO_AUTO_COMMIT`. Hacer commit al terminar y rollback ante cualquier fallo. Evitar una solicitud HTTP por cada integrante.

1. Antes de escribir, validar la sesión, el formato del ID y el RUT con módulo 11. Normalizar el DV y nombres y deduplicar la plantilla incluyendo al capitán. Validar longitud según la capacidad real de las columnas `VARCHAR2` y el juego de caracteres del esquema.
2. Bloquear la fila de `SGCD_TORNEOS` por ID con `SELECT ... FOR UPDATE`. Toda escritura que pueda afectar cupos, tamaño, horarios, estado o plantilla adquiere primero el mismo bloqueo, tanto en el portal como en recepción. Si también requiere bloquear un equipo o una cancha, hacerlo después del torneo y en orden consistente. Verificar de nuevo la operación propuesta después de adquirir el bloqueo.
3. Para un alta, consultar el registro persistente de idempotencia por torneo, tipo e ID de actor autenticado, operación y clave. Guardar junto a la clave el hash de los datos normalizados y el identificador de equipo dentro de la transacción. Una repetición con el mismo contenido recupera el recibo del alta aunque el cupo esté ahora completo o el torneo haya cerrado. Reutilizar la clave con otro contenido produce conflicto. Esta persistencia debe añadirse al conectar el backend.
4. Exigir `PLANIFICADO`, tamaño configurado y programación con al menos un bloque vigente. Obtener el inicio del primer bloque publicado, mediante el mínimo `INICIO_RESERVA` para ese torneo en `SGCD_RESERVAS`, con tipo `TORNEO` y estado distinto de `CANCELADA`. Comparar con el reloj de `America/Santiago`, incluso si el primer bloque ya pasó y hay otros futuros. Una inscripción se cierra justo al inicio de ese primer bloque. Para alta, contar equipos `INSCRITO` bajo el bloqueo y comparar con `CUPOS_EQUIPOS_TORNEO`. Edición y retiro operan sobre un equipo activo y no requieren un cupo adicional. El portal permite ambos mientras esté abierto el plazo, incluso cuando la capacidad se agotó.
5. Comprobar que el tamaño enviado coincide con el configurado y que el plantel tiene exactamente esa cantidad. Comparar cada par RUT/DV con los jugadores de equipos `INSCRITO` del mismo torneo. Al editar excluir sólo el equipo propio que se está reemplazando. Para mantener la restricción de Oracle de nombre único por torneo, incluir los equipos retirados al comprobar el nombre, comparando nombres recortados de forma consistente en PHP y Oracle. En modalidad individual generar el nombre y desambiguarlo bajo el mismo bloqueo.
6. Reutilizar o insertar `SGCD_JUGADORES` por RUT/DV. Si el jugador ya existe y tiene una nueva ficha asociable, vincularla al cliente que coincide, sin sobrescribir el nombre de una identidad existente desde una inscripción ajena. Procesar los RUT en orden estable para reducir bloqueos cruzados entre torneos. En una colisión de inserción concurrente por RUT, resolver recuperando la fila ganadora por el mismo par RUT/DV. Enlazar los jugadores mediante `SGCD_EQUIPO_JUGADORES`, con el capitán identificado por el cliente responsable al presentar la plantilla.
7. Insertar el equipo y todas sus relaciones en la misma transacción, o modificar equipo y relaciones como una unidad. Para retiro sólo cambia el estado del equipo. Los cupos y la elegibilidad de planteles se derivan de inscripciones activas. Registrar la clave de idempotencia de alta y confirmar la transacción sólo cuando todas las escrituras terminaron.

`SGCD_PKG_TORNEOS.inscribir_equipo` ya bloquea el torneo y agrega al capitán. El procedimiento original desconoce el tamaño exacto y no comprueba si ese capitán figura en otro equipo. `agregar_jugador` incluye equipos retirados en la consulta de duplicados y se puede llamar de forma independiente. La conexión de los dos paneles requiere centralizar esas rutas en el contrato completo y aplicar el mismo bloqueo a las operaciones administrativas de programación y cancelación.

## Errores y verificación

- Devolver errores de validación por campo o fila para tamaño, RUT y nombre. Usar conflicto cuando se agote el cupo, cambie el tamaño, cierre la inscripción o un RUT ya ocupe un lugar en otro equipo activo. PHP transforma las excepciones de Oracle en mensajes de la aplicación sin enviar detalles SQL al navegador.
- Repetir una inscripción válida con la misma clave y separar ese caso del intento de reenviar con datos distintos. Simular una respuesta perdida después del commit.
- Hacer competir dos conexiones de Oracle por el último cupo y por el mismo RUT. Probar una de las conexiones como personal y la otra como cliente. Provocar el fallo de un último integrante y comprobar que no queda el equipo ni se consume cupo.
- Probar edición de equipo con capacidad completa, retiro que libera el cupo y nueva inscripción de un RUT liberado. Comprobar que las mismas operaciones sobre un ID ajeno se rechazan.
- Comprobar que el portal y el panel muestran el mismo cupo y que una inscripción no añade bloques de cancha, reservas ni cargos.
