# SGCD — Sistema de Gestión de Centros Deportivos

Proyecto de **INF324 / ES3**. Motor de base de datos Oracle 26ai Free en Docker, lógica de negocio
en PL/SQL y una web de administración en PHP y AdminLTE.
**Entrega:** 2026-11-27.

**Estado de la entrega:** esquema v3 y paquetes PL/SQL disponibles. El panel tiene acceso de personal conectado a Oracle y flujos operativos de demostración pendientes de integración.

- [Acceso a la demo y credenciales de desarrollo](docs/entrega/ACCESO_DEMO.md)
- [Guía de integración para el equipo de backend y su agente de IA](docs/entrega/INTEGRACION_BACKEND.md)

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
| `web/` | Panel PHP, JavaScript por página, componentes y datos de demostración |
| `CODEGO/` | Bitácora y reportes fechados del avance |

## La base, en orden

| Archivo | Qué hace | Estado |
|---|---|---|
| `sql/oracle/01_ddl_v2.sql` | Esquema v2: 17 tablas | histórico |
| `sql/oracle/02_pruebas_v2.sql` | 26 pruebas de integridad de la v2 | histórico |
| `sql/oracle/03_catalogos_v2.sql` | Catálogos de la v2 (2 recintos, 78 tarifas) | histórico |
| `sql/oracle/04_ddl_v3.sql` | **Esquema v3: 22 tablas** (cliente web, credenciales, torneos) | compilado |
| `sql/oracle/05_paquetes_plsql.sql` | **6 paquetes de lógica de negocio** (compilado: 12 objetos VALID) | compilado |
| `sql/oracle/06_catalogos_v3.sql` | Catálogos de la v3 (80 tarifas, 2 credenciales demo) | cargado |
| `sql/oracle/07_datos_operativos.sql` | Datos demo: clientes, reservas, pagos, torneos | pendiente |
| `sql/oracle/08_pruebas_v3.sql` | Pruebas negativas y positivas de la v3 | pendiente |

Se ejecutan **en ese orden**, dentro del esquema `SGCD`. `04_ddl_v3.sql` es autocontenido:
borra las tablas `SGCD_*` existentes antes de crearlas, así que reemplaza a la v2 sin pasos manuales.

## Convenciones de nombres

- Todo objeto lleva el prefijo `SGCD_`; las tablas van en plural.
- Restricciones: `PK_`, `FK_`, `UQ_` (única), `CK_` (check); índices: `IX_` (no único), `UX_` (único).
- Columnas: `ID_` = llave (foránea si apunta a otra tabla), `TIPO_` = clasificación estable,
  `ESTADO_` = estado que cambia, `FECHA_` = día, `..._EN` = instante, `IMPORTE_`/`VALOR_`/`PRECIO_`
  = dinero, `_HASH` = derivado de un secreto.
- El significado de cada columna y cada valor permitido está en
  [`docs/modelo/glosario-tablas.md`](docs/modelo/glosario-tablas.md). Es el primer archivo que hay
  que leer para tocar la base.

## Cómo se levanta

```bash
docker start oracle-free                      # el motor
docker ps                                     # esperar (healthy)
docker exec -it oracle-free sqlplus sgcd@localhost/FREEPDB1
```

Detalles de instalación, versiones y desinstalación en `infra/INSTALADO.md`.

## Cómo se decide

Las decisiones de diseño están fechadas en [`docs/diseno/`](docs/diseno/) y su historial en
`CODEGO/CHANGELOG.md`. Si un documento y el código discrepan, manda el código y se corrige el
documento en el mismo commit.

## Qué falta

1. `07_datos_operativos.sql` — clientes, credenciales de cliente, membresías, reservas, pagos, implementos y torneos demo.
2. `08_pruebas_v3.sql` con la batería completa.
3. Conectar la operación del panel a PHP y Oracle, incluida la recuperación de contraseña.
4. Definir quién hace las pantallas del cliente final.
