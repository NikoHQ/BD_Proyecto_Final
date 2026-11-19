# Prompt — `07_datos_operativos.sql`

**Cuándo usarlo:** solo cuando existan `04_ddl_v3.sql` y `06_datos_catalogos_v3.sql`.
Un script de datos no puede preceder al esquema: si no hay DDL, el modelo solo puede inventarlo.

**Adjunta estos archivos al prompt (obligatorio):**

1. `sql/oracle/04_ddl_v3.sql`
2. `sql/oracle/06_datos_catalogos_v3.sql`
3. `sql/oracle/05_paquetes_plsql.sql` — para las firmas de `crear_reserva` y `arrendar_bloque`

**Qué cambió respecto del intento anterior**

| Problema | Corrección |
|---|---|
| El otro modelo no tenía el DDL | Se adjunta; y la regla cero le ordena detenerse si falta, no improvisar |
| "`SGCD_CLIENTES` no tiene RUT" | **Sí lo tiene en v3**: `RUT_CLIENTE NUMBER(8)` + `DV_CLIENTE CHAR(1)` |
| "No hay columna de dirección" | Es correcto: **no existe dirección de cliente** en el modelo. Solo `DIRECCION_RECINTO`. No se inventa |
| Importes sin origen | Toda reserva se construye desde una fila de `SGCD_TARIFAS`, así el importe y el día de la semana existen siempre |
| Riesgo de solapes | Las reservas se crean con `SGCD_PKG_RESERVAS.crear_reserva`, no con `INSERT` |

---

## Texto del prompt — copiar desde aquí

Actúa como DBA Oracle. Vas a escribir **un solo archivo** `07_datos_operativos.sql` con datos
operativos plausibles para SGCD, un sistema de gestión de recintos deportivos en Chile.

Se ejecuta **después** de dos scripts que te adjunto: `04_ddl_v3.sql` (esquema `SGCD`, 21 tablas)
y `06_datos_catalogos_v3.sql` (catálogos ya cargados: 2 recintos, 7 instalaciones, 5 deportes,
6 modalidades, 14 horarios, 78 tarifas).

### Regla cero

No inventes el esquema. Si una tabla o columna no aparece en el DDL adjunto, **no existe**: no la
crees, no la uses y no rellenes el hueco con una suposición. Si falta el DDL o el script de
catálogos, detente y pídelos. No entregues un archivo parcial ni un "ejemplo ilustrativo".

### Correcciones que invalidan el intento anterior

1. `SGCD_CLIENTES` **sí** tiene RUT: `RUT_CLIENTE NUMBER(8)` (solo dígitos, sin puntos ni guion) y
   `DV_CLIENTE CHAR(1)` (`0`–`9` o `K`, mayúscula). El par `(RUT_CLIENTE, DV_CLIENTE)` es único.
2. **No existe dirección de cliente.** La única dirección del modelo es
   `SGCD_RECINTOS.DIRECCION_RECINTO`. No agregues columnas ni inventes ese dato.
3. La tabla de precios es `SGCD_TARIFAS`, y sus filas son la **única** fuente de importes.
4. Las reservas **no** se insertan con `INSERT` directo: se crean con
   `SGCD_PKG_RESERVAS.crear_reserva(...)`, que valida cruces de horario y calcula
   `IMPORTE_ACORDADO_RESERVA` desde la tarifa. Si quieres un importe distinto, no lo escribas:
   usa el parámetro de descuento del procedimiento.

### Datos a generar

| Qué | Volumen | Notas |
|---|---|---|
| `SGCD_PLANES_MEMBRESIA` | 3 | mensual, trimestral, anual; descuentos 0 %, 5 %, 10 % |
| `SGCD_ARTICULOS` | 8 | balones, petos, paletas, redes; venta y/o arriendo |
| `SGCD_CLIENTES` | 45 | fichas completas, RUT con DV correcto (módulo 11) |
| `SGCD_ADMINISTRADORES` | 3 | 1 `ADMINISTRADOR`, 2 `OPERADOR` |
| `SGCD_CREDENCIALES` | 3 | 1 admin, 1 operador, 1 cliente **no verificado** |
| `SGCD_MEMBRESIAS` | 14 | algunas vigentes, algunas vencidas |
| `SGCD_MOVIMIENTOS_PUNTOS` | 25 | `GANADO` positivos, `CANJEADO` negativos |
| `SGCD_RESERVAS` | 140 | ventana `2026-10-01` a `2026-12-15` |
| `SGCD_OPERACIONES_IMPLEMENTOS` | 22 | `VENTA` y `ARRIENDO` |
| `SGCD_DETALLES_IMPLEMENTOS` | 40 | 1–3 líneas por operación |
| `SGCD_PAGOS` | 60 | reservas, operaciones y membresías |
| `SGCD_TORNEOS` | 2 | uno interno con descuento 100 %, uno a tarifa plena |
| `SGCD_EQUIPOS` | 8 | 4 por torneo |
| `SGCD_EQUIPO_JUGADORES` | 40 | 5 jugadores por equipo |
| Bloques de torneo | 14 | filas de `SGCD_RESERVAS` con `TIPO_RESERVA='TORNEO'` |

### Reglas de consistencia (todas obligatorias)

- **Fecha de referencia fija:** `DATE '2026-11-18'`. No uses `SYSDATE` para decidir qué es pasado
  y qué es futuro.
- **Toda reserva nace de una fila de `SGCD_TARIFAS`:** toma su `DIA_SEMANA_TARIFA` y su banda
  `HORA_DESDE_TARIFA`/`HORA_HASTA_TARIFA` para fijar día y hora reales de `INICIO_RESERVA`. Así el
  día de la semana coincide con una banda tarifaria existente y el importe siempre se puede
  calcular.
- **Nada de reservas** en canchas con `ESTADO_CANCHA <> 'DISPONIBLE'`, ni fuera del
  `SGCD_HORARIOS` de su recinto, ni cruzadas en la misma cancha. Si una llamada al procedimiento
  falla, ajusta el bloque y reintenta; no lo fuerces con `INSERT`.
- **Mezcla de estados:** ~55 % `CONFIRMADA`, ~20 % `COMPLETADA` (fechas pasadas), ~15 %
  `PENDIENTE` de origen `WEB` (futuras), ~10 % `CANCELADA`.
- `ORIGEN_RESERVA = 'MOSTRADOR'` **exige** `ID_ADMINISTRADOR`; `'WEB'` lo **prohíbe**.
- **Pagos:** cada fila apunta a exactamente un origen (reserva, operación o membresía). Importe
  igual al total o una fracción documentada como abono; nunca mayor que el total.
- **Membresías:** `FECHA_TERMINO_MEMBRESIA > FECHA_INICIO_MEMBRESIA`.
- **Puntos:** `CANTIDAD_MOVIMIENTO <> 0`; `CANJEADO` en negativo; el saldo por cliente nunca queda
  negativo.
- **Torneos:** bloques con `TIPO_RESERVA='TORNEO'` e `ID_TORNEO` no nulo; `ID_MODALIDAD` siempre
  presente; `ID_CLIENTE` puede ser nulo en esos bloques.
- **Credenciales:** una sola por cliente (`UNIQUE ID_CLIENTE`); rol `CLIENTE` exige `ID_CLIENTE`;
  exactamente uno de `ID_CLIENTE`/`ID_ADMINISTRADOR` no nulo. Usa **este hash ya calculado** para
  la clave `Demo1234` (bcrypt, verificado):
  `$2y$12$K9jB5X2EHPjF9LC1fTdJdOc3SMHziE1S4gN.9hYEEn3ffnBDhzLpG`
  No generes hashes nuevos ni inventes formatos.
- **Datos plausibles de Chile:** nombres y apellidos de uso común, teléfonos `+569XXXXXXXX`,
  correos en minúsculas y únicos, RUT únicos con DV correcto.

### Formato del entregable

- Un único archivo SQL, comentado por bloques, sin `CREATE` ni `ALTER`: solo `DELETE`/`INSERT` y
  llamadas a procedimientos.
- **Re-ejecutable:** al inicio borra solo datos operativos, en orden inverso de dependencia
  (`PAGOS`, `DETALLES_IMPLEMENTOS`, `OPERACIONES_IMPLEMENTOS`, `RESERVAS`, `EQUIPO_JUGADORES`,
  `EQUIPOS`, `TORNEOS`, `MOVIMIENTOS_PUNTOS`, `MEMBRESIAS`, `CREDENCIALES`, `CLIENTES`,
  `ADMINISTRADORES`, `ARTICULOS`, `PLANES_MEMBRESIA`). Nunca borres catálogos.
- Un solo `COMMIT` al final.
- Al final, un bloque de **verificación** que imprima con `SELECT` etiquetado: conteo por tabla,
  reservas por estado, ingresos por mes, ocupación por instalación, y tres consultas de sanidad:
  FKs huérfanas, reservas cruzadas por cancha, y clientes con saldo de puntos negativo.

### Autochequeo antes de entregar

Responde estas diez preguntas; si alguna falla, corrige el archivo y vuelve a empezar:

1. ¿Alguna columna usada no existe en el DDL adjunto?
2. ¿Algún `RUT_CLIENTE`/`DV_CLIENTE` viola módulo 11 o se repite?
3. ¿Algún correo repetido, con mayúsculas o sin `@`?
4. ¿Alguna reserva fuera del horario del recinto o en cancha no disponible?
5. ¿Dos reservas cruzadas en la misma cancha, contando las `PENDIENTE`?
6. ¿Algún `IMPORTE_ACORDADO_RESERVA` que no corresponda a una tarifa vigente (o a la tarifa con el
   descuento del torneo)?
7. ¿Algún pago cuyo importe exceda el total de su origen, o con cero o dos orígenes?
8. ¿Algún movimiento de puntos que deje saldo negativo?
9. ¿Algún bloque de torneo sin `ID_TORNEO`, o un torneo con equipos que no existen?
10. ¿El script corre dos veces seguidas sin violar ninguna restricción?

Si algo no se puede cumplir con la información adjunta, dilo y detente. No rellenes con supuestos.

## Texto del prompt — hasta aquí
