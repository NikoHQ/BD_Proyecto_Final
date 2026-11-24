# Aporte de Ignacio

Actualizado: 20-11-2026. Falta compilar y probar en Oracle.

## Archivos

- 02: actualizar nombre, telefono y correo del cliente.
- 03: borrar clientes sin registros relacionados.
- 04: tabla, secuencia y triggers para registrar cambios y borrados.
- 05: tres consultas para los reportes.
- 06: pruebas positivas de clientes y auditoria.
- 06b: errores esperados, ejecutar cada bloque por separado.
- 06c: datos de prueba y resultados esperados de los reportes.
- 07: mostrar errores de compilacion.

## Antes de cargar

Usar un esquema de pruebas con la v3 de Nico, autocommit desactivado y sin otros cambios
pendientes. Comparar primero las columnas y las siete FK de clientes con las tablas
finales de Pablo. Todas deben seguir habilitadas y sin borrado en cascada.

El archivo 04 PROPONE crear SGCD_AUDITORIA_CLIENTES, ademas de su secuencia y triggers.
Esto llevaria el modelo de 22 a 23 tablas. Acordarlo con Nico y Pablo ANTES de ejecutarlo.
La rubrica pide monitoreo con triggers; no obliga a crear esta tabla especifica.
No volver a ejecutar el DDL de Nico para probar esto: su limpieza borra las tablas SGCD_*.

## Orden de ejecucion

1. Ejecutar `SET SQLBLANKLINES ON` y usar F5 en SQL Developer.
2. Cargar 04 una sola vez. Si ya existe la auditoria, conservar sus datos y secuencia.
3. Cargar 02 y 03. Ejecutar 07 y comprobar que los objetos existen y no tienen errores.
4. Ejecutar 06. Debe mostrar los mensajes OK y revertir los datos de prueba.
5. Ejecutar cada bloque de 06b y comparar el error con su comentario.
6. Ejecutar 06c desde la misma carpeta. Debe mostrar ingresos de 2 pagos por 200,
   una cancha con 2 reservas y un cliente con 2 reservas. Tras ROLLBACK, los reportes
   deben quedar vacios. La prueba exige los ultimos 30 dias sin operaciones previas.
7. Hacer las pruebas de dos sesiones indicadas abajo y guardar las salidas.

Separar la creacion de objetos de las pruebas: el DDL confirma transacciones.
Las pruebas revierten la transaccion completa; no usar una conexion con trabajo pendiente.
Las secuencias consumen numeros aunque se haga ROLLBACK. Los RUT de prueba son sinteticos.

## Para Nico

Los procedimientos no hacen COMMIT ni ROLLBACK: el backend confirma o revierte y cierra
la transaccion. Exigir perfil administrativo antes de llamar estas operaciones/reportes.
Telefono y correo NULL vacian el campo. ID, RUT, DV y estado del cliente se conservan.
La tabla mantiene las validaciones de formato/largo y las FK/UNIQUE; algunos errores
concurrentes conservaran su codigo original de Oracle, como ORA-00001 u ORA-02292.

La auditoria guarda fecha y valores anteriores/nuevos, sin identificar al operador.
Se revierte junto con los cambios y conserva registros de fichas borradas.

Los reportes son SELECT de los ultimos 30 dias para parametrizar y conectar al frontend:
ingresos cobrados, reservas por cancha y clientes con mas reservas. Excluyen reservas
canceladas y muestran solo canchas/clientes con reservas. No calculan ocupacion porcentual.

El ZIP para compartir esta en BaseDatos: borradores_plsql_para_revision.zip.
No se ejecuto Oracle en esta sesion. Despues de revisar nuestro aporte, revisaremos el de Nico.

## Pruebas con dos conexiones

Usar fichas creadas solo para probar, sin autocommit. Anotar sus IDs.

- A actualiza una ficha sin confirmar. B intenta actualizarla: debe esperar. A revierte;
  B termina y luego revierte. Revisar que los datos y auditoria vuelvan al estado inicial.
- Con otra ficha, A borra sin confirmar. B intenta editarla. A confirma: B debe recibir
  -20103. Revertir B. Si A hubiera revertido, B deberia poder actualizar.
- A crea una credencial sin confirmar y B intenta borrar su ficha. Si A confirma,
  el borrado debe rechazarse con -20107 u ORA-02292. Usar otra ficha para probar rollback de A.
- Dos fichas intentan usar el mismo correo. Solo una puede conservarlo: la otra debe
  recibir -20104 u ORA-00001. Revertir la llamada rechazada.

Al terminar, cerrar las transacciones y limpiar solo los datos de prueba confirmados,
primero hijos y luego fichas. La auditoria ya confirmada permanece.

## Referencias de clases

Base principal: TXT de Unidad 1 y Unidad 2. TRIM y LOWER confirmados por Ignacio.
COUNT/SUM/GROUP BY: U1 L5; JOIN: U1 L6; TRUNC: U1 L3-2; TO_CHAR: U1 L4.
Procedimientos: U2 C1; secuencias: U2 C2; triggers: U2 C4 y PAUTA ES2.

Del PPT se uso SQL%ROWCOUNT para comprobar filas afectadas (Clase 3, diapositiva 8),
AFTER DELETE para auditar borrados (Clase 4, diapositivas 2/4/8) y RAISE para mostrar
el error despues de revertir pruebas (Clase 1-2, diapositiva 14). SHOW ERRORS esta en
Clase 4, diapositiva 10. No se agregaron indices, ciclos ni SQL dinamico.

## Pendientes del proyecto

Estos archivos aportan UPDATE/DELETE de un CRUD, monitoreo y consultas para tres dashboards.
Falta probarlos e integrarlos, revisar los diez CRUD completos, cinco gestores, perfiles,
datos, video y modelo final. No se da la rubrica completa por cumplida.
Despues de revisar nuestro aporte, revisaremos el codigo de Nico.
