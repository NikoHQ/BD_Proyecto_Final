# Diseño — SGCD v3: cliente web, cuentas y torneos

**Fecha:** 2026-11-18 · **Proyecto:** INF324/ES3 — Sistema de Gestión de Centros Deportivos
**Entrega:** 2026-11-27
**Estado:** **aprobado el 2026-11-18** (decisiones D1–D7, revisión del builder resuelta, precio de
bloque de torneo = opción O4). Siguiente paso: plan de trabajo y construcción.

---

## 1. Intento y por qué

Hoy el sistema es un panel de administración y el cliente es una ficha que el recepcionista
escribe. El cambio de alcance del 2026-11-18 mueve dos cosas:

1. **El cliente final pasa a ser usuario del sistema.** Se registra en la web y reserva por sí
   mismo, sin dejar de existir el camino presencial, donde el recepcionista crea la ficha y hace
   la reserva.
2. **Aparece el módulo de torneos**: inscripción de equipos/participantes y arriendo de bloques
   de cancha para el evento. Sin partidos, sin fixture, sin resultados.

El objetivo es que un mismo cliente tenga **una sola historia** —reservas, pagos, membresía—
sin importar si la primera vez lo atendió una persona en el mesón o se registró desde la web.

## 2. Objetivos

- Ficha de cliente identificada por RUT, utilizable **sin cuenta** (caso mostrador = caso normal).
- Cuenta de acceso como accesorio opcional de la ficha, verificada en recepción.
- Un solo mecanismo de autenticación para clientes y personal.
- Un solo calendario de canchas: reserva normal y bloque de torneo compiten por las mismas horas.
- Regla de no solape por **cancha** y por **intervalo real**, no solo por hora de inicio.
- Toda regla de negocio en PL/SQL. PHP solo presentará.

## 3. No-objetivos

- Partidos, fixture, programación, resultados o tablas de posiciones.
- Pago de inscripción de torneo (ver §7.4: cómo añadirlo sin rehacer nada).
- Recuperación de contraseña por correo: no hay servidor de correo en el entorno.
- Pantallas del cliente final: las construye el equipo. Esta entrega expone las operaciones.
- Notificaciones, correo, SMS, pasarela de pago.
- Bloqueos **con fecha** (mantención programada, feriados). Decidido 2026-11-18: la mantención es
  un **estado indefinido de la cancha** (`ESTADO_CANCHA = 'MANTENCION'`), que bloquea toda reserva
  hasta que se levante a mano. No hay `BLOQUEO_CANCHA` ni rangos de fechas; la deuda D-4 se cierra
  como no aplicable.
- Expiración automática de reservas `PENDIENTE` (se documenta como deuda, no se implementa).

## 4. Anti-objetivos (esto sería un fracaso aunque compile)

- Que dos fichas distintas correspondan a la misma persona sin que nadie lo haya decidido.
- Que alguien vea el historial de otra persona por escribir un RUT.
- Que una reserva web pueda bloquear la mejor hora del recinto sin confirmación humana.
- Que el chequeo de solape dependa de la modalidad, o de que el bloque sea de torneo o no.
- Lógica de negocio en PHP que después haya que mudar a PL/SQL.

## 5. Restricciones

- ES3 exige **dos capas** con la lógica pesada en la base. La lámina se rotula 2 capas; el MVC
  dentro de PHP es organización interna del cliente, no una capa.
- Oracle AI Database 26ai Free 23.26.3 en Docker, PDB `FREEPDB1`, esquema `SGCD`.
- La base **no tiene datos operativos**: 0 clientes, 0 reservas, 0 pagos, 0 administradores.
  Solo catálogos (2 recintos, 7 instalaciones, 78 tarifas). Por eso se reconstruye, no se migra.
- PHP 8.5 + `oci8` + Apache ya operativos. AdminLTE 4.10.1 disponible en `package/`.
- Quedan 9 días.

## 6. Decisiones tomadas (Naiko, 2026-11-18)

| # | Decisión |
|---|---|
| D1 | El RUT identifica al cliente; `ID_CLIENTE` sigue siendo la llave interna. |
| D2 | El RUT identifica, **no autentica**: nunca es contraseña ni factor de acceso. |
| D3 | La cuenta de cliente nace `NO_VERIFICADA`; se verifica en recepción al confirmar. |
| D4 | El recepcionista puede crear la ficha antes de reservar; la web crea ficha o se engancha. |
| D5 | La reserva web nace `PENDIENTE`; el mostrador la `CONFIRMA`. |
| D6 | El bloque de cancha de un torneo **es una reserva**: un solo calendario. |
| D7 | El chequeo de solape es por cancha y por intervalo real, dentro del procedimiento. |

**Decisión del constructor, revisable:** las credenciales van en una tabla propia
(`SGCD_CREDENCIALES`) y no en un `USUARIO` único ni en columnas sueltas dentro de
`CLIENTES`/`ADMINISTRADORES`. Razón: el cliente sin cuenta es el caso normal, así que forzarlo a
tener login inventa datos; y con columnas separadas en dos tablas habría dos caminos de
autenticación. La credencial es un accesorio 1:1 de la ficha, con el mismo XOR que ya se usa en
`SGCD_PAGOS`.

## 7. Esquema v3

Se reconstruye el esquema completo (17 → **22** tablas). `sql/oracle/01..03` quedan como registro de
la v2; la v3 entra en archivos nuevos (§9).

### 7.1 `SGCD_CLIENTES` — cambia

- `RUT_CLIENTE NUMBER(8) NOT NULL` — solo dígitos, sin puntos ni guion.
- `DV_CLIENTE CHAR(1) NOT NULL` — `0`–`9` o `K`, en mayúscula.
- `UNIQUE (RUT_CLIENTE, DV_CLIENTE)` — clave natural.
- `CORREO_CLIENTE` gana `UNIQUE` (nullable: Oracle admite varios NULL) y normalización a minúsculas.
- `TELEFONO_CLIENTE` **no** es único: una familia comparte número. Se indexa y se usa como ayuda
  de búsqueda en la UI, no como constraint.
- `CLAVE_HASH_CLIENTE` **no** existe aquí: vive en la credencial.

Motivo del DV en columna aparte: el dígito verificador puede ser `K`, que no cabe en un `NUMBER`,
y es la única defensa barata contra un error de tipeo que crearía una segunda ficha de la misma
persona. Reemplazar `K` por `0` o descartar el DV destruye esa defensa y falsea el documento
impreso; el costo real de conservarlo es una columna `CHAR(1)` y una línea en la clave única.

### 7.2 `SGCD_CREDENCIALES` — nueva

| Columna | Regla |
|---|---|
| `ID_CREDENCIAL` | `IDENTITY` |
| `LOGIN_USUARIO` | `UNIQUE`, normalizado a mayúsculas. Cliente: `12345678-5`. Personal: nombre de usuario |
| `CLAVE_HASH` | `VARCHAR2(255)`, hash generado en PHP (`password_hash`), nunca la clave |
| `ROL` | `ADMINISTRADOR` / `OPERADOR` / `CLIENTE` |
| `ESTADO` | `ACTIVA` / `BLOQUEADA` / `INACTIVA` |
| `ID_CLIENTE` | FK, nulo o no |
| `ID_ADMINISTRADOR` | FK, nulo o no |
| `VERIFICADA_EN` | `TIMESTAMP` nulo; `NULL` = cuenta no verificada |
| `VERIFICADA_POR` | FK a `ADMINISTRADORES`, nula |
| `UNIQUE (ID_CLIENTE)` | una cuenta por ficha como máximo |

Constraints:
- XOR de dueño: exactamente uno de `ID_CLIENTE` / `ID_ADMINISTRADOR` no nulo.
- `ROL = 'CLIENTE'` ⟺ `ID_CLIENTE` no nulo. Personal siempre tiene `VERIFICADA_EN` no nulo.

Consecuencia: `SGCD_ADMINISTRADORES` pierde `USUARIO_ADMINISTRADOR`, `CLAVE_HASH_ADMINISTRADOR` y
`PERFIL_ADMINISTRADOR`; el perfil pasa a ser el `ROL` de su credencial. Una sola autenticación
para las dos poblaciones.

**Dónde se verifica la clave.** El hash se genera y se compara en PHP (`password_hash` /
`password_verify`); la base guarda el hash y nunca ve la clave en claro. No es lógica pesada: es
una comparación criptográfica, y hacerla en PL/SQL obligaría a `DBMS_CRYPTO` sin ganar nada. La
base impone lo que sí importa: estado, rol, dueño y verificación. Los hashes de los datos demo se
precalculan una vez y se pegan como constantes en `06_datos_catalogos_v3.sql`, con la clave en
claro documentada en el encabezado del archivo (es un entorno de laboratorio).

**Qué permite una cuenta no verificada:** reservar (la reserva queda `PENDIENTE`, D5). **Qué no
permite:** ver historial, pagos, membresía ni puntos de la ficha. La verificación la hace un
administrador; en el mostrador ocurre en el mismo acto en que confirma la reserva.

### 7.3 `SGCD_RESERVAS` — cambia

- `TIPO_RESERVA VARCHAR2(10) NOT NULL DEFAULT 'NORMAL'` ∈ `NORMAL`, `TORNEO`.
- `ID_TORNEO NUMBER(10) NULL` FK a `SGCD_TORNEOS`; obligatorio si `TIPO_RESERVA = 'TORNEO'`,
  prohibido si es `NORMAL`.
- `ORIGEN_RESERVA VARCHAR2(10) NOT NULL` ∈ `MOSTRADOR`, `WEB`; `MOSTRADOR` exige
  `ID_ADMINISTRADOR` no nulo, `WEB` lo exige nulo.
- `ID_CLIENTE` admite nulo **solo** cuando `TIPO_RESERVA = 'TORNEO'` (el club arrienda su propio
  gimnasio para el evento: no hay cliente al que cobrarle). `ID_MODALIDAD` sigue **obligatoria**
  siempre: el bloque se tarifa con la modalidad del torneo, así que no existe tarifa sin modalidad.
- El índice único de bloque **deja de incluir `ID_MODALIDAD`**: hoy permite pisar la misma cancha
  a la misma hora cambiando de deporte. Clave nueva: `(ID_CANCHA, INICIO_RESERVA)`, emulando el
  parcial con `CASE WHEN ESTADO_RESERVA <> 'CANCELADA' THEN ... END`.
- `ESTADO_RESERVA` conserva los cuatro valores actuales; `PENDIENTE` **bloquea** el horario.

### 7.4 `SGCD_TORNEOS`, `SGCD_EQUIPOS`, `SGCD_JUGADORES`, `SGCD_EQUIPO_JUGADORES` — nuevas

- `SGCD_TORNEOS`: `ID_TORNEO`, `ID_RECINTO`, `ID_MODALIDAD`, `NOMBRE_TORNEO`,
  `FECHA_INICIO_TORNEO`, `FECHA_FIN_TORNEO`, `CUPOS_EQUIPOS_TORNEO`,
  `DESCUENTO_PORCENTAJE_TORNEO NUMBER(5,2) DEFAULT 0` (0–100, §7.6),
  `ESTADO_TORNEO` ∈ `PLANIFICADO`/`EN_CURSO`/`FINALIZADO`/`CANCELADO`.
- `SGCD_EQUIPOS`: `ID_EQUIPO`, `ID_TORNEO`, `NOMBRE_EQUIPO`, `ID_CLIENTE_RESPONSABLE` (capitán,
  que además es el primer jugador), `FECHA_INSCRIPCION_EQUIPO`,
  `ESTADO_EQUIPO` ∈ `INSCRITO`/`RETIRADO`; `UNIQUE (ID_TORNEO, NOMBRE_EQUIPO)`.
- `SGCD_JUGADORES`: registro liviano de quien juega torneos, **sin ficha de cliente**.
  `ID_JUGADOR`, `RUT_JUGADOR NUMBER(8)`, `DV_JUGADOR CHAR(1)`, `NOMBRE_JUGADOR`,
  `ID_CLIENTE NULL` (enlace si ese RUT ya es cliente); `UNIQUE (RUT_JUGADOR, DV_JUGADOR)`.
- `SGCD_EQUIPO_JUGADORES`: PK `(ID_EQUIPO, ID_JUGADOR)`; un jugador no puede estar dos veces en el
  mismo equipo. Un torneo individual se modela con equipos de un jugador, así que no hace falta una
  estructura aparte para "participante suelto".

**Regla de identidad (decidido 2026-11-19).** El capitán inscribe a sus jugadores con **nombre y
RUT**; no se crea una ficha por jugador. La fila de `SGCD_JUGADORES` es la identidad del jugador,
con el RUT como clave natural, y se reutiliza en torneos posteriores sin volver a teclearlo. Si el
RUT ya corresponde a un cliente, `ID_CLIENTE` se rellena en el acto y el nombre se toma de la ficha:
nadie queda duplicado ni con dos grafías, y si más adelante ese jugador se hace socio, el enlace ya
existe. Es el mismo principio de §7.2 aplicado hacia el otro lado: la identidad de una persona
nunca es una fila de inscripción.

Pago de inscripción: **no se modela en esta entrega**. Cuando se necesite, `SGCD_PAGOS` gana
`ID_EQUIPO` como cuarto brazo del XOR ya existente; no toca ninguna otra tabla.

### 7.5 Índices

Los 14 de la v2 se mantienen. Se agregan: `SGCD_CREDENCIALES (ID_CLIENTE)`,
`(ID_ADMINISTRADOR)`, `SGCD_EQUIPOS (ID_TORNEO)`, `SGCD_EQUIPO_JUGADORES (ID_JUGADOR)`,
`SGCD_JUGADORES (ID_CLIENTE)`,
`SGCD_RESERVAS (ID_TORNEO)`, `SGCD_CLIENTES (TELEFONO_CLIENTE)`, `(CORREO_CLIENTE)`.

### 7.6 Precio del bloque de torneo — **decidido: O4** (2026-11-18)

Las opciones que se discutieron:

| # | Opción | A favor | En contra |
|---|---|---|---|
| O1 | Tarifa siempre | Una sola regla, cero ramas, el importe queda registrado | Un torneo interno del club se cobra a sí mismo (asiento contable vacío) |
| O2 | Exento si es torneo (importe 0) | Lo que la gente espera de un torneo interno | Se pierde el valor de esas horas; un organizador externo no puede pagar |
| O3 | Precio negociado por bloque (parámetro) | Cubre eventos externos y acuerdos | Un parámetro libre se presta para dedo; hay que auditarlo |
| O4 | **Tarifa + descuento % en el torneo** (0–100) | Cubre los tres casos (exento = 100 %) sin parámetro libre ni ramas en el procedimiento | Una columna más y una multiplicación |

Recomendación: **O4**. `SGCD_TORNEOS.DESCUENTO_PORCENTAJE_TORNEO NUMBER(5,2) DEFAULT 0`, y
`crear_reserva` gana un parámetro acotado `p_descuento_porcentaje NUMBER DEFAULT 0` con
`CHECK` de rango: el importe sigue saliendo de la tarifa, `× (1 − descuento/100)`, y nunca se
teclea. `arrendar_bloque` le pasa el porcentaje del torneo. El porcentaje vive donde corresponde
—en el evento, no en cada bloque— y el procedimiento central gana una multiplicación, no una rama.

## 8. Servicios (PL/SQL)

| Paquete | Procedimientos |
|---|---|
| `SGCD_PKG_CLIENTES` | `normalizar_rut`, `validar_rut` (módulo 11), `crear_ficha`, `buscar_ficha` (RUT / teléfono / correo) |
| `SGCD_PKG_AUTH` | `crear_credencial`, `verificar_cuenta(id_cred, id_admin)`, `obtener_credencial(login)` (devuelve hash, rol, estado, verificación, dueño) |
| `SGCD_PKG_TARIFAS` | `tarifa_vigente(cancha, modalidad, fecha_hora) → valor_hora` |
| `SGCD_PKG_RESERVAS` | `crear_reserva`, `confirmar_reserva`, `cancelar_reserva`, `consultar_disponibilidad` |
| `SGCD_PKG_TORNEOS` | `crear_torneo`, `inscribir_equipo` (cupos con bloqueo), `registrar_jugador` (alta o reutilización por RUT), `agregar_jugador`, `arrendar_bloque` (llama a `crear_reserva` con `TIPO_RESERVA='TORNEO'`) |
| `SGCD_PKG_CONSULTAS` | `historial_cliente(id_cred)`, `estado_cuenta(id_cred)` — rechazan si la cuenta no está verificada |

### 8.0 Identidad del que llama

Ningún procedimiento confía en el `ID_CLIENTE` que le pasen. Las operaciones que actúan sobre
datos de un cliente reciben `p_id_cred` —la credencial de quien llama— y resuelven el dueño dentro
del paquete: un cliente solo cancela y consulta lo suyo; un administrador puede todo. Esa es la
casa de la regla "cuenta no verificada no ve historial" (§7.2), y sin ella la afirmación de dos
capas se cae en la primera pregunta incómoda.

### 8.1 `crear_reserva` — el procedimiento central

1. Rechaza `fin <= inicio`.
2. Rechaza cancha en `MANTENCION` o `INACTIVA`, y horario fuera de la ventana del recinto.
3. `SELECT ... FROM SGCD_CANCHAS WHERE ID_CANCHA = p_cancha FOR UPDATE` — serializa la cancha
   para que dos sesiones simultáneas no se cuelen entre el chequeo y el insert.
4. Conflicto si existe fila con `ID_CANCHA = p_cancha` y `ESTADO_RESERVA <> 'CANCELADA'` y
   `INICIO_RESERVA < p_fin` y `TERMINO_RESERVA > p_inicio`. **Sin `ID_MODALIDAD` en la condición.**
5. Tarifa: `SGCD_PKG_TARIFAS.tarifa_vigente(cancha, modalidad, inicio)`; si no hay banda, error
   explícito. `p_importe` **no** es parámetro: el importe siempre se deriva. Si se pasa
   `p_descuento_porcentaje` (0–100, default 0, opción O4 §7.6), se aplica `× (1 − desc/100)`; es el
   único caso en que el importe no es la tarifa pura, y sigue sin teclearse a mano.
6. Inserta con `ESTADO_RESERVA = p_estado` (`PENDIENTE` si origen web, `CONFIRMADA` si mostrador).

Escritura de la lógica: una función privada `hay_conflicto(cancha, inicio, fin)` que usan tanto
`crear_reserva` como `consultar_disponibilidad`, para que la pantalla y el insert nunca discrepen.

### 8.2 Contrato de `crear_ficha`

Si `(RUT, DV)` ya existe, devuelve el `ID_CLIENTE` existente con `p_creada = FALSE` y **no modifica
nada** de la ficha: la web nunca sobreescribe datos de una ficha existente, ni siquiera campos
vacíos. Editar una ficha es del recepcionista. El registro web que cae en una ficha existente solo
crea una credencial `NO_VERIFICADA` sobre ella, y por §7.2 no ve historial hasta que un
administrador la verifique.

### 8.3 `confirmar_reserva` no verifica la cuenta

Son dos actos distintos: confirmar un bloque y responder por la identidad de una persona. El panel
los ofrece en la misma pantalla, pero como dos llamadas (`confirmar_reserva`, `verificar_cuenta`).
Si estuvieran acoplados, cada confirmación de mostrador regalaría acceso al historial de la ficha.

### 8.4 Inscripción de un equipo, en orden

1. `crear_torneo(...)` — lo hace un administrador; el torneo nace `PLANIFICADO`.
2. `inscribir_equipo(id_torneo, nombre, id_cred_capitan)` — exige torneo en `PLANIFICADO`, bloquea
   la fila del torneo (`FOR UPDATE`), cuenta los equipos `INSCRITO` contra `CUPOS_EQUIPOS_TORNEO`,
   crea el equipo y registra al capitán como primer jugador.
3. `agregar_jugador(id_equipo, rut, dv, nombre)` — valida el DV (módulo 11), exige torneo
   `PLANIFICADO`, rechaza si ese jugador ya está en el equipo o en otro equipo del mismo torneo,
   resuelve `ID_CLIENTE` por RUT y, si existe, copia el nombre de la ficha e ignora el tecleado.
4. `arrendar_bloque(...)` — los bloques de cancha del evento, con el descuento del torneo.

Retirar un equipo (`ESTADO_EQUIPO = 'RETIRADO'`) libera su cupo y **no** borra a sus jugadores:
la inscripción se desactiva, no se destruye.

## 9. Entregables y orden de carga

| Archivo | Contenido |
|---|---|
| `sql/oracle/04_ddl_v3.sql` | esquema completo v3, autocontenido, con `DROP ... CASCADE CONSTRAINTS` al inicio |
| `sql/oracle/05_paquetes_plsql.sql` | especificaciones y cuerpos de los seis paquetes |
| `sql/oracle/06_datos_catalogos_v3.sql` | los catálogos de `03` adaptados (recintos, instalaciones, deportes, modalidades, horarios, tarifas) |
| `sql/oracle/07_datos_operativos.sql` | clientes, credenciales, membresías, reservas, pagos, implementos y torneos de ejemplo; re-ejecutable |
| `sql/oracle/08_pruebas_v3.sql` | pruebas negativas/positivas, cada una con su resultado esperado |

Los archivos `01..03` no se tocan: quedan como evidencia de la v2.

## 10. Pruebas

Se conservan las 26 de `02_pruebas_integridad.sql` y se agregan como mínimo:

| Caso | Esperado |
|---|---|
| Solape exacto (19:00–20:00 vs 19:00–20:00) | rechazo |
| Solape parcial (19:00–20:00 vs 19:30–20:30) | rechazo |
| Intervalo contenido (19:00–21:00 vs 19:30–20:00) | rechazo |
| Adyacente (19:00–20:00 vs 20:00–21:00) | acepta |
| Misma cancha, **distinta modalidad**, mismo horario | rechazo (bug actual: acepta) |
| Reserva `CANCELADA` en el horario | acepta |
| Bloque de torneo contra reserva normal | rechazo |
| Reserva web `PENDIENTE` en el horario | rechazo para otro |
| `fin <= inicio` | rechazo |
| Cancha en `MANTENCION` | rechazo |
| RUT con DV inválido | rechazo |
| RUT duplicado | rechazo |
| Correo duplicado | rechazo |
| Credencial sin dueño / con dos dueños | rechazo |
| Segunda credencial para la misma ficha | rechazo |
| Rol `CLIENTE` sin `ID_CLIENTE` | rechazo |
| Login duplicado | rechazo |
| Concurrencia: dos sesiones al mismo bloque | una gana, la otra recibe error (dos terminales y transcripción guardada en `docs/`; sin arnés automatizado) |
| Jugador de torneo con RUT que no es cliente | acepta; **cero** filas nuevas en `SGCD_CLIENTES` |
| Jugador con RUT de un cliente existente | enlaza `ID_CLIENTE` y copia el nombre de la ficha |
| RUT repetido en el mismo equipo | rechazo |
| Mismo jugador en dos equipos del mismo torneo | rechazo |
| DV inválido en un jugador | rechazo |
| Inscripción sobre `CUPOS_EQUIPOS_TORNEO` | rechazo |
| Inscripción con el torneo en `EN_CURSO` | rechazo |

## 11. Lo que queda al constructor

- Nombres definitivos de columnas y tipos exactos de cada tabla nueva.
- Forma de `consultar_disponibilidad` (rango de fechas y granularidad de 30 o 60 minutos se
  decide al escribir la firma; el diseño no la fija).
- Normalización del teléfono chileno (`+56 9 ...` a formato canónico) y su función.
- Formato del reporte de error de conflicto que devuelve el procedimiento a la pantalla.
- Estructura de la capa PHP y del login (fuera de esta entrega, pero condicionada a §7.2).

## 12. Revisión independiente (2026-11-18)

Un ingeniero Oracle que no participó en la conversación leyó el documento para planificar desde
él. Siete preguntas, siete resoluciones:

| # | Pregunta del revisor | Resolución |
|---|---|---|
| 1 | ¿Cuánto cuesta un bloque de torneo y quién fija el precio? | Se tarifa con la modalidad del torneo; `ID_MODALIDAD` pasa a obligatoria siempre e `p_importe` no es parámetro (§7.3, §8.1). |
| 2 | ¿La base hace cumplir "cuenta no verificada no ve historial"? | Sí: `p_id_cred` en las operaciones y `SGCD_PKG_CONSULTAS` con el chequeo dentro (§8.0). |
| 3 | ¿Dónde se verifica la clave? | En PHP; la base guarda el hash. Los hashes demo se precalculan (§7.2). |
| 4 | Si el RUT ya tiene ficha, ¿se engancha o se rechaza? | Se engancha, sin tocar la ficha, y la credencial nace `NO_VERIFICADA` (§8.2). |
| 5 | ¿21 o 22 tablas? | 21. La 22 era un error mío al contar. `BLOQUEO_CANCHA` queda fuera de alcance (§3). |
| 6 | ¿`confirmar_reserva` verifica la cuenta? | No: dos llamadas distintas, misma pantalla (§8.3). |
| 7 | ¿Qué evidencia para la prueba de concurrencia? | Dos terminales y transcripción guardada; sin arnés (§10). |
| 8 | ¿Entra el bloqueo por mantención/feriados (D-4)? | No: `MANTENCION` es un estado indefinido de la cancha, sin fechas (§3). |

Pendiente de Naiko: **nada**. Las siete preguntas del revisor quedaron resueltas y la opción O4
(§7.6) fue aprobada el 2026-11-18.
