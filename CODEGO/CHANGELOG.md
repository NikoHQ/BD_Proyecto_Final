# CODEGO — bitácora del proyecto

Aquí vive **solo lo que no tiene otra casa**: este CHANGELOG, `ESTADO_ACTUAL.md` y los reportes
fechados. El código y los documentos viven en su ruta canónica (`sql/`, `docs/`, `infra/`) y su
historial es git.

## Reglas

1. Nada de espejos. Los que había se eliminaron el 2026-11-19: duplicaban archivos que ya estaban
   en su ruta y se desincronizaban. Si algo cambia, se cambia en su ruta canónica.
2. Cada sesión de trabajo **agrega una entrada fechada** abajo, con los archivos tocados y el
   resultado verificable.
3. `ESTADO_ACTUAL.md` se reescribe cuando cambia el estado. Los `REPORTE_<fecha>.md` no se tocan:
   son fotos del día.
4. Las rutas de las entradas antiguas son históricas; el mapa vigente está en el `README.md` de
   la raíz.

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
`07_datos_operativos.sql`, `08_pruebas_v3.sql`, web de administración, y definir quién hace las
pantallas del cliente final.

---

## 2026-11-19 — Inscripción de jugadores en torneos, sin fichas extra

**Decisión.** El capitán inscribe a sus jugadores pidiendo **nombre y RUT**. No se crea una ficha
de cliente por jugador. La identidad del participante es una fila de `SGCD_JUGADORES`, con el RUT
como clave natural; si ese RUT ya corresponde a un cliente, `ID_CLIENTE` se enlaza solo y el nombre
se copia de la ficha.

**Por qué.** La versión anterior exigía que cada integrante fuera un cliente existente (PK
`(ID_EQUIPO, ID_CLIENTE)`), lo que obligaba a crear 5 fichas por equipo para inscribir un torneo y
llenaba `SGCD_CLIENTES` de gente que jugó una tarde. La alternativa de guardar solo un nombre libre
perdía la identificación. El RUT da identidad sin ficha, y el enlace opcional evita la persona
duplicada el día que ese jugador se haga socio.

**Esquema: 21 → 22 tablas.**

| Cambio | Detalle |
|---|---|
| Nueva `SGCD_JUGADORES` | `ID_JUGADOR`, `RUT_JUGADOR NUMBER(8)`, `DV_JUGADOR CHAR(1)`, `NOMBRE_JUGADOR`, `ID_CLIENTE NULL`; `UNIQUE (RUT_JUGADOR, DV_JUGADOR)` |
| `SGCD_EQUIPO_JUGADORES` | PK `(ID_EQUIPO, ID_JUGADOR)` en vez de `(ID_EQUIPO, ID_CLIENTE)` |
| `SGCD_EQUIPOS` | `ESTADO_EQUIPO` e `ID_CLIENTE_RESPONSABLE` pasan a nombre canónico; el capitán es el primer jugador |

**Reglas en el paquete** (`SGCD_PKG_TORNEOS`): `registrar_jugador` (alta o reutilización por RUT),
`agregar_jugador` valida DV módulo 11, torneo en `PLANIFICADO`, RUT no repetido en el equipo y
jugador no inscrito en otro equipo del mismo torneo; `inscribir_equipo` cuenta cupos con
`FOR UPDATE`; `RETIRADO` libera cupo sin borrar jugadores.

**Archivos actualizados**

| Ruta | Qué cambió |
|---|---|
| `docs/superpowers/specs/2026-11-18-sgcd-v3-cliente-web-torneos-design.md` | §7.1/§7.4/§7.5 (22 tablas, tres tablas de torneo + regla de identidad), §8.4 (orden de inscripción), §10 (7 casos de prueba nuevos) |
| `sql/oracle/00_GLOSARIO_TABLAS.md` | `SGCD_JUGADORES` documentada, plantilla corregida, mapa de relaciones |

**Orden vigente de los scripts:** `04_ddl_v3.sql` → `05_paquetes_plsql.sql` →
`06_datos_catalogos_v3.sql` → `07_datos_operativos.sql` → `08_pruebas_v3.sql`.

---

## 2026-11-19 (2) — Repositorio ordenado + `04_ddl_v3.sql` compilado

**Contexto.** Los nombres de archivo no decían qué era cada cosa (`sporting_database.sql`,
`PPT Blanco2.pptx`, `17-11-26/3EB0036...mdj`). Se reorganiza el árbol y se escribe el DDL de la v3,
que era el cuello de botella de todo lo demás.

**Árbol nuevo**

| Antes | Ahora |
|---|---|
| `UML.mdj`, `ES3.pdf`, `R2.pdf`, `Carta tipo…docx`, `PPT Blanco*.pptx`, `template.jpg` en la raíz | `docs/modelo/modelo-uml.mdj`, `material/enunciado-ES3.pdf`, `material/enunciado-R2.pdf`, `material/carta-validacion-problema.docx`, `material/plantilla-presentacion-N.pptx`, `material/portada-template.jpg` |
| `17-11-26/3EB…-correccion_gpt.mdj`, `3EB…-tablas.sql`, `…jpg` | `docs/recibido/2026-11-17/modelo-gpt.mdj`, `tablas-v2.sql`, `imagen-referencia.jpg` |
| `sql/oracle/00_GLOSARIO_TABLAS.md` | `docs/modelo/glosario-tablas.md` |
| `sql/oracle/01_ddl_sgcd_corregido.sql`, `02_pruebas_integridad.sql`, `03_datos_catalogos.sql` | `sql/oracle/01_ddl_v2.sql`, `02_pruebas_v2.sql`, `03_catalogos_v2.sql` |
| `sporting_database.sql` | `sql/sqlite/00_prototipo-modelo.sql` |
| `docs/superpowers/specs/2026-11-18-…-design.md` | `docs/diseno/2026-11-18-diseno-v3-cliente-web-torneos.md` |
| `ANALISIS_17-11-26_vs_nuestro.md` | `docs/modelo/analisis-modelo-recibido.md` |

Se agregaron `README.md` en la raíz, en `sql/` y en `material/` (este último con la tabla de
nombres originales, para no perder la referencia). Los movimientos se hicieron con `git mv`: el
historial sigue a cada archivo. Las rutas de las entradas anteriores de este CHANGELOG son las
históricas; el mapa vigente está en `README.md`.

**Archivo nuevo**

| Ruta | Qué es |
|---|---|
| `sql/oracle/04_ddl_v3.sql` | DDL completo de la v3, autocontenido y re-ejecutable (borra las `SGCD_*` antes de crear). 22 tablas, 23 índices, 61 `CHECK` con nombre, 29 `FK`, 16 `UNIQUE`. |

**Validación real.** Compilado en un esquema de pruebas `SGCDV3` del contenedor `oracle-free`
(no se tocó `SGCD`, que sigue en v2):

```
TABLAS SGCD 22 · INDICES SGCD 23 · CHECK SGCD 61 · FK SGCD 29 · UNIQUE SGCD 16
errores de compilación: 0
```

Pruebas de humo ejecutadas contra el DDL (todas con el resultado esperado):

| Caso | Resultado |
|---|---|
| RUT duplicado | `ORA-00001` `UQ_SGCD_CLIENTE_RUT` |
| DV inválido (`X`) | `ORA-02290` `CK_SGCD_CLIENTE_DV` |
| Credencial sin dueño / con dos dueños | `ORA-02290` (`CK_SGCD_CRED_ROL_DUENO`, `CK_SGCD_CRED_DUENO`) |
| Operador sin verificar | `ORA-02290` `CK_SGCD_CRED_PERSONAL_VERIF` |
| Reserva `WEB` con administrador | `ORA-02290` `CK_SGCD_RES_ORIGEN_ADMIN` |
| `NORMAL` con `ID_TORNEO` / `TORNEO` sin `ID_TORNEO` | `ORA-02290` `CK_SGCD_RES_TORNEO_ID` |
| Bloque de torneo sin cliente | **acepta** |
| Mismo bloque dos veces | `ORA-00001` `UX_SGCD_RESERVAS_BLOQUE` |
| Solape parcial 19:00–20:00 vs 19:30–20:30 | **acepta** — el DDL solo atrapa inicios iguales; lo bloquea `SGCD_PKG_RESERVAS` |
| Jugador de torneo enlazado a un cliente existente | **acepta** |
| RUT de jugador duplicado | `ORA-00001` `UQ_SGCD_JUGADOR_RUT` |

**Pendiente.** `05_paquetes_plsql.sql` (el solape parcial es el primer procedimiento), catálogos y
datos de la v3, pruebas completas, web de administración, y decidir quién hace las pantallas del
cliente final.

---

## 2026-11-19 (3) — Secuencias + triggers, v3 compilada en `SGCD` y capa de servicios

**Decisión.** Se reemplaza `IDENTITY` por **secuencia + trigger** en las 19 tablas con PK simple
(las 3 de PK compuesta no llevan llave generada). El trigger solo asigna si el ID viene nulo, así
las cargas con ID explícito siguen funcionando.

**Motivo.** Lo pidió Naiko (probable exigencia de la rúbrica). Técnicamente no arregla los huecos:
una secuencia se consume antes del `INSERT`, igual que `IDENTITY`. `NOCACHE` solo evita perder
números por reinicio.

**Compilación real en el esquema `SGCD`** (ya no en el de pruebas): se descartaron las 17 tablas
de la v2. Sus catálogos son reproducibles, pero `03_catalogos_v2.sql` no sirve en la v3 porque
reajusta columnas `IDENTITY`; los reemplaza `06_catalogos_v3.sql`.

```
TABLAS 22 · SECUENCIAS 19 · TRIGGERS 19 · INDICES 23 · CHECK 61 · FK 29 · UNIQUE 16
errores de compilación: 0
```

**Archivo nuevo**

| Ruta | Qué es |
|---|---|
| `sql/oracle/05_paquetes_plsql.sql` | 6 paquetes, 12 objetos compilados `VALID`, 0 errores: `SGCD_PKG_CLIENTES`, `_AUTH`, `_TARIFAS`, `_RESERVAS`, `_TORNEOS`, `_CONSULTAS`. Incluye la tabla de códigos `ORA-200xx` en el encabezado. |

**Pruebas de humo ejecutadas contra la base real** (todas con el resultado esperado):

| Caso | Resultado |
|---|---|
| Trigger genera el ID con la secuencia | `ID_RECINTO = 1` |
| `INSERT` con ID explícito | se respeta (`777`), la secuencia no salta |
| Ficha con RUT válido (módulo 11) | creada |
| RUT con DV inválido | `ORA-20001` |
| **Solape parcial 19:00–20:00 vs 19:30–20:30** | **`ORA-20007`** |
| Bloque adyacente 20:00–21:00 | aceptado |
| Día sin horario (sábado en recinto que no abre) | `ORA-20005` |
| Reserva web | creada `PENDIENTE` / `WEB` |
| Cuenta no verificada pide historial | `ORA-20011` |
| Tras `verificar_cuenta` | el historial se abre |

**Bug encontrado y corregido en el camino.** Si el recinto no abría ese día, el `SELECT` del
horario lanzaba `ORA-01403` en crudo; ahora `crear_reserva` lo traduce a `ORA-20005` con mensaje.

**Estado de los datos.** La base quedó con el esquema v3 y los paquetes, **sin filas**: los
catálogos de la v2 se perdieron al reconstruir y `06` todavía no existe. Toda prueba de humo se
ejecutó dentro de una transacción con `ROLLBACK`.

