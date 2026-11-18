# CODEGO — registro de entregables actualizados

Carpeta aparte con **todo lo que vamos actualizando** del proyecto. No es fuente de verdad:
lo canónico vive en su ruta normal del repo (`sql/oracle/`, `sql/sqlite/`, `infra/`…).
Aquí se guarda una copia **en la misma ruta relativa**, para que se pueda entregar o revisar
sin tocar los originales.

## Reglas

1. Un archivo por ruta canónica. Ruta espejo: `CODEGO/<misma ruta que en el repo>`.
2. Cada actualización **sobrescribe** el espejo y **agrega una entrada** abajo con fecha.
3. Los espejos no se editan a mano: si algo cambia, se cambia en la ruta canónica y se vuelve a copiar.
4. Lo recibido de terceros (`17-11-26/`) no se copia aquí; solo lo que producimos nosotros.
5. El historial real es git; este archivo es el índice legible.

---

## 2026-11-17 — Corrección del modelo 17 tablas contra `17-11-26/`

**Contexto.** El archivo recibido (`tablas.sql` + `correccion_gpt.mdj`) resultó ser el mismo
modelo 3FN de 17 tablas que nuestro `UML.mdj`, renombrado `SGCD_*`, más un DDL Oracle que
nuestro repo no tenía. Se absorben 3 atributos que nos faltaban (`clave_hash`/`perfil`,
`estado_reserva`, `descuento_porcentaje`) y se corrige el DDL.

**Archivos**

| Ruta | Qué es |
|---|---|
| `sql/oracle/01_ddl_sgcd_corregido.sql` | DDL Oracle 23ai, 17 tablas + 15 índices. `IDENTITY`, `NOT NULL` completo, `NUMBER(12,2)`, `CHAR(5)`+`REGEXP_LIKE`, `TIMESTAMP`, 7 `UNIQUE`, 8 `CHECK` de rango, XOR de 3 ramas en `PAGOS`, `TIPO_CANCHA`, índice único por función para el bloque de reserva ignorando `CANCELADA`. |
| `sql/oracle/ANALISIS_17-11-26_vs_nuestro.md` | Diferencias, defectos C-01…C-20 con evidencia, contradicciones internas (D-2…D-5) y decisiones abiertas (D-1…D-4). |

**Validación.** 32/32 sentencias parseadas con `sqlglot` dialecto `oracle`
(`PYTHONPATH=/tmp/opencode/pylibs`). Sin compilar en Oracle real: el contenedor `oracle-free`
está apagado.

**Pendiente de Naiko.** D-1 `IDENTITY` vs secuencia+trigger · D-2 `CANCHA` vs `INSTALACION` ·
D-3 horario por recinto vs por instalación · D-4 agregar `BLOQUEO_CANCHA` (18ª tabla).

---

## 2026-11-17 (2) — Compilación real en Oracle 26ai Free + pruebas de integridad

**Servidor levantado.** `oracle-free` (`container-registry.oracle.com/database/free:latest`,
Oracle AI Database 26ai Free 23.26.3.0.0), volumen `oracle-free-data`, `--shm-size=1g`,
PDB `FREEPDB1`, esquema propio `SGCD` (no se compiló en `SYSTEM`). La imagen de julio 2026
trae la base pre-construida: lista en 15 s, sin `createDB`.

**Archivos**

| Ruta | Qué es |
|---|---|
| `sql/oracle/01_ddl_sgcd_corregido.sql` | Igual que la entrada anterior **con una corrección de portabilidad**: se eliminaron las 17 líneas en blanco que había dentro de cada `CREATE TABLE`. SQL*Plus con `SQLBLANKLINES OFF` (default) trata la línea en blanco como terminador de sentencia, y cortaba cada tabla por la mitad (`SP2-0734: unknown command beginning "CONSTRAINT..."`). Ahora el archivo se pega igual en SQL*Plus, SQLcl o DBeaver. |
| `sql/oracle/02_pruebas_integridad.sql` | 26 pruebas: 24 negativas que exigen el `ORA-` exacto y 2 positivas (T-25 reserva cancelada libera el bloque, T-26 `IDENTITY` genera PK). Deja el esquema vacío al final. |

**Resultado de compilación**

```
errores de compilación: 0
TABLE 17 · INDEX 41 · SEQUENCE 15 · CHECK 130 · FK 18 · UNIQUE 9
filas restantes tras la limpieza: 0 en todas las tablas
```

Los 15 `SEQUENCE` son las secuencias internas `ISEQ$$_` de las 15 columnas `IDENTITY`
(17 tablas menos las 2 de PK compuesta, que no llevan surrogate).

**Resultado de las pruebas: 26 OK / 0 FAIL**

`ORA-02290` (CHECK) ×21 · `ORA-00001` (UNIQUE) ×3 · `ORA-02291` (FK compuesta) ×1 · `ORA-01400` (NOT NULL) ×1

**Dato de operación.** El contador de `IDENTITY` no es continuo: cada `INSERT` rechazado por una
restricción consume un número. T-26 devolvió `ID_PAGO=5` con 0 filas en la tabla. No es un bug;
si la entrega exige numeración sin huecos, hay que volver a secuencia + trigger (D-1 abierto).

---

## 2026-11-17 (3) — Carga de catálogos en Oracle

**Archivo nuevo**

| Ruta | Qué es |
|---|---|
| `sql/oracle/03_datos_catalogos.sql` | Portado del prototipo SQLite a Oracle. 2 recintos, 7 instalaciones con `TIPO_CANCHA`, 5 deportes, 6 modalidades, 10 pares cancha-modalidad, 14 horarios y 78 tarifas (las 21 bandas del prototipo expandidas por día). Re-ejecutable con guarda: no purga si hay reservas o pagos. |

**Resultado verificado**

```
RECINTOS 2 · CANCHAS 7 · DEPORTES 5 · MODALIDADES 6
CANCHA_MOD 10 · HORARIOS 14 · TARIFAS 78
```

**Diferencia deliberada con el prototipo.** En SQLite se cargaban **49 horarios** (7 instalaciones × 7 días)
porque `horario` colgaba de `instalacion`. En el modelo de 17 tablas `HORARIO` cuelga de `RECINTO`, así que
solo caben **14** (2 recintos × 7 días). No es un error de carga: es D-3 manifestándose en datos reales.
Un recinto no puede abrir distinto por instalación con este modelo.

**Dos detalles técnicos que quedaron resueltos en el script**

1. **`INSERT` con ID explícito no avanza la secuencia `IDENTITY`.** Tras cargar IDs 1..7, el siguiente
   `INSERT` sin ID habría chocado con la PK. Se corrige con
   `ALTER TABLE ... MODIFY (col GENERATED BY DEFAULT ON NULL AS IDENTITY (START WITH LIMIT VALUE))`,
   que reposiciona el contador en `max+1`. Verificado: tras la carga, el siguiente `ID_CANCHA` es 8+.
2. **`ORA-00979` en la consulta de verificación**: `ORDER BY c.ID_CANCHA` con la columna fuera del
   `GROUP BY`. Corregido en el archivo.

---

## 2026-11-17 (4) — Resumen de estado exportado

| Ruta | Qué es |
|---|---|
| `CODEGO/ESTADO_ACTUAL.md` | Snapshot del proyecto: lo que existe y lo que falta (capa por capa), estado de las capas, deuda abierta D-1…D-4, siguiente unidad recomendada y datos de acceso. |

Documento sin ruta canónica: vive solo en CODEGO como foto fechada del avance. Se reescribe
cuando cambie el estado, no se versiona por copia.

---

## 2026-11-18 — Cambio de alcance: diseño v3 aprobado (cliente web + torneos)

**Contexto.** El alcance del proyecto cambia: el cliente final pasa a ser usuario del sistema
(se registra y reserva por sí mismo), se agrega un módulo de torneos **sin partidos** (inscripción
de equipos + arriendo de bloques de cancha) y la web de administración. El modelo pasa de 17 a
**21 tablas**. Se documenta el diseño completo y se aprueba antes de construir. **No se compiló
nada**: la base sigue con las 17 tablas de la v2.

**Archivos**

| Ruta | Qué es |
|---|---|
| `docs/superpowers/specs/2026-11-18-sgcd-v3-cliente-web-torneos-design.md` | Diseño v3 aprobado: decisiones D1–D7 + O4, esquema de 21 tablas, 6 paquetes PL/SQL, contrato de `crear_reserva`, matriz de pruebas y registro de la revisión independiente (7 preguntas, 7 resoluciones). |
| `sql/oracle/00_GLOSARIO_TABLAS.md` | Glosario y diccionario de la base: tags de nombres, 21 dominios de valores, una línea por columna de cada tabla y mapa de relaciones. |
| `CODEGO/REPORTE_2026-11-18.md` | Reporte del día: cambio de alcance, decisiones, estado real de la base, riesgos y próxima sesión. |

**Decisiones cerradas.** RUT identifica y no autentica · `ID_CLIENTE` sigue siendo la llave
interna y el RUT es `NUMBER(8)` + `DV CHAR(1)` · la cuenta nace `NO_VERIFICADA` y se verifica en
recepción · la ficha existe sin cuenta (el caso normal) · la reserva web nace `PENDIENTE` · el
bloque de torneo **es una reserva** (un solo calendario) · solape por cancha e intervalo real ·
precio de bloque = tarifa × (1 − descuento % del torneo), exento = 100 % · mantención es estado
indefinido de la cancha, sin bloqueos con fecha (D-4 cerrada como no aplicable).

**Corrección detectada en el camino.** El índice único de la v2 incluye `ID_MODALIDAD`, así que
hoy dos reservas pueden ocupar la misma cancha a la misma hora con modalidades distintas. Se
corrige en la v3 quitando la modalidad de la clave y agregando el chequeo de intervalos en
`SGCD_PKG_RESERVAS`.

**Pendiente.** Plan de trabajo, `04_ddl_v3.sql`, `05_paquetes_plsql.sql`, `06_datos_catalogos_v3.sql`,
`07_pruebas_v3.sql`, web de administración, y definir quién hace las pantallas del cliente final.

