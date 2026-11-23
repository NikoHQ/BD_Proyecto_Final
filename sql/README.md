# Scripts de base de datos

## Oracle — el que se entrega

Ejecutar **en orden**, conectado como el esquema dueño (`SGCD`), no como `SYSTEM`.

| # | Archivo | Contenido | Toca datos |
|---|---|---|---|
| 01 | `oracle/01_ddl_v2.sql` | Esquema v2, 17 tablas. Histórico: se conserva como evidencia del modelo anterior | sí, borra |
| 02 | `oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | no, deja el esquema vacío |
| 03 | `oracle/03_catalogos_v2.sql` | Catálogos de la v2: 2 recintos, 7 instalaciones, 78 tarifas | sí, carga |
| 04 | `oracle/04_ddl_v3.sql` | **Esquema v3, 22 tablas.** Autocontenido: borra las `SGCD_*` y las recrea | sí, borra |
| 05 | `oracle/05_paquetes_plsql.sql` | 6 paquetes: clientes, auth, tarifas, reservas, torneos, consultas | no |
| 06 | `oracle/06_catalogos_v3.sql` | Catálogos adaptados a la v3 | sí, carga |
| 07 | `oracle/07_datos_operativos.sql` | Datos demo re-ejecutables | sí, recarga |
| 08 | `oracle/08_pruebas_v3.sql` | Pruebas negativas y positivas de la v3 | no, limpia al final |
| 09 | [`oracle/09_torneos_tamano_plantilla.sql`](oracle/09_torneos_tamano_plantilla.sql) | Migra el tamaño de los equipos sobre Oracle v3 | conserva los datos existentes |

La v3 reemplaza a la v2: `04` borra lo que haya. Para conservar la v2 hay que exportarla antes.
`03_catalogos_v2.sql` **no sirve en la v3**: reajusta columnas `IDENTITY`, que ya no existen. Los
catálogos de la v3 van en `06`. En un esquema v3 existente, aplica únicamente la migración `09` para incorporar el tamaño de equipo. [Contrato Oracle de torneos](../docs/entrega/TORNEOS_ORACLE.md)

## SQLite — prototipo, no se entrega

`sqlite/00_prototipo-modelo.sql` (modelo completo) y `sqlite/01_catalogos.sql` (catálogos). Sirven
para probar reglas sin levantar Oracle; el motor de la entrega es Oracle.

## Reglas al escribir scripts

- Sin líneas en blanco **dentro** de una sentencia: SQL*Plus con `SQLBLANKLINES OFF` corta la
  sentencia en la línea vacía y la mitad de la tabla se pierde.
- Un archivo = un propósito. No mezclar DDL, datos y pruebas.
- Todo lo que se pueda probar, se prueba con una negativa que exija el `ORA-` exacto.
