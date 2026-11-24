# Mantenedor de horarios del recinto

El SQL instala crear, listar, editar y borrar en un archivo. Al editar,
se ajusta la apertura y el cierre del día existente. Para cambiar el día,
crear su horario y configurar los bloques que correspondan.

Se usan los nombres y restricciones de SGCD_HORARIOS de la v3 local de Nico
y la tabla SGCD_BLOQUES_HORARIOS del mantenedor de bloques. El DDL final debe
generar el ID, validar HH:MI y el rango de apertura y cierre, y asegurar un
horario por recinto y día. La aplicación controla la transacción.

En Oracle de pruebas, crear un horario de 09:00 a 22:00 para un día libre
del recinto y verificar su listado. Crear un bloque de 18:00 a 19:00.
Cambiar el cierre a 20:00 y comprobar que se guardó. Intentar cambiarlo
a 18:30 y comprobar el error -20842. Intentar borrar el horario y comprobar
el error -20844. Borrar el bloque y comprobar que se puede borrar el horario.
Revertir los cambios al finalizar.
