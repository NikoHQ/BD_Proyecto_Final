# Mantenedor de torneos

El SQL complementa el alta de Nico con listado, edición y borrado. Al llevar
SGCD_PKG_TORNEOS.crear_torneo al esquema final, usar la cantidad predeterminada
de SGCD_MODALIDADES para inicializar MAX_JUGADORES_POR_EQUIPO. Permitir
configurar una cantidad entera positiva al crear el torneo. Confirmar el
contrato PHP al retirar los parámetros de recinto y descuento de la v3.

El borrador toma las columnas del UML de 19 tablas y propone nombres físicos
con SGCD_. Confirmar especialmente SGCD_INSCRIPCIONES_TORNEO,
SGCD_EQUIPOS_JUGADORES, INSCRITO y las columnas de reserva. Las claves
foráneas de reservas e inscripciones deben impedir el borrado en cascada
del historial. La programación de cancha y los cambios de nómina deben
bloquear la misma fila del torneo antes de validar y escribir.

En Oracle, probar el alta y su cantidad inicial, el listado, la edición
de un torneo vacío, el rechazo al reducir cupos o cambiar la cantidad
con equipos incompatibles, y el borrado con y sin referencias.
