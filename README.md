# SGCD — Sistema de Gestión de Centros Deportivos

Proyecto de **INF324 / ES3**. Motor de base de datos Oracle 26ai Free en Docker, lógica de negocio
en PL/SQL, un portal de clientes en PHP y Bootstrap y un panel de administración con AdminLTE.
**Entrega:** 2026-11-27.

**Estado hoy (2026-11-23):** el equipo cerró el **UML objetivo de 19 tablas**
([fuente](23-11-26/UML_objetivo_19_tablas.mdj) y [mapa de integración](docs/entrega/MODELO_OBJETIVO.md)).
La base de trabajo sigue siendo el esquema v3 de transición (**23 tablas** en este repositorio),
con 6 paquetes PL/SQL `VALID` y catálogos cargados. El portal de clientes y el panel administrativo
están disponibles en modo demostración; el acceso de personal y la consulta de catálogo usan Oracle.
**Siguiente paso:** publicar el DDL de instalación de las 19 tablas y adaptar los paquetes a ese modelo.

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

| Archivo | Qué hace | Estado |
|---|---|---|
| `sql/oracle/01_ddl_v2.sql` | Esquema v2: 17 tablas | histórico |
| `sql/oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | histórico |
| `sql/oracle/03_catalogos_v2.sql` | Catálogos de la v2 (2 recintos, 78 tarifas) | histórico |
| `sql/oracle/04_ddl_v3.sql` | **Esquema v3 de transición: 23 tablas** (cliente web, credenciales, torneos, auditoría) | compilado |
| `sql/oracle/05_paquetes_plsql.sql` | **6 paquetes de lógica de negocio** (12 objetos `VALID`), con el CRUD de la ficha y los 3 reportes | compilado |
| `sql/oracle/06_catalogos_v3.sql` | Catálogos de la v3 (80 tarifas, credenciales de laboratorio) | cargado |
| `sql/oracle/07_datos_operativos.sql` | Datos demo: clientes, reservas, pagos, torneos | pendiente |
| `sql/oracle/08_pruebas_v3.sql` | Pruebas de la v3: ficha y auditoría de clientes, errores y reportes | parcial |
| `sql/oracle/09_torneos_tamano_plantilla.sql` | Migración incremental del tamaño de plantilla | disponible |

Para inicializar un esquema v3 vacío, usa los scripts 04 a 06 como usuario `SGCD`. El script 04
recrea las tablas (borra las `SGCD_*` existentes). El esquema de transición permite levantar la
demo; el backend final se escribe sobre el [UML oficial de 19 tablas](docs/entrega/MODELO_OBJETIVO.md)
y el DDL de instalación con nombres definitivos `SGCD_*`, secuencias y triggers.

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

1. **DDL de las 19 tablas** con nombres definitivos `SGCD_*`, PK/FK, restricciones, secuencias y
   triggers coordinados con Pablo, más los catálogos del recinto único (6 canchas + grande, 3 deportes).
2. Adaptar los 6 paquetes al modelo objetivo (`USUARIO` en lugar de `CREDENCIALES`, reservas por
   bloques de una hora con la regla de la cancha grande, tarifa por bloque, inscripción completa).
3. Integrar los 10 mantenedores de `23-11-26/mi_parte_nuevo/` (faltan modalidades, deportes,
   canchas, horarios, cancha–modalidad, administradores y torneos).
4. Los 5 gestores: reservas con precio por bloques consecutivos y sin cruce grande/1-2-3, pago
   único por reserva, inscripción de equipos con nómina y último cupo, programación de torneos sin
   cliente, y definir el quinto.
5. Exponer los tres reportes de `SGCD_PKG_CONSULTAS` en una página **Reportes**, aplicar permisos
   de cliente/administrador y adaptar los triggers de auditoría (antes/después al editar, antes al borrar).
6. `07_datos_operativos.sql` — clientes, reservas, pagos y torneos demo para los dashboards y el video.
7. Conectar el panel y el portal a Oracle (hoy la mayoría de los flujos usan datos ficticios).
8. Recuperación de contraseña por preguntas de seguridad.
