# Mantenedor de tarifas para Nico

El módulo contiene procedimientos para crear, editar, cambiar estado,
borrar y listar tarifas, junto con sus scripts de prueba.

- Ejecutar el módulo sobre el esquema de integración una vez confirmados
  los nombres de tablas, columnas, estados y reglas de vigencia. Los SQL
  conservan los nombres físicos del borrador anterior.
- El INSERT omite ID_TARIFA y lo recupera con RETURNING. El esquema debe
  asignarlo mediante el mecanismo acordado con Pablo.
- Si Nico adopta una API que protege las escrituras de tarifas, integrar
  estas operaciones dentro de esa API y conservar sus controles.
- Antes de publicar, comparar la consulta de tarifa vigente del backend
  con las reglas del mantenedor. Probar que una tarifa creada o editada
  desde administración se use para cotizar un bloque de la misma cancha,
  modalidad, día y horario.
- Compilar 01_mantenedor_tarifas.sql y ejecutar 02_pruebas_tarifas.sql y
  02b_pruebas_errores.sql en Oracle de pruebas con los datos que indican
  sus encabezados.

Paquete de integración. La compilación y la ejecución de pruebas quedan
pendientes del DDL final de Nico.
