# SGCD — Sistema de Gestión de Centros Deportivos

Proyecto INF324 / ES3. Incluye una base Oracle 26ai Free, lógica de negocio en PL/SQL, un portal de clientes en PHP y un panel administrativo.

El modelo vigente tiene 19 tablas. La aplicación gestiona clientes, canchas, horarios, tarifas, reservas, pagos y torneos sobre Oracle.

- [Guía de ejecución con Docker](docs/entrega/ACCESO_DEMO.md)
- [Recorrido del portal de clientes](docs/entrega/PORTAL_CLIENTE.md)
- [UML objetivo de 19 tablas](docs/modelo/UML_objetivo.mdj)
- [Carta de validación firmada](docs/entrega/carta-validacion-problema-firmada.pdf)

## Ejecutar con Docker

Desde la raíz del repositorio:

```sh
cp .env.example .env
```

Edita `.env` y define `ORACLE_PASSWORD` y `SGCD_DB_PASSWORD`. No subas ese archivo a Git.

Levanta la aplicación y carga el esquema con datos de demostración:

```sh
docker compose up -d --wait
bash infra/inicializar-oracle-local.sh --datos-demo
```

Para reiniciar la base con la foto de demostración, ejecuta `bash infra/reiniciar-demo.sh`. El comando pide confirmación y reconstruye el esquema, los catálogos, los paquetes y los datos demo.

Abre:

- Portal: <http://127.0.0.1:8080/cliente/>
- Panel administrativo: <http://127.0.0.1:8080/dashboardadmin/>

Las credenciales de demostración y los comandos para detener o reiniciar el entorno están en la [guía Docker](docs/entrega/ACCESO_DEMO.md).

## Estructura

| Ruta | Contenido |
| --- | --- |
| `compose.yaml` | Oracle y la aplicación PHP con OCI8. |
| `.env.example` | Variables requeridas para crear el entorno local. |
| `infra/` | Inicializador del esquema Oracle. |
| `sql/oracle/` | DDL, catálogos, paquetes PL/SQL y datos de demostración. |
| `web/` | Portal de clientes, panel administrativo, APIs PHP, JavaScript y estilos. |
| `docs/modelo/` | UML objetivo y fuente PlantUML. |
| `docs/entrega/` | Guía de ejecución, recorrido de la demo y carta firmada. |
