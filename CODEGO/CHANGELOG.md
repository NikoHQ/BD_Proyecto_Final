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
catálogos de la v2 se perdieron al reconstruir y `06` todavía no existía (se escribió en la entrada
siguiente). Toda prueba de humo se ejecutó dentro de una transacción con `ROLLBACK`.

---

## 2026-11-19 (4) — Catálogos de la v3 cargados

**Decisiones aplicadas** (aprobadas por Naiko): catálogo completo **+ 2 credenciales de personal**;
datos de la v2 copiados tal cual (la ubicación de los recintos sigue en discusión); IDs explícitos
con reposicionamiento de secuencias al final; guarda contra datos transaccionales; y **un ejemplo
de vigencia de tarifa** para que esa columna deje de estar muerta.

**Archivo nuevo**

| Ruta | Qué es |
|---|---|
| `sql/oracle/06_catalogos_v3.sql` | Catálogos v3: 2 recintos, 7 instalaciones, 5 deportes, 6 modalidades, 10 pares, 14 horarios, **80 tarifas** (78 base + 2 de temporada alta), 3 planes, 8 artículos, 2 administradores y 2 credenciales demo (`ADMIN` / `OPERADOR`, clave `Demo1234`). Idempotente y con `WHENEVER SQLERROR EXIT FAILURE`. |

**Resultado verificado**

```
RECINTOS 2 · CANCHAS 7 · DEPORTES 5 · MODALIDADES 6 · CANCHA_MOD 10 · HORARIOS 14
TARIFAS 80 · PLANES 3 · ARTICULOS 8 · ADMINISTRADORES 2 · CREDENCIALES 2
Secuencias reposicionadas: 10   (SGCD_SEQ_RECINTOS -> 3, SGCD_SEQ_CANCHAS -> 8, SGCD_SEQ_TARIFAS -> 244 ...)
```

**Vigencia de tarifa comprobada contra el paquete** (Padel dobles, sábado, 09:00–20:00):

| Fecha de la reserva | `tarifa_vigente` |
|---|---|
| 2026-11-21 | 15.000 |
| 2026-12-05 | 18.000 |
| 2027-01-10 | 18.000 |

Es decir: la fila nueva se sobrepone desde el 1 de diciembre y nada anterior se reescribe.

**Dos defectos corregidos en el camino**

1. `EXISTENCIAS_ARRIENDO_ARTICULO` es `NOT NULL` con default 0; el artículo "Silbato" intentaba
   insertar `NULL`. Corregido a 0.
2. La verificación de secuencias usaba `USER_SEQUENCES`, que mira el esquema **del usuario
   conectado**. Ejecutando como `SYSTEM` con `CURRENT_SCHEMA=SGCD` devolvía las secuencias de
   `SYSTEM` y no imprimía nada. Ahora usa `ALL_SEQUENCES` filtrado por `CURRENT_SCHEMA`.

**Dato técnico útil.** `ALTER SEQUENCE ... RESTART START WITH n` fija el **próximo** valor y admite
bajar: tras llegar a 3, un `RESTART START WITH 1` devuelve 1. Por eso el script calcula
`MAX(id)+1` en lugar de escribir un número fijo: un valor fijo mal puesto duplicaría claves.

**Idempotencia comprobada.** El script se ejecutó tres veces seguidas; el estado final siempre fue
el mismo y las secuencias siguieron por delante del máximo.


---

## 2026-11-20 — Aporte de clientes integrado (tabla 23, CRUD y auditoría)

**Contexto.** Ignacio entregó `mi_parte_plsql/` con actualizar/borrar ficha, una tabla de
auditoría y tres reportes. Se revisó contra el modelo v3 y se integró en las rutas canónicas.
Decisiones y contrato completo en
[`docs/diseno/2026-11-20-integracion-aporte-clientes.md`](../docs/diseno/2026-11-20-integracion-aporte-clientes.md).

**Archivos tocados**

| Ruta | Cambio |
|---|---|
| `sql/oracle/04_ddl_v3.sql` | Tabla 23 `SGCD_AUDITORIA_CLIENTES` + secuencia + índice + `TRG_SGCD_CLIENTES_AU/AD` + `BI` de la auditoría. El DDL pasa de 22 a 23 tablas y de 19 a 20 pares secuencia/trigger |
| `sql/oracle/05_paquetes_plsql.sql` | `SGCD_PKG_CLIENTES`: `actualizar_ficha`, `cambiar_estado`, `borrar_ficha`. `SGCD_PKG_CONSULTAS`: `reporte_ingresos`, `reporte_reservas_cancha`, `reporte_clientes_reservas`. Errores nuevos `-20024..-20026` |
| `sql/oracle/08_pruebas_v3.sql` | Nuevo. Secciones: ficha + auditoría, errores esperados y reportes |
| `README.md` | Estado, 23 tablas y estado de cada script |

**Resultado verificado**

```
SGCD       TABLAS 23 · SECUENCIAS 20 · TRIGGERS 22 · INDICES 24 · CHECK 62 · FK 29 · UNIQUE 16
           PAQUETES 6 (12 objetos VALID) · INVALIDOS 0
PRUEBAS    9 OK (1.1 a 1.7, 3.1, 3.2) · 0 fallos
REBUILD    esquema desechable SGCD_DRY: 04 -> 05 -> 06 = 23 tablas, 80 tarifas, 2 credenciales, 0 inválidos; usuario eliminado después
```

**Decisiones que evitan trampas**

1. La auditoría vive dentro de `04_ddl_v3.sql` porque su limpieza borra tablas `SGCD_*` y
   secuencias `SGCD_SEQ_*`: en un archivo aparte, una re-ejecución del DDL la dejaría huérfana.
2. Los procedimientos entran al paquete: la rúbrica exige la lógica en la capa de servicios y el
   catálogo de errores ya tenía `-20002` y `-20017` para los mismos casos.
3. `crear_ficha` ahora responde `-20025` cuando falta el nombre (antes `-20002`).
4. El operador de la auditoría llega por `CLIENT_IDENTIFIER`; si PHP no lo fija, la columna queda
   nula y nada más cambia.
5. `borrar_ficha` conserva su conteo de las 7 FK, pero además traduce `ORA-02292` a `-20026` para
   la carrera entre el conteo y el `DELETE`.

**No ejecutado a propósito**

- No se re-ejecutó `04_ddl_v3.sql` sobre `SGCD`: se aplicaron sólo los objetos nuevos, para no
  borrar catálogos ni credenciales. La re-ejecución completa se validó en `SGCD_DRY`.
- `mi_parte_plsql/` se deja intacto como referencia del aporte; sus pruebas apuntan a los
  procedimientos sueltos y a los códigos `-201xx`, que ya no existen.

---

## 2026-11-20 (2) — API de clientes y despliegue nativo

**Contexto.** Paso 2 de la integración del panel: la página de clientes deja de escribir en
`localStorage` y pasa a invocar `SGCD_PKG_CLIENTES`. Se descarta `compose.yaml` (levantaba un
segundo Oracle en 1521) y se documenta el despliegue sobre el Apache + PHP-FPM ya instalado.

**Archivos**

| Ruta | Cambio |
|---|---|
| `web/includes/api.php` | Nuevo. Sesión, CSRF por cabecera, lectura JSON/formulario, `apiLlamar` (binds + cursor + commit), mapa de errores Oracle → HTTP |
| `web/api/clientes.php` | Nuevo. `listar`, `ver`, `crear`, `actualizar`, `estado`, `borrar` |
| `web/includes/auth.php` | `csrfToken()` extraído de `csrfField()` |
| `web/index.php` | `<meta name="csrf-token">` para el JavaScript |
| `sql/oracle/05_paquetes_plsql.sql` | `listar_fichas` (filtros, paginación, total) y `ficha_detalle` (contadores) en `SGCD_PKG_CLIENTES`; error `-20027` |
| `infra/DESPLIEGUE_WEB.md` | Nuevo. Comandos en fish: variables en `www.conf`, `rsync` a `/srv/http`, reinicio y diagnóstico |
| `docs/diseno/2026-11-20-api-clientes.md` | Nuevo. Contrato, errores y trampas de OCI8 |
| `docs/entrega/ACCESO_DEMO.md` | Arranque sin compose; crédito `ADMIN/admin` |
| `compose.yaml`, `.env.example` | Eliminados |

**Verificado**

```
17 casos curl: 200/201/400/401/403/404/405/409 en el código esperado
SGCD: 0 clientes y 0 auditoría tras limpiar los datos de prueba · 3 credenciales (ADMIN, OPERADOR, NAIKO)
05: 6 paquetes VALID, 0 inválidos
```

**Trampas resueltas** (detalle en `docs/diseno/2026-11-20-api-clientes.md`): buffer de 1 byte en
OUT NUMBER (`ORA-06502`), `BOOLEAN` no bindeable, OUT que no vuelve por referencia, cursor
`SQLT_RSET`, sesión ausente en el endpoint y OPcache del servidor embebido.

---

## 2026-11-20 — Cierre de jornada

**Estado.** Esquema v3 con 23 tablas y 6 paquetes `VALID` (0 inválidos), catálogos cargados,
panel desplegado en `/srv/http` sobre Apache + PHP-FPM nativo y login contra Oracle funcionando.
`web/` y `/srv/http` son idénticos; `main` en GitHub al día.

**Lo que quedó operativo**

- CRUD de clientes completo en `SGCD_PKG_CLIENTES` + `api/clientes.php`, con permisos por perfil,
  CSRF, auditoría atribuida al operador y 17 casos curl verificados.
- Tabla 23 `SGCD_AUDITORIA_CLIENTES` con sus triggers de monitoreo.
- Tres reportes como funciones de cursor, listos para conectar.
- Despliegue documentado en `infra/DESPLIEGUE_WEB.md`; `compose.yaml` descartado.

**Pendientes al cierre** (detalle en `README.md`)

1. `07_datos_operativos.sql`.
2. Resto de `08_pruebas_v3.sql` (reservas, pagos, torneos, auth).
3. Conectar `clientes.js` a la API y quitar el modo demostración de esa vista.
4. Página de Reportes.
5. Agenda, reservas, pagos y torneos contra los paquetes.
6. Recuperación por preguntas.
7. Mostrar `CREADO_EN_RESERVA` en los choques de horario.

**Base al cierre:** 0 clientes, 0 reservas, 0 pagos, 0 filas de auditoría; 80 tarifas, 3
administradores y 3 credenciales (`ADMIN`, `OPERADOR`, `NAIKO`).

---

## 2026-11-23 — Entrega del equipo (UML de 19 tablas) fusionada y plan de integración

**Contexto.** El grupo cerró el modelo objetivo: **19 tablas** con un recinto único, fútbol/tenis/pádel,
usuarios con rol administrador o cliente, horarios en bloques de una hora y la cancha grande compuesta
por las canchas 1, 2 y 3. Pablo entregó `tablas.sql`; Ignacio, nueve mantenedores, pago de reserva,
auditoría y reportes; Eric subió el portal de clientes adaptado al modelo.

**Archivos**

| Ruta | Qué es |
|---|---|
| `23-11-26/` | Material recibido tal cual: `mensajes.txt`, `tablas.sql`, `UML_objetivo_19_tablas.mdj`, `mi_parte_nuevo/` y `tablas/` |
| `docs/diseno/2026-11-23-plan-19-tablas.md` | Plan de integración: mapa v3 → 19 tablas, renombres del SQL de Ignacio, 8 decisiones bloqueantes, fases y reparto |
| `README.md` | Estado al 23-11 y pendientes reordenados por el modelo objetivo |
| `docs/entrega/ACCESO_DEMO.md` | Fusión de ambas guías; cuentas corregidas a `ADMIN/admin` y `OPERADOR/Demo1234` |

**Fusión de `codex/frontend-admin-demo` (`563d14d`) en `main` (`27267d8`).** Entran el portal de
clientes (`web/cliente/`), el panel reubicado en `web/dashboardadmin/`, los contratos
`RESERVAS_ORACLE.md` y `TORNEOS_ORACLE.md`, `MODELO_OBJETIVO.md`, el UML de 19 tablas en
`docs/modelo/uml-equipo-19/` y las pruebas `tests/portal-cliente.php` y `tests/torneos-cliente.php`.

**Resolución de conflictos.** `web/index.php` queda como portal; la administración vive en
`/dashboardadmin/`. `README.md` y `ACCESO_DEMO.md` se combinan. En `sql/oracle/04` y `06` se conserva
el esquema v3 de 23 tablas, que es el que compila con los paquetes y la auditoría desplegados; la
adaptación de 16 tablas de la rama queda en el historial (`563d14d`) como referencia para el DDL
definitivo. La fusión automática de `05_paquetes_plsql.sql` conservó el CRUD de la ficha y los reportes.

**Validación.** `php -l` sobre todo `web/` sin errores; `tests/portal-cliente.php` y
`tests/torneos-cliente.php` en verde. Sin ejecutar Oracle en esta sesión: el DDL de 19 tablas todavía
no existe.

**Decisiones que hay que cerrar con el grupo** (detalle en el plan): 17 vs 19 tablas · `TARIFA` con o
sin `ID_MODALIDAD` · columnas de auditoría (valores serializados de Pablo vs una columna por campo de
Ignacio) · rol `OPERADOR` fuera del UML · "partidos y bloqueos" del calendario fuera de alcance ·
secuencias y triggers de las 19 tablas.

---

## 2026-11-23 (2) — DDL de 19 tablas y catálogos del recinto único, compilados y probados

**Contexto.** Cerradas las decisiones con Naiko: 19 tablas, `TARIFA` con `ID_MODALIDAD`, auditoría
en la forma del UML con JSON de formato fijo, roles solo `ADMINISTRADOR` y `CLIENTE`, y calendario
limitado a reservas.

**Archivos**

| Ruta | Qué es |
|---|---|
| `sql/oracle/10_ddl_sgcd_19.sql` | Esquema objetivo: 19 tablas con PK, FK, `UNIQUE`, `CHECK`, `DEFAULT`, índices, 16 secuencias, 18 triggers (16 de llave y `TRG_SGCD_CLIENTES_AU`/`AD`), más `SGCD_JSON_TEXTO` |
| `sql/oracle/11_catalogos_sgcd_19.sql` | Recinto único, 10 canchas (6 de fútbol 6, la grande y 3 sueltas), componentes 1-2-3, 3 deportes, 3 modalidades, 6 horarios, 82 bloques, 120 tarifas, 3 torneos y cuentas `admin`/`demo`/`nuevo` |
| `sql/oracle/13_pruebas_sgcd_19.sql` | 22 comprobaciones: objetos, coherencia de catálogos, ID automático, auditoría y negativas con su `ORA-` exacto |
| `sql/README.md` | Orden de ejecución nuevo, nota de `NLS_LANG` y regla de IDs por secuencia |
| `README.md`, `docs/entrega/ACCESO_DEMO.md` | Estado al 23-11 y cómo instalar el modelo de 19 tablas aparte de la v3 |
| `docs/diseno/2026-11-23-plan-19-tablas.md` | Fases 1 y 2 marcadas como hechas; notas técnicas del DDL |

**Verificación.** Esquema limpio `SGCD19` en `oracle-free/FREEPDB1`: 19 tablas, 16 secuencias,
18 triggers `ENABLED`, 0 objetos con error. `13_pruebas_sgcd_19.sql`: 22/22 en verde, incluida la
auditoría (`{"nombre":…,"telefono":null}` con el administrador 1), el rechazo de `OPERADOR`, el
bloque duplicado y el segundo pago. Los catálogos quedaron con 120 tarifas y 82 bloques.

**Hallazgo.** SQL*Plus dentro del contenedor corre sin locale: sin `NLS_LANG=AMERICAN_AMERICA.AL32UTF8`
y `LANG=C.UTF-8`, cada acento y la "·" se guardan como U+FFFD. Se documentó en `sql/README.md`; la
carga correcta se verificó con `DUMP` (`Fútbol` = 46,195,186,...).

**Siguiente.** `12_paquetes_sgcd_19.sql`: AUTH sobre `SGCD_USUARIOS`, clientes con auditoría, tarifas
por bloque, reservas con bloques consecutivos y regla de la cancha grande, torneos con nómina y
pago único, más los mantenedores de Ignacio con los nombres del modelo.

---

## 2026-11-23 (3) — Fase 3 por unidades: auth, clientes, mantenedores y tarifas

**Contexto.** Sesión con el protocolo `/calmadito`: cada unidad se declaró con su contrato, se
escribió sola y se revisó contra las cuatro lentes antes de abrir la siguiente. Se fijó como regla
que **no se toca ninguna tabla del UML**; todo se resuelve en paquetes y procedimientos.

**Archivos**

| Ruta | Unidad |
|---|---|
| `sql/oracle/12a_pkg_auth.sql` | 1. `SGCD_PKG_AUTH` sobre `SGCD_USUARIOS`: `crear_usuario`, `cuenta`, `cambiar_clave`, `cambiar_estado` |
| `sql/oracle/12b_pkg_clientes.sql` | 2. `SGCD_PKG_CLIENTES`: ficha idempotente por RUT, `registrar_cuenta_web` que engancha la ficha presencial, borrado con guardas |
| `sql/oracle/12c_mantenedores_catalogo.sql` | 3. Ignacio: deporte, modalidad, cancha y cancha–modalidad |
| `sql/oracle/12d_mantenedores_horario.sql` | 4. Ignacio: horario, bloque y administrador, con los renombres `DIA_SEMANA`, `HORA_APERTURA`, `HORA_CIERRE` |
| `sql/oracle/12e_mantenedor_tarifas.sql` | 5. Ignacio: tarifas, con los seis renombres sin sufijo `_TARIFA` |
| `sql/oracle/12f_pkg_tarifas.sql` | 6. `SGCD_PKG_TARIFAS`: `valor_bloque`, `cotizar` con total y detalle por hora |
| `sql/oracle/14_pruebas_paquetes_sgcd_19.sql` | Pruebas de las seis unidades, acumuladas |
| `sql/README.md`, `README.md` | Orden de ejecución nuevo y estado real de los paquetes |

**Decisiones de la sesión.** Pago anulado: una fila por reserva, anular y recobrar reutiliza la fila.
`reprogramar_reserva` entra en la unidad de reservas. Códigos de error: se mantienen los dos rangos
(`-20xxx` nuestros, `-208xx` de Ignacio). El cliente no cancela: lo justifica la política del recinto.
La programación de torneo recibe un rango y el paquete la divide en bloques. En el API, los códigos
conocidos usan su mensaje y sólo lo no mapeado cae al mensaje de Oracle.

**Verificación.** Esquema `SGCD19` sobre `oracle-free`: 19 tablas, 3 paquetes, 34 procedimientos,
1 función y 18 triggers, todos `VALID`. `13_pruebas_sgcd_19.sql` en verde (22 comprobaciones del DDL)
y `14_pruebas_paquetes_sgcd_19.sql` con **122 comprobaciones en verde** en las seis unidades.

**Hallazgos abiertos**

1. La regla de Ignacio "una tarifa iniciada no se modifica ni se borra" (`-20810`/`-20811`) impide
   editar las 120 tarifas del catálogo desde el panel. Para la fase 4: editar sólo franjas futuras y,
   para las iniciadas, ofrecer "desactivar y crear nueva".
2. `-20860…-20864` se comparten entre canchas y administradores, y las altas no validan el padre
   (`ORA-02291`). Se resuelve en el mapa de errores del API, sin renumerar.
3. `SGCD_PKG_CLIENTES` ya no tiene `buscar_ficha`: nada la usaba y `listar_fichas(texto)` la cubre.

**Siguiente.** Unidad 7: `SGCD_PKG_RESERVAS` con bloques consecutivos, candado ordenado del grupo
grande/1-2-3, cotización desde `SGCD_PKG_TARIFAS` y `reprogramar_reserva`.
