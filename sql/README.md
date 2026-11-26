# Scripts de base de datos

## Oracle — el que se entrega

Ejecutar **en orden**, conectado como el esquema dueño (`SGCD`), no como `SYSTEM`.

### Modelo objetivo de 19 tablas (vigente desde 2026-11-23)

| # | Archivo | Contenido | Toca datos |
|---|---|---|---|
| 10 | `oracle/10_ddl_sgcd_19.sql` | **Esquema de 19 tablas del UML del equipo.** Autocontenido: borra las `SGCD_*` y las `SGCD_SEQ_*` y las recrea, con PK, FK, `UNIQUE`, `CHECK`, índices, 16 secuencias y 18 triggers (16 de llave y los 2 de auditoría) | sí, borra |
| 11 | `oracle/11_catalogos_sgcd_19.sql` | Catálogos del recinto único: 10 canchas (6 de fútbol 6, la grande y 3 sueltas), sus componentes, 3 deportes, 3 modalidades, 6 horarios, 82 bloques, 120 tarifas, 3 torneos y las cuentas de laboratorio | sí, purga y carga |
| 12a | `oracle/12a_pkg_auth.sql` | `SGCD_PKG_AUTH` sobre `SGCD_USUARIOS`: cuenta con perfil, alta, clave y estado | no |
| 12b | `oracle/12b_pkg_clientes.sql` | `SGCD_PKG_CLIENTES`: ficha, registro de cuenta web y borrado con guardas | no |
| 12c | `oracle/12c_mantenedores_catalogo.sql` | Procedimientos de Ignacio: deporte, modalidad, cancha y cancha–modalidad | no |
| 12d | `oracle/12d_mantenedores_horario.sql` | Procedimientos de Ignacio: horario, bloque y administrador | no |
| 12e | `oracle/12e_mantenedor_tarifas.sql` | Procedimientos de Ignacio: tarifas por cancha, modalidad, día y franja | no |
| 12f | `oracle/12f_pkg_tarifas.sql` | `SGCD_PKG_TARIFAS`: valor por bloque y cotización de N bloques con detalle | no |
| 12g | `oracle/12g_pkg_reservas.sql` | `SGCD_PKG_RESERVAS`: bloques consecutivos, choque por solape, candado ordenado de la cancha grande/1-2-3, solicitud web pendiente, cancelación, reprogramación y cierre de vencidas | no |
| 12h | `oracle/12h_pkg_pagos.sql` | `SGCD_PKG_PAGOS`: pago único por adelantado y por el total, cobro de la diferencia tras reprogramar, anulación como reembolso y saldo por reserva | no |
| 12i | `oracle/12i_pkg_torneos.sql` | `SGCD_PKG_TORNEOS`: torneo, inscripción con nómina y cupos, RUT único por torneo, retiro y programación por bloques que entra a reservas | no |
| 12j | `oracle/12j_pkg_consultas.sql` | `SGCD_PKG_CONSULTAS`: ingresos, reservas por cancha y clientes por reservas, con rango obligatorio y filtro de propiedad | no |
| 13 | `oracle/13_pruebas_sgcd_19.sql` | Comprobaciones del DDL y los catálogos: objetos, coherencia, IDs automáticos, auditoría y reglas negativas. Revierte todo al final | no, limpia al final |
| 14 | `oracle/14_pruebas_paquetes_sgcd_19.sql` | Pruebas de los paquetes y mantenedores, por unidad. Revierte todo al final | no, limpia al final |
| 15 | [`oracle/15_datos_operativos_sgcd_19.sql`](oracle/15_datos_operativos_sgcd_19.sql) | Carga 16 fichas ficticias, 48 reservas, 32 pagos y 10 inscripciones para el recorrido de entrega | agrega y conserva lo existente |

Las carreras entre dos conexiones no caben en un bloque anónimo: viven en
`tests/integracion_dos_sesiones.sh` con `tests/sesion.sql`, y se ejecutan con
`bash tests/integracion_dos_sesiones.sh`. Crean su propio fixture con `COMMIT`, lo borran al
terminar y dejan el esquema limpio.

Para Docker local, sigue la [guía de acceso](../docs/entrega/ACCESO_DEMO.md). El instalador verifica
el usuario `SGCD19` y sólo ejecuta `10` y `11` cuando está vacío. En un esquema ya instalado,
`--actualizar-paquetes` recompila `12a`–`12j` y `--datos-demo` carga el lote ficticio de `15` por
solicitud explícita. Si ejecutas los SQL por separado en SQL*Plus, usa
`NLS_LANG=AMERICAN_AMERICA.AL32UTF8` para conservar acentos y caracteres como «·».

### Transición v3 de 23 tablas (histórica)

| # | Archivo | Contenido | Toca datos |
|---|---|---|---|
| 01 | `oracle/01_ddl_v2.sql` | Esquema v2, 17 tablas. Histórico: se conserva como evidencia del modelo anterior | sí, borra |
| 02 | `oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | no, deja el esquema vacío |
| 03 | `oracle/03_catalogos_v2.sql` | Catálogos de la v2: 2 recintos, 7 instalaciones, 78 tarifas | sí, carga |
| 04 | `oracle/04_ddl_v3.sql` | Esquema v3 de transición, **23 tablas** (incluye membresías, puntos, implementos y auditoría) | sí, borra |
| 05 | `oracle/05_paquetes_plsql.sql` | 6 paquetes de la v3: clientes, auth, tarifas, reservas, torneos, consultas | no |
| 06 | `oracle/06_catalogos_v3.sql` | Catálogos adaptados a la v3 | sí, carga |
| 07 | `oracle/07_datos_operativos.sql` | Datos demo re-ejecutables | sí, recarga |
| 08 | `oracle/08_pruebas_v3.sql` | Pruebas negativas y positivas de la v3 | no, limpia al final |
| 09 | [`oracle/09_torneos_tamano_plantilla.sql`](oracle/09_torneos_tamano_plantilla.sql) | Migra el tamaño de los equipos sobre Oracle v3 | conserva los datos existentes |

La v3 reemplaza a la v2 y la 10 reemplaza a la v3: cada DDL borra lo que haya. Para conservar datos
hay que exportarlos antes. `03_catalogos_v2.sql` **no sirve** en las versiones posteriores: reajusta
columnas `IDENTITY`, que ya no existen. [Mapa del modelo objetivo](../docs/entrega/MODELO_OBJETIVO.md) ·
[Contrato Oracle de torneos](../docs/entrega/TORNEOS_ORACLE.md)

## SQLite — prototipo, no se entrega

`sqlite/00_prototipo-modelo.sql` (modelo completo) y `sqlite/01_catalogos.sql` (catálogos). Sirven
para probar reglas sin levantar Oracle; el motor de la entrega es Oracle.

## Reglas al escribir scripts

- Sin líneas en blanco **dentro** de una sentencia: SQL*Plus con `SQLBLANKLINES OFF` corta la
  sentencia en la línea vacía y la mitad de la tabla se pierde.
- Los archivos con datos en español se cargan con `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` y
  `LANG=C.UTF-8` en el contenedor. Sin eso, el cliente convierte cada acento en U+FFFD al insertar.
- Un archivo = un propósito. No mezclar DDL, datos y pruebas.
- Los IDs los genera el trigger `BEFORE INSERT` sobre su secuencia. La carga de catálogos inserta
  IDs explícitos y al final reposiciona cada secuencia en `MAX+1`.
- Todo lo que se pueda probar, se prueba con una negativa que exija el `ORA-` exacto.
