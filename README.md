# SGCD — Sistema de Gestión de Centros Deportivos

Proyecto de **INF324 / ES3**. Motor de base de datos Oracle 26ai Free en Docker, lógica de negocio
en PL/SQL, un portal de clientes en PHP y Bootstrap y un panel de administración con AdminLTE.
**Entrega:** 2026-11-27.

**Estado hoy (2026-11-24):** el equipo cerró el **UML objetivo de 19 tablas**
([fuente](23-11-26/UML_objetivo_19_tablas.mdj) y [mapa de integración](docs/entrega/MODELO_OBJETIVO.md)).
Ya están el **DDL de instalación de las 19 tablas**, los **catálogos del recinto único** y **los 7
paquetes** del modelo (`10` a `14` de `sql/oracle/`), compilados y con **233 comprobaciones en
verde** en un esquema limpio, más **17 comprobaciones de concurrencia** con dos sesiones reales
(`tests/integracion_dos_sesiones.sh`). El portal de clientes y el panel administrativo están
disponibles en modo demostración; el acceso de personal y la consulta de catálogo usan Oracle.
**Siguiente paso:** conectar la web a los paquetes (fase 4).

- [Acceso a la demo y credenciales de desarrollo](docs/entrega/ACCESO_DEMO.md)
- [Guía de integración para el equipo de backend y su agente de IA](docs/entrega/INTEGRACION_BACKEND.md)
- [UML oficial de 19 tablas y mapa desde v3](docs/entrega/MODELO_OBJETIVO.md)
- [Recorrido del portal de clientes](docs/entrega/PORTAL_CLIENTE.md)
- [Contrato de reservas y pagos](docs/entrega/RESERVAS_ORACLE.md) · [Contrato de torneos](docs/entrega/TORNEOS_ORACLE.md)

---

## Mapa del repositorio

| Carpeta | Qué hay |
|---|---|
| `sql/oracle/` | Los scripts de la base, numerados en orden de ejecución |
| `sql/sqlite/` | Prototipo viejo en SQLite (referencia histórica, no se ejecuta en la entrega) |
| `docs/diseno/` | El diseño vigente: decisiones, esquema, paquetes, pruebas |
| `docs/modelo/` | Glosario de tablas, modelo UML y análisis del modelo recibido |
| `docs/recibido/` | Material que nos pasaron terceros, tal cual llegó |
| `docs/prompts/` | Prompts reutilizables para generar artefactos |
| `material/` | Enunciados del ramo, plantillas y documentos de entrega |
| `infra/` | Instalación del servidor (Apache, PHP, Oracle) e inventario de lo instalado |
| `web/` | Portal PHP, panel administrativo, JavaScript por página y adaptadores de demostración |
| `tests/` | Pruebas de los flujos del portal (PHP embebido) |
| `23-11-26/` | Entrega del equipo del 23-11: UML de 19 tablas, DDL de Pablo y aportes PL/SQL |
| `CODEGO/` | Bitácora y reportes fechados del avance |

## La base, en orden

### Modelo objetivo de 19 tablas (vigente)

| Archivo | Qué hace | Estado |
|---|---|---|
| `sql/oracle/10_ddl_sgcd_19.sql` | **Esquema de 19 tablas del UML**: PK, FK, `UNIQUE`, `CHECK`, índices, 16 secuencias y 18 triggers (16 de llave y los 2 de auditoría) | compilado y probado |
| `sql/oracle/11_catalogos_sgcd_19.sql` | Recinto único, 10 canchas con la grande y sus componentes, 3 deportes, 3 modalidades, 6 horarios, 82 bloques, 120 tarifas, 3 torneos y cuentas de laboratorio | cargado |
| `sql/oracle/12a_pkg_auth.sql` … `12j_pkg_consultas.sql` | Paquetes y mantenedores adaptados al modelo objetivo | los 7 paquetes y 9 mantenedores compilados |
| `sql/oracle/13_pruebas_sgcd_19.sql` | Comprobaciones del DDL y los catálogos, con reversa final | en verde |
| `sql/oracle/14_pruebas_paquetes_sgcd_19.sql` | Pruebas de los paquetes y mantenedores, por unidad | en verde |

### Transición v3 (histórica)

| Archivo | Qué hace | Estado |
|---|---|---|
| `sql/oracle/01_ddl_v2.sql` | Esquema v2: 17 tablas | histórico |
| `sql/oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | histórico |
| `sql/oracle/03_catalogos_v2.sql` | Catálogos de la v2 (2 recintos, 78 tarifas) | histórico |
| `sql/oracle/04_ddl_v3.sql` | Esquema v3 de transición: 23 tablas (cliente web, credenciales, torneos, auditoría) | compilado |
| `sql/oracle/05_paquetes_plsql.sql` | 6 paquetes de la v3, con el CRUD de la ficha y los 3 reportes | compilado |
| `sql/oracle/06_catalogos_v3.sql` | Catálogos de la v3 (80 tarifas, credenciales de laboratorio) | cargado |
| `sql/oracle/07_datos_operativos.sql` | Datos demo: clientes, reservas, pagos, torneos | pendiente |
| `sql/oracle/08_pruebas_v3.sql` | Pruebas de la v3: ficha y auditoría de clientes, errores y reportes | parcial |
| `sql/oracle/09_torneos_tamano_plantilla.sql` | Migración incremental del tamaño de plantilla | disponible |

Cada DDL borra las tablas `SGCD_*` antes de crearlas: se ejecuta sólo en desarrollo. Los archivos con
datos en español requieren `NLS_LANG=AMERICAN_AMERICA.AL32UTF8` y `LANG=C.UTF-8` en el `docker exec`
(ver [`sql/README.md`](sql/README.md)), o los acentos se guardan como caracteres de reemplazo.

## Convenciones de nombres

- Todo objeto lleva el prefijo `SGCD_`; las tablas van en plural.
- Restricciones: `PK_`, `FK_`, `UQ_` (única), `CK_` (check); índices: `IX_` (no único), `UX_` (único).
- Columnas: `ID_` = llave (foránea si apunta a otra tabla), `TIPO_` = clasificación estable,
  `ESTADO_` = estado que cambia, `FECHA_` = día, `..._EN` = instante, `IMPORTE_`/`VALOR_`/`PRECIO_`
  = dinero, `_HASH` = derivado de un secreto.
- Los IDs los genera Oracle con `SGCD_SEQ_*` y un trigger `BEFORE INSERT`; no se envían desde PHP.
- El significado de cada columna y cada valor permitido está en
  [`docs/modelo/glosario-tablas.md`](docs/modelo/glosario-tablas.md). Es el primer archivo que hay
  que leer para tocar la base.

## Cómo se levanta

En la torre se sirve con Apache + PHP-FPM nativo sobre el contenedor `oracle-free` (ver
[`infra/DESPLIEGUE_WEB.md`](infra/DESPLIEGUE_WEB.md)). Para un entorno aislado, desde la raíz del
repositorio:

```sh
docker compose up -d
docker compose ps
```

Abre el [portal de clientes](http://127.0.0.1:8080/) o el [panel administrativo](http://127.0.0.1:8080/dashboardadmin/). La [guía de acceso](docs/entrega/ACCESO_DEMO.md) explica cómo inicializar una base nueva y contiene las cuentas provisionales.

## Cómo se decide

Las decisiones de diseño están fechadas en [`docs/diseno/`](docs/diseno/) y su historial en
`CODEGO/CHANGELOG.md`. Si un documento y el código discrepan, manda el código y se corrige el
documento en el mismo commit.

## Qué falta

1. **Conectar la web a los paquetes** (fase 4): endpoints con sesión, perfil y CSRF, y reemplazar
   `demo/store.js`, `demo/fixtures.js`, `demo/tournaments.js` y `cliente/demo.php` por `fetch` a los
   paquetes. La fase 3 quedó cerrada con 7 paquetes, 9 mantenedores, 233 pruebas de contrato y la
   batería de concurrencia.
2. Conectar la web a esos paquetes (hoy todo sigue en la v3 y en la demo).
3. Los 5 gestores: reservas con precio por bloques consecutivos y sin cruce grande/1-2-3, pago
   único por reserva, inscripción de equipos con nómina y último cupo, programación de torneos sin
   cliente, y definir el quinto.
4. Exponer los tres reportes de `SGCD_PKG_CONSULTAS` en una página **Reportes**, aplicar permisos
   de cliente/administrador y adaptar los triggers de auditoría al formato JSON ya instalado.
5. `07_datos_operativos.sql` — clientes, reservas, pagos y torneos demo para los dashboards y el video.
6. Conectar el panel y el portal a Oracle (hoy la mayoría de los flujos usan datos ficticios).
7. Recuperación de contraseña por preguntas de seguridad.
