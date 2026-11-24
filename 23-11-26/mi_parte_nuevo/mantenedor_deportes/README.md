# Mantenedor de deportes

El DDL integrado debe generar el ID y proteger las referencias
con claves foráneas que impidan borrar catálogos en uso.

Prueba en Oracle con datos desechables: crear un registro, listar y
comprobar su ID, editar nombre y estado, consultar el cambio y borrar.
Repetir el borrado con un registro referenciado para comprobar el rechazo.
