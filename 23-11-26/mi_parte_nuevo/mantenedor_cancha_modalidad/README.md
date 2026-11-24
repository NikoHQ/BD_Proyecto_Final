# Mantenedor cancha–modalidad

El SQL reúne las cuatro operaciones para administrar qué modalidades admite
cada cancha. Editar reemplaza la modalidad de una asociación para la misma
cancha. El listado devuelve un cursor por cancha.

La clave compuesta de la 3FN usa ID_CANCHA e ID_MODALIDAD. Los nombres físicos
corresponden a la copia local de Nico. El DDL final debe mantener la clave
compuesta y las claves foráneas. La aplicación confirma o revierte.

Al integrar, conectar el filtro de nuevas reservas a la misma asociación.
Revisar con Nico el tratamiento de tarifas vigentes al quitar la
compatibilidad. Las reservas históricas guardan sus propios IDs.

En Oracle de pruebas, elegir una cancha y dos modalidades que todavía no estén
asociadas. Agregar la primera, listar, comprobar que el alta duplicada devuelve
-20850, editar a la segunda, listar y borrar. Probar también que una modalidad
inexistente se rechace por la clave foránea. Revertir al terminar.
