# Especificacion de integracion para agentes de IA

Este documento define el alcance objetivo que deben usar los agentes que
revisen o modifiquen el backend de Nico y el frontend de Eric. La fuente de
verdad del modelo es:

`tablas/UML_objetivo.mdj`

El modelo final tiene **17 tablas**. No se debe copiar la v3 actual sin
adaptacion. El backend y el frontend deben ajustarse a este alcance.

## Alcance acordado

- Un solo recinto.
- Deportes: futbol, tenis y padel.
- Varios administradores con los mismos privilegios.
- Clientes con cuenta web y clientes presenciales sin cuenta.
- Paginas separadas para administrador y cliente.
- Horarios por bloques de una hora.
- Seis canchas de futbol 6.
- Una cancha grande formada exclusivamente por las canchas 1, 2 y 3.
- Tarifas modificables por administrador segun cancha, modalidad, dia y horario.
- Reservas de una o mas horas usando bloques consecutivos.
- Pagos simples asociados a una reserva.
- Auditoria de fichas de clientes.
- Torneos simples con inscripcion de clientes y bloques de cancha asociados a reservas.
- Sin membresias ni puntos.
- Sin bloqueos de mantenimiento programados.
- Sin fixture, partidos, resultados ni clasificaciones.

## Tabla nueva importante

`BLOQUE_HORARIO` representa los bloques que ve el cliente:

- 08:00 a 09:00
- 09:00 a 10:00
- 10:00 a 11:00

`HORARIO` define la apertura y cierre del recinto. `BLOQUE_HORARIO` divide
ese horario en las opciones que se pueden seleccionar.

## Regla de cancha grande

La cancha grande usa las canchas 1, 2 y 3.

- Si una de esas tres canchas esta ocupada, la cancha grande no aparece.
- Si se reserva la cancha grande, las canchas 1, 2 y 3 quedan ocupadas.
- Las canchas 4, 5 y 6 siguen siendo independientes.

## Requisitos para el backend y Oracle

Revisar la v3 actual contra el UML y producir primero un mapa de cambios. No
realizar modificaciones masivas antes de identificar incompatibilidades.

Revisar especialmente:

1. Como adaptar el DDL a las 17 tablas finales.
2. Como reemplazar o ajustar `CREDENCIALES` para el esquema de usuarios,
   clientes y administradores del UML.
3. Eliminar del alcance membresias, puntos, implementos y operador.
4. Agregar `BLOQUE_HORARIO` y sus relaciones.
5. Adaptar tarifas y reservas a bloques de una hora.
6. Implementar la regla de la cancha grande sin permitir cruces con 1, 2 y 3.
7. Mantener pagos simples y auditoria de clientes.
8. Implementar `TORNEO` e `INSCRIPCION_TORNEO` con cupos, estado y fechas.
9. Permitir que una reserva opcionalmente se asocie a un torneo.
10. Revisar que los paquetes PL/SQL y los nombres de parametros coincidan con
   el UML antes de cambiar el frontend.

No borrar ni reemplazar el esquema actual sin preparar antes una copia o una
version nueva para pruebas.

## Requisitos para el frontend

Revisar el portal y el panel contra el mismo UML.

Revisar especialmente:

1. La pagina de cliente debe mostrar dia, bloque horario y canchas disponibles.
2. La pagina de administrador debe administrar tarifas, reservas y clientes.
3. Mostrar seis canchas de futbol 6.
4. Mostrar la cancha grande solo cuando 1, 2 y 3 esten libres.
5. Permitir seleccionar dos o mas bloques consecutivos para una reserva larga.
6. El precio debe venir del backend y conservarse en la reserva.
7. Retirar pantallas de membresias y puntos.
8. Mostrar torneos, cupos e inscripciones de clientes sin fixture ni resultados.

El frontend no debe inventar nombres de tablas ni parametros. Debe esperar el
contrato final de los paquetes o endpoints de Nico.

## Orden recomendado

1. Revisar el UML y confirmar las 17 tablas.
2. Nico prepara el mapa de cambios del DDL y paquetes.
3. El grupo aprueba ese mapa.
4. Nico adapta Oracle en una copia de pruebas.
5. Eric adapta las pantallas al contrato confirmado.
6. Probar una reserva de una hora, una de dos horas y una reserva de cancha
   grande.

Primero necesitamos una revision de cada IA y una lista de conflictos. No
hacer cambios masivos hasta que el grupo confirme esa lista.
