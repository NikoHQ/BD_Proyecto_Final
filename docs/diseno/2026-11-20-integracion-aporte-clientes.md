# Integración del aporte de clientes (20-11-2026)

**Contexto.** Ignacio entregó `mi_parte_plsql/` con actualizar y borrar ficha, una tabla de
auditoría y tres consultas de reporte. El código era correcto, pero estaba fuera del modelo y de
las convenciones del proyecto. Este documento fija cómo quedó integrado y por qué.

## Decisiones

| Tema | Decisión | Motivo |
|---|---|---|
| Tabla de auditoría | Dentro de `04_ddl_v3.sql`, como tabla 23 | El DDL borra toda tabla `SGCD_*` y toda secuencia `SGCD_SEQ_*` al re-ejecutarse; un archivo aparte quedaría huérfano y no sería re-ejecutable |
| Procedimientos | Dentro de `SGCD_PKG_CLIENTES` | La rúbrica y el diseño v3 exigen la lógica en la capa de servicios; dos procedimientos sueltos duplicaban validaciones |
| Códigos de error | Un solo catálogo `-200xx` | `-20103` y `-20104` ya existían como `-20002` y `-20017` |
| Panel web | Apache + PHP-FPM nativo sobre `oracle-free` | El stack ya está instalado y verificado; el `compose.yaml` de la rama traería un segundo Oracle en el mismo puerto |
| Borrado | Físico solo sin dependencias; con historial se usa `cambiar_estado` | Las 7 FK a `SGCD_CLIENTES` lo impiden de todos modos, y el panel necesita «Desactivar» |

## Mapa de archivos

| Aporte original | Destino |
|---|---|
| `02_actualizar_ficha_cliente.sql` | `SGCD_PKG_CLIENTES.actualizar_ficha` |
| `03_borrar_ficha_cliente.sql` | `SGCD_PKG_CLIENTES.borrar_ficha` (+ `cambiar_estado`, nuevo) |
| `04_auditoria_clientes.sql` | `04_ddl_v3.sql`: tabla 23, secuencia y triggers `TRG_SGCD_CLIENTES_AU/AD` |
| `05_reportes.sql` | `SGCD_PKG_CONSULTAS.reporte_ingresos / reporte_reservas_cancha / reporte_clientes_reservas` |
| `06`, `06b`, `06c` | `08_pruebas_v3.sql` (secciones 1 a 3) |
| `07_comprobar_compilacion.sql` | Sin archivo propio: `SHOW ERRORS` al final de `05` |

## Contrato de la ficha

```sql
SGCD_PKG_CLIENTES.actualizar_ficha(p_id_cliente, p_nombre, p_telefono, p_correo)
SGCD_PKG_CLIENTES.cambiar_estado(p_id_cliente, p_estado)   -- ACTIVO | INACTIVO
SGCD_PKG_CLIENTES.borrar_ficha(p_id_cliente)
```

- No hacen `COMMIT` ni `ROLLBACK`: la transacción la cierra la capa PHP.
- `ID_CLIENTE`, `RUT_CLIENTE`, `DV_CLIENTE` y `CREADO_EN_CLIENTE` no se editan: el RUT identifica.
- `p_telefono` y `p_correo` nulos o vacíos dejan el campo en `NULL`.
- La tabla conserva formato, largo y unicidad; por eso algunos errores llegan como `ORA-12899`,
  `ORA-02290` o `ORA-00001`.

## Errores propios

| Código | Cuándo |
|---|---|
| `-20002` | El cliente no existe |
| `-20009` | Estado fuera de `ACTIVO` / `INACTIVO` |
| `-20017` | El correo ya está en otra ficha (también `ORA-00001` por carrera) |
| `-20024` | ID nulo, no entero o menor que 1 |
| `-20025` | Nombre obligatorio |
| `-20026` | El cliente tiene registros relacionados (también `ORA-02292` por carrera) |

`crear_ficha` cambió de `-20002` a `-20025` cuando falta el nombre, para no confundirlo con
«cliente no encontrado».

Un ID que excede `NUMBER(10)` (por ejemplo `10000000000`) no produce `ORA-06502`: el parámetro lo
acepta y el paquete responde `-20002`. Comprobado en Oracle el 2026-11-20.

## Auditoría

`SGCD_AUDITORIA_CLIENTES` guarda `ACCION` (`UPDATE` / `DELETE`), `FECHA_EVENTO` (`TIMESTAMP`),
valores anteriores y nuevos de nombre, teléfono, correo y estado, y el `ID_ADMINISTRADOR` que
actuó. No lleva FK a `SGCD_CLIENTES`: el registro sobrevive al borrado de la ficha.

- **Operador.** Sale de `SYS_CONTEXT('USERENV','CLIENT_IDENTIFIER')`, que PHP fija al iniciar la
  sesión con `DBMS_SESSION.SET_IDENTIFIER(<id_administrador>)`. Si la sesión no lo declara, la
  columna queda `NULL` y todo lo demás funciona igual.
- **Transacción.** Los triggers son `AFTER`: un `ROLLBACK` revierte el cambio y su registro.
- **Alcance.** No audita `INSERT`: el alta ya queda fechada en `CREADO_EN_CLIENTE`. El comentario
  de un `UPDATE` sin cambios no genera fila.
- **Índice.** `IX_SGCD_AUDCLI_CLIENTE (ID_CLIENTE, FECHA_EVENTO)` para reconstruir la historia.

## Reportes

Tres funciones de solo lectura con ventana de `p_dias` (30 por defecto), devueltas como
`SYS_REFCURSOR` para que PHP las recorra sin reescribir SQL:

1. `reporte_ingresos` — total cobrado por día y medio de pago.
2. `reporte_reservas_cancha` — reservas por cancha, sin canceladas.
3. `reporte_clientes_reservas` — clientes con más reservas, sin canceladas.

Los reportes 2 y 3 usan `JOIN`, así que no muestran canchas ni clientes sin movimientos. El
bloque de torneo no compite en el ranking de clientes porque no tiene `ID_CLIENTE`.

## Pendientes

1. Sección de pruebas del resto de la v3 (reservas, pagos, torneos, auth) en `08_pruebas_v3.sql`.
2. Endpoints PHP del CRUD con CSRF, rol `ADMINISTRADOR` y traducción de errores a HTTP.
3. Página **Reportes** en el panel: la maqueta no la tiene y la rúbrica pide tres dashboards.
4. Regenerar los datos de demostración con DV válido: la maqueta trae RUT como `77543210-4`, que
   el módulo 11 de `crear_ficha` rechaza.
