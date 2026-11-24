# UML objetivo del equipo

`SGCD_objetivo.puml` es el modelo propuesto para integrar la base de Nico con
el portal de Eric segun las decisiones de Ignacio y Pablo.

Para verlo sin StarUML, abre `SGCD_objetivo.html` en el navegador. Requiere
conexion a internet para cargar el renderizador Mermaid.

`UML_objetivo.mdj` es la misma estructura de 17 tablas, convertida al formato
editable de StarUML usado en el modelo de Pablo. No agrega ni elimina tablas,
campos ni relaciones del modelo objetivo.

Incluye cuatro diagramas: 1FN con 5 tablas, 2FN con 14 tablas, 3FN con las
17 tablas finales y el modelo objetivo completo.

## Alcance aplicado

- Un solo recinto.
- Futbol, tenis y padel.
- Varios administradores con los mismos privilegios.
- Clientes web y clientes presenciales.
- Reservas por bloques de una hora.
- Seis canchas de futbol 6.
- Una cancha grande formada por las canchas 1, 2 y 3.
- Tarifas modificables por horario y recurso.
- Pagos simples asociados a reservas.
- Auditoria de fichas de clientes.

## Fuera del modelo base

- Membresias y puntos.
- Operador como rol separado.
- Bloqueos programados.
- Fixture y torneos complejos.
- Reglas definitivas de tenis y padel.

## Nota de integracion

Este UML representa el modelo objetivo, no una copia exacta del SQL actual de
Eric. El siguiente paso es adaptar el DDL, los paquetes PL/SQL y las pantallas
PHP a este modelo y no agregar tablas solo porque existen en la version v3.

El archivo se puede abrir o editar con PlantUML. La relacion
`CANCHA_COMPONENTE` documenta que la cancha grande usa exclusivamente las
canchas 1, 2 y 3.
