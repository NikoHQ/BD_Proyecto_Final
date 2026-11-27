# Ejecutar SGCD con Docker

Desde la raíz del repositorio, crea las claves locales de laboratorio:

```sh
cp .env.example .env
```

Edita `.env` y asigna valores distintos a `ORACLE_PASSWORD` y `SGCD_DB_PASSWORD`. El archivo está ignorado por Git.

Levanta Oracle y la aplicación, espera que Oracle esté disponible y carga el esquema con datos de demostración:

```sh
docker compose up -d --wait
bash infra/inicializar-oracle-local.sh --datos-demo
```

Comprueba el estado y abre la aplicación:

```sh
docker compose ps
```

- Portal: <http://127.0.0.1:8080/cliente/>
- Panel: <http://127.0.0.1:8080/dashboardadmin/>
- Oracle desde el host: `127.0.0.1:1521/FREEPDB1` (usuario `SGCD19`)

| Usuario | Clave inicial | Acceso |
| --- | --- | --- |
| `admin` | `admin` | Panel administrativo |
| `demo` | `SGCDdemo2026` | Portal de clientes |
| `nuevo` | `SGCDdemo2026` | Portal de clientes |

Para detener el entorno sin borrar datos:

```sh
docker compose down
```

Para borrar Oracle y todos sus datos de laboratorio:

```sh
docker compose down -v
```
