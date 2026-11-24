# Mantenedor de bloques horarios

El archivo 01 instala las cuatro operaciones CRUD y la validación
compartida por el alta y la edición. El listado devuelve un cursor ordenado
por hora. Para mover un bloque a otro horario, administrarlo en la plantilla
del día correspondiente. Las reservas conservan sus fechas guardadas.

El SQL utiliza SGCD_HORARIOS con las columnas de apertura y cierre de la v3
local de Nico. Para SGCD_BLOQUES_HORARIOS utiliza el prefijo SGCD_ y las
columnas del UML. Confirmar esos nombres en el DDL final. El esquema genera
el ID del bloque y el procedimiento lo devuelve con RETURNING. La aplicación
controla la transacción.

Para probar, ejecutar 01 y luego 02 en Oracle de pruebas, pasando como
argumento el ID de un horario sin bloques que cubra de 18:00 a 20:00.
La prueba comprueba las cuatro operaciones y el rechazo de solapamientos.
