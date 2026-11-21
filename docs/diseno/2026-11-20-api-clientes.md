# API de clientes (paso 2 de la integración)

**Fecha:** 2026-11-20. **Estado:** probado contra `SGCD`.

La página de clientes deja de usar `localStorage` y pasa a llamar a `SGCD_PKG_CLIENTES`. PHP no
tiene reglas de negocio: valida forma, autoriza, traduce el DTO y decide el código HTTP. Todo lo
demás (unicidad, RUT, dependencias, auditoría) vive en la base.

## Archivos

| Archivo | Responsabilidad |
| --- | --- |
| `web/includes/api.php` | Sesión, CSRF, lectura del cuerpo, ejecución de bloques PL/SQL, mapa de errores y respuesta JSON |
| `web/api/clientes.php` | Las seis acciones del recurso |
| `web/includes/auth.php` | `csrfToken()` nuevo, para que el JavaScript lea el token del `<meta>` |
| `web/index.php` | `<meta name="csrf-token">` |

## Contrato

Todas las respuestas son JSON:

```json
{ "ok": true,  "data": { } }
{ "ok": false, "error": { "codigo": 20017, "mensaje": "…" } }
```

`codigo` es el error de Oracle; `null` cuando el problema es de sesión, CSRF o método.

| Método y acción | Cuerpo / query | Perfil | Éxito |
| --- | --- | --- | --- |
| `GET ?accion=listar` | `texto`, `estado`, `pagina`, `tamano` | ambos | `{items, total, pagina, tamano, paginas}` |
| `GET ?accion=ver` | `id` | ambos | ficha con contadores |
| `POST ?accion=crear` | `nombre`, `rut`, `telefono`, `correo` | ambos | `201` con la ficha y `creada` |
| `POST ?accion=actualizar` | `id`, `nombre`, `telefono`, `correo` | ambos | ficha actualizada |
| `POST ?accion=estado` | `id`, `estado` (`ACTIVO`/`INACTIVO`) | ambos | ficha actualizada |
| `POST ?accion=borrar` | `id` | **solo administrador** | `{id, borrado}` |

- El cuerpo puede ser JSON o formulario; el token va en `X-CSRF-Token` o en el campo `csrf`.
- `rut` acepta `12.345.678-5`, `12345678-5` o `123456785`.
- `listar` busca por nombre, RUT (con o sin puntos), teléfono y correo; el RUT se compara sin
  separadores del lado de la base.
- `crear` es idempotente por RUT: si la ficha existe devuelve `200` con `creada: false` en vez de
  duplicarla.
- Toda mutación confirma con `oci_commit`; si la base falla, no se confirma nada.
- La ficha devuelta incluye `reservas`, `reservas_vigentes`, `importe_pagado`, `cuenta_web` y
  `eventos_auditoria`, para que el panel no tenga que pedir tres veces.

## Errores

| Oracle | HTTP | Cuándo |
| --- | --- | --- |
| `20001` | 400 | RUT inválido (módulo 11) |
| `20002` | 404 | La ficha no existe |
| `20009` | 400 | Estado fuera de `ACTIVO`/`INACTIVO` |
| `20017` | 409 | Correo de otra ficha |
| `20024` | 400 | ID nulo, no entero o menor que 1 |
| `20025` | 400 | Nombre vacío |
| `20026` | 409 | Tiene reservas o cuentas: desactivar, no borrar |
| `20027` | 400 | Filtro o paginación inválidos |
| `ORA-00001` | 409 | Carrera con la unicidad de correo o RUT |
| `ORA-02290` / `ORA-12899` | 400 | Formato o largo que impone la tabla |
| `ORA-02292` | 409 | Dependencia detectada al borrar |
| otro | 500 | Se registra en el log; al navegador no se le muestra el detalle |

Sesión vencida → `401`. Perfil sin permiso → `403`. Método equivocado → `405`.

## Detalles de OCI8 que costaron una hora

1. **OUT NUMBER.** `oci_bind_by_name` dimensiona el buffer con el largo del valor actual. Un
   contador inicializado en `0` queda con 1 byte y Oracle responde `ORA-06502 character string
   buffer too small`. `apiLlamar` bindea siempre con `max(64, strlen(valor))`.
2. **BOOLEAN.** OCI8 no puede bindear `BOOLEAN`. `crear_ficha` lo devuelve, así que el bloque
   anónimo lo pasa a `NUMBER` con `CASE WHEN v_creada THEN 1 ELSE 0 END`.
3. **OUT no vuelve por referencia.** `apiLlamar` recibe los binds por valor; los OUT quedan en la
   copia que devuelve (`$llamada['out']['id']`). Leer la variable original devuelve 0 y el error
   aparece disfrazado de `-20024`.
4. **Cursor.** El `SYS_REFCURSOR` se bindea con `SQLT_RSET` y se ejecuta aparte con
   `oci_execute($cursor)` antes de `oci_fetch_all`.
5. **Sesión.** Un endpoint no hereda la sesión: `api.php` llama a `authStart()` al incluirse. Sin
   eso, todo responde 401 aunque el navegador tenga la cookie.
6. **Desarrollo.** El servidor embebido con `opcache.enable_cli=1` sirve la versión anterior del
   archivo y hace perder media hora. Arrancarlo con `-d opcache.enable_cli=0`.

## Verificación

17 casos con `curl` sobre `http://127.0.0.1:8090`, todos en el código esperado:

```
listar vacío 200 · crear 201 · correo repetido 409/20017 · RUT inválido 400/20001
sin CSRF 403 · GET sobre crear 405 · ver 200 · actualizar 200 (auditoría +1)
estado INACTIVO 200 (auditoría +1) · filtro por estado 1 fila · búsqueda RUT con puntos 1 fila
borrar 200 · ver borrada 404/20002 · borrar con credencial 409/20026
operador listar 200 · operador borrar 403
```

Los datos de prueba se borraron al terminar (0 clientes, 0 filas de auditoría).

## Pendiente

1. Conectar `web/assets/js/pages/clientes.js`: cargar por API, quitar la clasificación
   Persona/Organización (no existe en el modelo) y dejar el RUT de solo lectura al editar.
2. Mostrar el error del servidor en el formulario en vez del mensaje local.
3. Reservas: mostrar `CREADO_EN_RESERVA` cuando hay choque de horario, para ver quién reservó
   primero (ver `docs/diseno/flujo-administracion-reservas.md`).
