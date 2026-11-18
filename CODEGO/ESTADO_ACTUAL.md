# Estado actual del proyecto — SGCD

**Fecha:** 2026-11-17 · **Proyecto:** INF324/ES3 · Sistema de Gestión de Centros Deportivos
**Entrega:** 2026-11-27

> [!warning] Superado el 2026-11-18
> El alcance cambió: el cliente final pasa a ser usuario del sistema y se agregan torneos y web de
> administración. La sección **"¿Solo admin?"** de este documento ya no es válida, y el modelo
> pasa de 17 a 21 tablas. Fuente de verdad actual:
> `docs/superpowers/specs/2026-11-18-sgcd-v3-cliente-web-torneos-design.md` y
> `CODEGO/REPORTE_2026-11-18.md`.

---

## Resumen

Una de dos capas terminada: la de **servicios/datos**. No existe capa cliente todavía.
No es "solo admin": es "solo motor".

---

## Lo que existe hoy (verificado)

| Componente | Estado | Evidencia |
|---|---|---|
| Motor | Oracle AI Database 26ai Free **23.26.3** en Docker | contenedor `oracle-free` healthy, PDB `FREEPDB1` |
| Esquema | `SGCD`, 17 tablas | 41 índices · 130 CHECK · 18 FK · 9 UNIQUE |
| Integridad | probada | **26/26** pruebas negativas y positivas |
| Catálogos | cargados | 2 recintos · 7 instalaciones · 5 deportes · 6 modalidades · 10 pares cancha-modalidad · 14 horarios · **78 tarifas** |
| Modelo | `UML.mdj` 1FN→2FN→3FN | 17 tablas, FK compuestas documentadas |
| Documentación | análisis + bitácora | `sql/oracle/ANALISIS_17-11-26_vs_nuestro.md`, `CODEGO/CHANGELOG.md` |
| Stack web | Apache 2.4.71 + PHP 8.5 + php-fpm + oci8 | servicios `active` |

### Catálogos cargados, por instalación

| Instalación | Deporte / Modalidad | Días tarifados | Rango CLP |
|---|---|---|---|
| Cancha Futbol 7 | Futbol 7 | 12 | 18.000 – 28.000 |
| Cancha Futbol 5 | Futbol 5 | 12 | 15.000 – 23.000 |
| Cancha Padel 1 | Padel dobles | 7 | 12.000 – 15.000 |
| Gimnasio Multiuso | Basquetbol 5x5 | 7 | 20.000 – 22.000 |
| Gimnasio Multiuso | Futbol 5 | 5 | 20.000 |
| Gimnasio Multiuso | Voleibol 6x6 | 7 | 18.000 – 20.000 |
| Gimnasio Multiuso | Entrenamiento funcional | 7 | 6.000 |
| Cancha Basquetbol | Basquetbol 5x5 | 7 | 16.000 – 18.000 |
| Cancha Voleibol | Voleibol 6x6 | 7 | 14.000 – 16.000 |
| Sala de Entrenamiento | Entrenamiento funcional | 7 | 8.000 |

---

## Lo que NO existe

| Falta | Dato duro |
|---|---|
| **Capa cliente** | `/srv/http` está **vacío**. Cero archivos. |
| **PHP propio** | cero `.php` en el repo fuera de AdminLTE (plantilla, no código) |
| **PL/SQL** | cero procedimientos, paquetes o triggers en `SGCD`. Solo las 15 secuencias de `IDENTITY` |
| **Datos operativos** | `CLIENTES 0 · RESERVAS 0 · PAGOS 0 · MEMBRESIAS 0 · ADMINISTRADORES 0` |
| **Vistas / informes** | ninguna |

---

## Capas: cómo estamos trabajando

Reparto real hoy:

```
CAPA CLIENTE      ✗ no existe
CAPA SERVICIOS    parcial:  DDL + constraints  ✓   PL/SQL  ✗
CAPA DATOS        ✓ 17 tablas + catálogos
```

ES3 pide **dos capas**: cliente y servicios en la base, con *"toda la programación lógica
pesada residirá en la base de datos"*. Quedan dos formas legítimas, y la elección **sigue
sin cerrarse** desde el 2026-11-15:

| Opción | Qué implica | Riesgo |
|---|---|---|
| **A — 2 capas (recomendada)** | PHP solo presenta y valida forma; toda la regla de negocio en paquetes PL/SQL. Se rotula *2 capas*, con MVC interno en PHP | Ninguno frente al enunciado |
| **B — 3 capas** | Lógica en PHP, BD como simple almacén | Contradice el enunciado y deja el PL/SQL vacío |

En la opción A el MVC de PHP **no cuenta como capa**: es organización interna del cliente.
Conviene rotular **2 capas** en la lámina y mostrar el PL/SQL como "servicios".

### ¿Solo admin?

Sí, y ya está decidido en el modelo, no es algo que falte: `ADMINISTRADOR` tiene `PERFIL`
(`ADMINISTRADOR` / `OPERADOR`) y `CLAVE_HASH`; `CLIENTE` **no tiene acceso** al sistema — es un
registro de datos, no un usuario. El producto es un **panel de administración**: recepcionista y
dueño operan, el cliente reserva por mostrador. Eso es independiente del número de capas.

---

## Deuda abierta, por peso

| # | Deuda | Impacto |
|---|---|---|
| 1 | PL/SQL inexistente | Es el corazón del requisito. Sin esto, "2 capas" es solo una frase |
| 2 | Capa cliente inexistente | No hay sistema que mostrar en el video ni en las capturas |
| 3 | Datos operativos en 0 | Dashboards y consultas salen vacíos |
| 4 | D-3 horario por recinto | 14 horarios en vez de 49; ya mordió al cargar catálogos |
| 5 | D-4 `BLOQUEO_CANCHA` | Mantención y feriados no tienen dónde guardarse |
| 6 | Modelo v2 de 24 tablas | Existe en la memoria del proyecto, **no como archivo**. O se escribe o se descarta |
| 7 | D-1 `IDENTITY` | Contadores con huecos; solo importa si se exige numeración continua |

### Decisiones abiertas

| ID | Decisión | Por defecto aplicado |
|---|---|---|
| D-1 | `IDENTITY` vs secuencia + trigger | `IDENTITY` |
| D-2 | `CANCHA` vs `INSTALACION` | `CANCHA` + `TIPO_CANCHA` |
| D-3 | Horario por recinto vs por instalación | por recinto |
| D-4 | Agregar `BLOQUEO_CANCHA` (18ª tabla) | no agregada |

---

## Siguiente unidad recomendada

**Paquete PL/SQL de reservas** (crear, cancelar, consultar disponibilidad). Es lo que convierte
el esquema en "servicios" y la pieza que el cliente PHP va a llamar después. Sin eso, cualquier
PHP escrito antes tendría la lógica en el lugar equivocado y habría que rehacerlo.

---

## Acceso

| Recurso | Valor |
|---|---|
| Servicio | `localhost:1521/FREEPDB1` |
| Usuario app | `sgcd` — dueño de las 17 tablas |
| Usuario admin | `system` — administrador del PDB |
| CDB | service `FREE`, `sys ... as sysdba` |
| Contenedor | `docker start oracle-free` · datos en volumen `oracle-free-data` |
