# Glosario y diccionario de datos — SGCD

**Qué es este archivo.** La llave para leer la base sin adivinar: qué significa cada prefijo y
sufijo de los nombres, qué valores admite cada columna de estado, y qué guarda cada tabla.
**Para quién:** cualquiera del equipo que abra el esquema, y para la defensa.
**Estado:** describe el esquema **v3** (21 tablas). Los nombres de las tablas nuevas son los
canónicos; si alguna vez discrepan, manda `04_ddl_v3.sql`.

---

## 1. Cómo leer los nombres

### 1.1 Prefijos de objeto

| Marca | Significa | Ejemplo |
|---|---|---|
| `SGCD_` | todo objeto del sistema lleva el prefijo del proyecto | `SGCD_RESERVAS` |
| plural | una tabla es un conjunto de filas, no una fila | `SGCD_CLIENTES`, no `SGCD_CLIENTE` |
| `PK_` | restricción de llave primaria | `PK_SGCD_RESERVAS` |
| `FK_` | llave foránea | `FK_SGCD_RES_CM` |
| `UQ_` | restricción `UNIQUE` (clave natural) | `UQ_SGCD_RECINTO_NOMBRE` |
| `UX_` | índice único | `UX_SGCD_RESERVAS_BLOQUE` |
| `IX_` | índice no único (velocidad, no regla) | `IX_SGCD_RESERVAS_CLIENTE` |
| `CK_` | restricción `CHECK` (dominio o rango) | `CK_SGCD_PAGO_ORIGEN` |

### 1.2 Prefijos y sufijos de columna

| Marca | Significa | Ejemplo |
|---|---|---|
| `ID_` | llave. Si apunta a otra tabla, es llave foránea | `ID_CLIENTE` |
| sufijo `_CLIENTE`, `_RESERVA`, `_CANCHA`… | **a qué entidad pertenece el dato**, no el dueño de la fila | `NOMBRE_CLIENTE` = nombre del cliente |
| `TIPO_` | clasificación estable; no debería cambiar en la vida de la fila | `TIPO_RESERVA` |
| `ESTADO_` | estado del ciclo de vida; cambia con el tiempo | `ESTADO_RESERVA` |
| `FECHA_` | día calendario (`DATE`) | `FECHA_PAGO` |
| `..._EN` | instante con hora (`TIMESTAMP`) | `CREADO_EN_RESERVA` |
| `INICIO_`, `TERMINO_` | extremos de un intervalo de tiempo | `INICIO_RESERVA` |
| `IMPORTE_`, `VALOR_`, `PRECIO_` | dinero en CLP, siempre `NUMBER(12,2)` | `IMPORTE_PAGO` |
| `_PORCENTAJE` | valor entre 0 y 100 | `DESCUENTO_PORCENTAJE_PLAN` |
| `_HASH` | derivado irreversible de un secreto; **nunca** la clave | `CLAVE_HASH_CREDENCIAL` |
| `_DETALLE` | línea de un documento padre | `CANTIDAD_DETALLE` |
| `VIGENTE_`, `EXISTENCIAS_` | rangos de validez y saldos | `VIGENTE_DESDE_TARIFA` |

### 1.3 Tipos por convención

| Dato | Tipo | Nota |
|---|---|---|
| Llaves | `NUMBER(10)` `IDENTITY` | identidad interna; no se muestra al usuario |
| Dinero | `NUMBER(12,2)` | CLP con dos decimales, aunque el peso no los use |
| Superficie | `NUMBER(8,2)` | m² |
| Hora del día | `CHAR(5)` | `'HH:MM'` en 24 h, validada con `REGEXP_LIKE` |
| Día de la semana | `NUMBER(1)` | `1` = lunes … `7` = domingo |
| Instante | `TIMESTAMP` | fecha + hora |
| Día | `DATE` | solo fecha |
| RUT | `NUMBER(8)` + `CHAR(1)` | cuerpo sin puntos + dígito verificador |

---

## 2. Dominios: valores permitidos

Si una columna no aparece aquí, es texto libre con un largo máximo.

| Tabla | Columna | Valores |
|---|---|---|
| `SGCD_RECINTOS` | `ESTADO_RECINTO` | `ACTIVO` · `INACTIVO` |
| `SGCD_DEPORTES` | `ESTADO_DEPORTE` | `ACTIVO` · `INACTIVO` |
| `SGCD_CLIENTES` | `ESTADO_CLIENTE` | `ACTIVO` · `INACTIVO` |
| `SGCD_ADMINISTRADORES` | `ESTADO_ADMINISTRADOR` | `ACTIVO` · `INACTIVO` |
| `SGCD_CREDENCIALES` | `ROL_CREDENCIAL` | `ADMINISTRADOR` · `OPERADOR` · `CLIENTE` |
| `SGCD_CREDENCIALES` | `ESTADO_CREDENCIAL` | `ACTIVA` · `BLOQUEADA` · `INACTIVA` |
| `SGCD_PLANES_MEMBRESIA` | `ESTADO_PLAN` | `ACTIVO` · `INACTIVO` |
| `SGCD_ARTICULOS` | `ESTADO_ARTICULO` | `ACTIVO` · `INACTIVO` |
| `SGCD_CANCHAS` | `TIPO_CANCHA` | `CANCHA` · `GIMNASIO` · `SALA` · `PISCINA` |
| `SGCD_CANCHAS` | `ESTADO_CANCHA` | `DISPONIBLE` · `MANTENCION` · `INACTIVA` |
| `SGCD_MODALIDADES` | `ESTADO_MODALIDAD` | `ACTIVO` · `INACTIVO` |
| `SGCD_TARIFAS` | `ESTADO_TARIFA` | `ACTIVA` · `INACTIVA` |
| `SGCD_MEMBRESIAS` | `ESTADO_MEMBRESIA` | `ACTIVA` · `VENCIDA` · `CANCELADA` |
| `SGCD_MOVIMIENTOS_PUNTOS` | `TIPO_MOVIMIENTO` | `GANADO` · `CANJEADO` · `AJUSTE` |
| `SGCD_RESERVAS` | `ESTADO_RESERVA` | `PENDIENTE` · `CONFIRMADA` · `CANCELADA` · `COMPLETADA` |
| `SGCD_RESERVAS` | `TIPO_RESERVA` | `NORMAL` · `TORNEO` |
| `SGCD_RESERVAS` | `ORIGEN_RESERVA` | `MOSTRADOR` · `WEB` |
| `SGCD_TORNEOS` | `ESTADO_TORNEO` | `PLANIFICADO` · `EN_CURSO` · `FINALIZADO` · `CANCELADO` |
| `SGCD_EQUIPOS` | `ESTADO_EQUIPO` | `INSCRITO` · `RETIRADO` |
| `SGCD_OPERACIONES_IMPLEMENTOS` | `TIPO_OPERACION` | `VENTA` · `ARRIENDO` |
| `SGCD_PAGOS` | `MEDIO_PAGO` | `EFECTIVO` · `DEBITO` · `CREDITO` · `TRANSFERENCIA` |

---

## 3. Diccionario por área

### 3.1 Recintos e instalaciones

**`SGCD_RECINTOS`** — el establecimiento físico. Un recinto tiene instalaciones y un horario.
| Columna | Significado |
|---|---|
| `ID_RECINTO` | llave interna |
| `NOMBRE_RECINTO` + `COMUNA_RECINTO` | nombre visible; el par es único |
| `DIRECCION_RECINTO`, `TELEFONO_RECINTO` | contacto |
| `ESTADO_RECINTO` | si el recinto opera |
| `CREADO_EN_RECINTO` | cuándo se dio de alta |

**`SGCD_CANCHAS`** — la instalación reservable. `CANCHA` es solo un tipo: también gimnasio, sala
y piscina viven aquí.
| Columna | Significado |
|---|---|
| `ID_CANCHA` | llave interna |
| `ID_RECINTO` | a qué recinto pertenece |
| `NOMBRE_CANCHA` | único **dentro** del recinto |
| `TIPO_CANCHA` | cancha / gimnasio / sala / piscina |
| `SUPERFICIE_CANCHA` | m², opcional |
| `ESTADO_CANCHA` | `MANTENCION` bloquea toda reserva mientras dure, sin fecha de término; se levanta a mano |

**`SGCD_HORARIOS`** — ventana de atención **del recinto**, por día de la semana.
| Columna | Significado |
|---|---|
| `ID_HORARIO` | llave interna |
| `ID_RECINTO` + `DIA_SEMANA_HORARIO` | un solo horario por recinto y día |
| `HORA_APERTURA_HORARIO`, `HORA_CIERRE_HORARIO` | apertura y cierre, `'HH:MM'`, apertura < cierre |

### 3.2 Deporte, modalidad y tarifas

**`SGCD_DEPORTES`** — fútbol, pádel, básquetbol…

**`SGCD_MODALIDADES`** — la variante jugable de un deporte: *Fútbol 5*, *Fútbol 7*,
*Pádel dobles*, *Voleibol 6x6*. Cuelga de un deporte y su nombre es único dentro de él.

**`SGCD_CANCHAS_MODALIDADES`** — qué modalidades admite cada instalación. Tabla puente con PK
compuesta `(ID_CANCHA, ID_MODALIDAD)`; sin ella no se puede tarifar ni reservar.

**`SGCD_TARIFAS`** — precio por hora de una modalidad en una instalación, por banda horaria.
| Columna | Significado |
|---|---|
| `ID_CANCHA` + `ID_MODALIDAD` | la combinación tarifada |
| `DIA_SEMANA_TARIFA` | 1–7 |
| `HORA_DESDE_TARIFA`, `HORA_HASTA_TARIFA` | banda horaria; desde < hasta |
| `VIGENTE_DESDE_TARIFA`, `VIGENTE_HASTA_TARIFA` | desde cuándo rige el precio; `NULL` hasta = vigente |
| `VALOR_HORA_TARIFA` | CLP por hora, > 0 |

**Regla:** la tarifa aplicable se busca por cancha + modalidad + día + hora de inicio. Si no hay
banda, la reserva falla con error explícito: no existe "precio por defecto".

### 3.3 Personas y acceso

**`SGCD_CLIENTES`** — la ficha comercial. Existe **sin cuenta**, y ese es el caso normal.
| Columna | Significado |
|---|---|
| `ID_CLIENTE` | llave interna, la que usan las demás tablas |
| `RUT_CLIENTE` | cuerpo del RUT, solo dígitos |
| `DV_CLIENTE` | dígito verificador, `0`–`9` o `K`; el par es la clave natural |
| `NOMBRE_CLIENTE` | nombre completo |
| `CORREO_CLIENTE` | único cuando viene; normalizado a minúsculas |
| `TELEFONO_CLIENTE` | **no** único: una familia comparte número |
| `ESTADO_CLIENTE` | si la ficha está vigente |
| `CREADO_EN_CLIENTE` | alta de la ficha |

**`SGCD_ADMINISTRADORES`** — el personal del recinto. Datos personales solamente: su acceso está
en `SGCD_CREDENCIALES`. El antiguo `PERFIL` es hoy el rol de la credencial.

**`SGCD_CREDENCIALES`** — el acceso al sistema. Una credencial pertenece **a exactamente un**
cliente o a un administrador.
| Columna | Significado |
|---|---|
| `ID_CREDENCIAL` | llave interna |
| `LOGIN_CREDENCIAL` | lo que se escribe al entrar; único. Cliente: `12345678-5`. Personal: usuario |
| `CLAVE_HASH_CREDENCIAL` | hash bcrypt; la clave en claro nunca se guarda |
| `ROL_CREDENCIAL` | qué puede hacer |
| `ESTADO_CREDENCIAL` | `BLOQUEADA` impide entrar sin borrar nada |
| `ID_CLIENTE` / `ID_ADMINISTRADOR` | dueño; exactamente uno de los dos |
| `FECHA_VERIFICACION_CREDENCIAL` | `NULL` = cuenta **no verificada**: puede reservar, no puede ver historial |
| `ID_ADMINISTRADOR_VERIFICADOR` | quién respondió por la identidad |

**Reglas:** una sola credencial por ficha (`UNIQUE ID_CLIENTE`); rol `CLIENTE` exige
`ID_CLIENTE`; el personal siempre nace verificado.

### 3.4 Membresías y puntos

**`SGCD_PLANES_MEMBRESIA`** — el producto: nombre, duración en días, beneficio, descuento %.

**`SGCD_MEMBRESIAS`** — un cliente suscrito a un plan, con fecha de inicio y término. Estados:
`ACTIVA`, `VENCIDA`, `CANCELADA`. La vigencia contra la fecha de una reserva la valida PL/SQL, no
el DDL.

**`SGCD_MOVIMIENTOS_PUNTOS`** — libro de puntos: cada fila suma o resta. `CANTIDAD_MOVIMIENTO`
distinto de cero; el signo lo pone el tipo (`GANADO` positivo, `CANJEADO` negativo). El saldo es
una suma, nunca una columna.

### 3.5 Reservas — el corazón

**`SGCD_RESERVAS`** — **el único calendario del sistema**. Una reserva de mostrador, una reserva
web y el bloque de cancha arrendado para un torneo son filas de esta tabla.

| Columna | Significado |
|---|---|
| `ID_RESERVA` | llave interna |
| `ID_CLIENTE` | a nombre de quién; `NULL` solo si es bloque de torneo del propio club |
| `ID_ADMINISTRADOR` | quién la tomó en el mesón; `NULL` si vino de la web |
| `ID_CANCHA` | qué instalación ocupa |
| `ID_MODALIDAD` | bajo qué reglamento se juega; siempre obligatoria |
| `INICIO_RESERVA`, `TERMINO_RESERVA` | intervalo real; término > inicio |
| `IMPORTE_ACORDADO_RESERVA` | lo que se cobra: tarifa de la banda × (1 − descuento del torneo). Nunca se teclea |
| `ESTADO_RESERVA` | `PENDIENTE` (web, sin confirmar) **bloquea igual** · `CONFIRMADA` · `CANCELADA` (libera) · `COMPLETADA` |
| `TIPO_RESERVA` | `NORMAL` o `TORNEO` |
| `ID_TORNEO` | obligatorio si el tipo es `TORNEO`; prohibido si es `NORMAL` |
| `ORIGEN_RESERVA` | `MOSTRADOR` (exige administrador) o `WEB` (lo prohíbe) |
| `CREADO_EN_RESERVA` | cuándo se registró |

**Regla que no vive en el DDL:** dos reservas no pueden **cruzarse** en la misma cancha. El índice
único solo atrapa inicios idénticos; el cruce parcial lo detecta `SGCD_PKG_RESERVAS` comparando
intervalos. Una reserva `CANCELADA` no bloquea.

### 3.6 Torneos — sin partidos

**`SGCD_TORNEOS`** — el evento.
| Columna | Significado |
|---|---|
| `ID_TORNEO` | llave interna |
| `ID_RECINTO`, `ID_MODALIDAD` | dónde y de qué deporte |
| `NOMBRE_TORNEO` | nombre del evento |
| `FECHA_INICIO_TORNEO`, `FECHA_FIN_TORNEO` | cuándo se juega |
| `CUPOS_EQUIPOS_TORNEO` | máximo de equipos inscritos |
| `DESCUENTO_PORCENTAJE_TORNEO` | 0–100; se aplica al arriendo de cada bloque del torneo. `100` = torneo exento |
| `ESTADO_TORNEO` | planificado / en curso / finalizado / cancelado |

**`SGCD_EQUIPOS`** — la inscripción. Un torneo individual se modela con equipos de un jugador.
| Columna | Significado |
|---|---|
| `ID_EQUIPO` | llave interna |
| `ID_TORNEO` | a qué torneo se inscribe |
| `NOMBRE_EQUIPO` | único dentro del torneo |
| `ID_CLIENTE_RESPONSABLE` | el cliente que responde por el equipo |
| `FECHA_INSCRIPCION_EQUIPO` | cuándo se inscribió |
| `ESTADO_EQUIPO` | `INSCRITO` o `RETIRADO` |

**`SGCD_EQUIPO_JUGADORES`** — quiénes juegan. PK `(ID_EQUIPO, ID_CLIENTE)`: un cliente no puede
estar dos veces en el mismo equipo, sí en dos torneos distintos.

**El arriendo de cancha del torneo no es una tabla aparte:** son filas de `SGCD_RESERVAS` con
`TIPO_RESERVA = 'TORNEO'` e `ID_TORNEO` apuntando al evento.

### 3.7 Caja e implementos

**`SGCD_ARTICULOS`** — lo que se vende o se arrienda: balones, petos, paletas.

**`SGCD_OPERACIONES_IMPLEMENTOS`** — cabecera de una venta o un arriendo de implementos a un
cliente, con su importe total.

**`SGCD_DETALLES_IMPLEMENTOS`** — líneas de esa operación: artículo, cantidad, precio acordado,
entrega y devolución (prevista y real).

**`SGCD_PAGOS`** — un pago apunta a **exactamente un origen**: una reserva, una operación de
implementos o una membresía. Ese XOR es la restricción `CK_SGCD_PAGO_ORIGEN`; si algún día hay
pago de inscripción a torneo, se agrega un cuarto brazo y nada más.

---

## 4. Mapa de relaciones

```
RECINTOS ──┬── CANCHAS ──┬── CANCHAS_MODALIDADES ──┬── TARIFAS
           │             │                          └── RESERVAS ──┬── PAGOS
           ├── HORARIOS  │                                          └── TORNEOS ── EQUIPOS ── EQUIPO_JUGADORES
           └── TORNEOS   │
DEPORTES ── MODALIDADES ─┘

CLIENTES ──┬── CREDENCIALES  (1:0..1, opcional)
           ├── MEMBRESIAS ── PLANES_MEMBRESIA
           ├── MOVIMIENTOS_PUNTOS
           ├── RESERVAS
           ├── EQUIPOS
           ├── EQUIPO_JUGADORES
           └── OPERACIONES_IMPLEMENTOS ── DETALLES_IMPLEMENTOS ── ARTICULOS

ADMINISTRADORES ──┬── CREDENCIALES (1:0..1)
                  ├── RESERVAS (quién tomó la reserva en el mesón)
                  └── CREDENCIALES (quién verificó una cuenta)
```

---

## 5. Lo que no está en este glosario

- **La lógica.** Validar RUT, detectar cruces de horario, calcular tarifa, verificar una cuenta:
  todo eso vive en los paquetes PL/SQL (`SGCD_PKG_*`), descritos en el documento de diseño.
- **Las vistas e informes.** No existen todavía; cuando se creen, se documentan aquí con el mismo
  formato.
- **Los datos de ejemplo.** `06_datos_catalogos_v3.sql` carga catálogos y unas pocas filas demo;
  el glosario describe estructura, no contenido.
