# SGCD — Sistema de Gestión de Centros Deportivos

Proyecto de **INF324 / ES3**. Motor de base de datos Oracle 26ai Free en Docker, lógica de negocio
en PL/SQL, un portal de clientes en PHP y Bootstrap y un panel de administración con AdminLTE.
**Entrega:** 2026-11-27.

**Estado hoy (2026-11-26):** el equipo cerró el **UML objetivo de 19 tablas**
([UML](docs/modelo/uml-equipo-19/UML_objetivo.mdj) y [mapa de integración](docs/entrega/MODELO_OBJETIVO.md)).
Están el **DDL de las 19 tablas**, los **catálogos del recinto único** y **los 7 paquetes**
(`10` a `14` de `sql/oracle/`), compilados, con **240 comprobaciones de contrato** y **17 de
concurrencia** en verde (`tests/integracion_dos_sesiones.sh`). La **fase 4 está cerrada**: agenda,
reservas, pagos, torneos y reportes del panel y del portal leen y escriben en Oracle
([detalle](docs/diseno/2026-11-24-unidad5-cerrada.md)). La contraparte firmó la
[carta de validación de la problemática](docs/entrega/carta-validacion-problema-firmada.pdf)
el 25-11-2026.
La carga de datos de laboratorio para la demostración está en el script 15. El panel
administra clientes, recintos y tarifas sobre Oracle.

- [Acceso a la demo y credenciales de desarrollo](docs/entrega/ACCESO_DEMO.md)
- [Guía de integración para el equipo de backend y su agente de IA](docs/entrega/INTEGRACION_BACKEND.md)
- [UML oficial de 19 tablas y mapa desde v3](docs/entrega/MODELO_OBJETIVO.md)
- [Recorrido del portal de clientes](docs/entrega/PORTAL_CLIENTE.md)
- [Contrato de reservas y pagos](docs/entrega/RESERVAS_ORACLE.md) · [Contrato de torneos](docs/entrega/TORNEOS_ORACLE.md)
- [Carta de validación firmada por la contraparte](docs/entrega/carta-validacion-problema-firmada.pdf)

---

## Mapa del repositorio

| Carpeta | Qué hay |
|---|---|
| `sql/oracle/` | Los scripts de la base, numerados en orden de ejecución |
| `sql/sqlite/` | Prototipo viejo en SQLite (referencia histórica, no se ejecuta en la entrega) |
| `docs/diseno/` | El diseño vigente: decisiones, esquema, paquetes, pruebas |
| `docs/modelo/` | Glosario de tablas, modelo UML y análisis del modelo recibido |
| `docs/entrega/` | Contratos, guías y material de entrega, incluida la carta firmada |
| `docs/recibido/` | Material de terceros, tal cual llegó (local, no se versiona) |
| `docs/prompts/` | Prompts reutilizables para generar artefactos |
| `material/` | Enunciados y plantillas del ramo (local, no se versiona) |
| `infra/` | Instalación del servidor (Apache, PHP, Oracle) e inventario de lo instalado |
| `web/` | Portal PHP, panel administrativo, JavaScript por página y APIs OCI8 |
| `tests/` | Pruebas de integración por HTTP y concurrencia Oracle |
| `23-11-26/` | Entrega del equipo del 23-11 (local, no se versiona; el UML vigente está en `docs/modelo/`) |
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
| `sql/oracle/15_datos_operativos_sgcd_19.sql` | Fichas ficticias, reservas, pagos y equipos para la demostración | carga repetible |

### Transición v3 (histórica)

| Archivo | Qué hace | Estado |
|---|---|---|
| `sql/oracle/01_ddl_v2.sql` | Esquema v2: 17 tablas | histórico |
| `sql/oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | histórico |
| `sql/oracle/03_catalogos_v2.sql` | Catálogos de la v2 (2 recintos, 78 tarifas) | histórico |
| `sql/oracle/04_ddl_v3.sql` | Esquema v3 de transición: 23 tablas (cliente web, credenciales, torneos, auditoría) | compilado |
| `sql/oracle/05_paquetes_plsql.sql` | 6 paquetes de la v3, con el CRUD de la ficha y los 3 reportes | compilado |
| `sql/oracle/06_catalogos_v3.sql` | Catálogos de la v3 (80 tarifas, credenciales de laboratorio) | cargado |
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
docker compose up -d --wait oracle
bash infra/inicializar-oracle-local.sh
docker compose up -d --no-deps app
docker compose ps
```

Abre el [portal de clientes](http://127.0.0.1:8080/) o el [panel administrativo](http://127.0.0.1:8080/dashboardadmin/). La [guía de acceso](docs/entrega/ACCESO_DEMO.md) explica cómo inicializar una base nueva y contiene las cuentas provisionales.

Para cargar los datos ficticios de la demostración en el esquema local, ejecuta
`bash infra/inicializar-oracle-local.sh --datos-demo`. Consulta el recorrido y sus fechas de
referencia en [Datos operativos de la demo](sql/README.md#datos-operativos-de-la-demo).

Para volver a la foto curada después de un ensayo, `bash infra/reiniciar-demo.sh` reconstruye
el esquema (tablas, catálogos, paquetes y datos del script 15) en un solo paso. Pide escribir
`REINICIAR`; con `--si` no pregunta. Acepta `CONT`, `DBUSER`, `DBPASS` y `DBSVC` para apuntar
a otra instalación.

## Cómo se decide

Las decisiones de diseño están fechadas en [`docs/diseno/`](docs/diseno/) y su historial en
`CODEGO/CHANGELOG.md`. Si un documento y el código discrepan, manda el código y se corrige el
documento en el mismo commit.

## Qué falta

Queda preparar las capturas, el video, las láminas y el ensayo de la defensa. La
carta de validación está firmada. La recuperación por preguntas permanece fuera del
alcance acordado.
