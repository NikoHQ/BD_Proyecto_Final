# Inventario de instalación — Proyecto BD Recintos Deportivos

Máquina: **cachyos-niko** (torre) · CachyOS · kernel 7.3.3 · 15 GiB RAM · 451 GB libres en `/` (btrfs)
Motivo: ES3 / INF324 — Base de Datos, entrega 27-11-2026.

Este archivo existe para saber **qué se instaló por el proyecto y qué se puede eliminar** cuando termine.

---

## 1. Instalado para el proyecto

| Componente | Versión | Origen | Para qué | Se puede eliminar |
|---|---|---|---|---|
| `php` | 8.5.12-2 | repo | lenguaje del cliente | sí |
| `php-fpm` | 8.5.12-2 | repo | FastCGI para Apache | sí |
| `php-oci8` | 3.4.1-1 | **AUR** | extensión Oracle (OCI8) | sí |
| `oracle-instantclient-basic` | 23.26.3.0.0-1 | **AUR** | `libclntsh`, `libnnz` | sí |
| `oracle-instantclient-sdk` | 23.26.3.0.0-1 | **AUR** | headers para compilar oci8 | sí |
| `oracle-instantclient-sqlplus` | 23.26.3.0.0-1 | **AUR** | `sqlplus` en el host | sí |
| `dbeaver-ce-jre-bin` | 26.2.4-1 | **AUR** | GUI, carga de `.sql`, exportar ERD | sí |
| `apache` | 2.4.71-1.1 | repo | servidor web | sí |

## 2. Artefactos Docker

| Artefacto | Tamaño | Nota |
|---|---|---|
| imagen `container-registry.oracle.com/database/free:latest` | **13,8 GB** | el grueso del espacio |
| contenedor `oracle-free` | — | pendiente de crear |
| volumen `oracle-free-data` | ~3 GB | datos de la BD; **contiene el trabajo** |

## 3. Ya existía antes del proyecto — NO eliminar

| Componente | Nota |
|---|---|
| `docker` 29.9.3 + compose 5.7.1 | venía instalado; `docker0` ya existía |
| `libaio` 0.3.113 | dependencia del Instant Client |
| `yay` 13.1.0, `git`, `base-devel`, `gcc`, `make` | herramientas del sistema |
| Tailscale, VirtualBox + 3 VMs del laboratorio | otro proyecto |

---

## 4. Configuración del sistema modificada

| Archivo / unidad | Cambio |
|---|---|
| `/etc/httpd/conf/httpd.conf` | descomenta `proxy_module` y `proxy_fcgi_module`, `DirectoryIndex index.php index.html`, bloque `FilesMatch` + `ServerName localhost` |
| `/etc/httpd/conf/httpd.conf.bak-*` | respaldo automático del script |
| `/etc/php/php-fpm.d/www.conf` | **sin cambios** (Arch ya usa el socket correcto) |
| `/etc/php/conf.d/oci8.ini` | instalado por el paquete `php-oci8` |
| `php-fpm.service`, `httpd.service` | habilitados con `systemctl enable` |
| `docker.service` | habilitado |
| `/srv/http/info.php` | página de prueba temporal |
| `/srv/http/recintos` | (pendiente) raíz del proyecto web |

---

## 5. Limpieza cuando el proyecto termine

Orden recomendado. El paso 1 es el único irreversible: **exporta la base antes**.

```fish
# 1. Respaldo lógico de la base (dentro del contenedor)
docker exec oracle-free sh -c 'expdp system/$ORACLE_PASSWORD FULL=Y DIRECTORY=/tmp DUMPFILE=recintos.dmp'
docker cp oracle-free:/tmp/recintos.dmp ./recintos.dmp

# 2. Detener y borrar contenedor + volumen
docker rm -f oracle-free
docker volume rm oracle-free-data

# 3. Borrar la imagen (libera 13,8 GB)
docker rmi container-registry.oracle.com/database/free:latest

# 4. Servicios
sudo systemctl disable --now httpd php-fpm

# 5. Paquetes
sudo pacman -Rns apache php php-fpm
yay -Rns php-oci8 oracle-instantclient-basic oracle-instantclient-sdk oracle-instantclient-sqlplus dbeaver-ce-jre-bin

# 6. Restos
sudo rm -f /srv/http/info.php
sudo rm -rf /srv/http/recintos
```

Advertencia: si se actualiza `php` sin recompilar, `oci8` deja de cargar hasta ejecutar `yay -S --rebuild php-oci8`.

---

## 6. Repositorio del proyecto

- Ruta en la torre: `/home/naiko/Proyectos/basedatos_u3` (sincronizada por Syncthing desde el notebook).
- Prototipo SQLite del modelo: `sql/sqlite/01_catalogos.sql`.
- Script de esta guía: `infra/01_apache_phpfpm.sh`.

---

## 7. Progreso

### 2026-11-15

- Modelo v2 aprobado: 24 tablas, `INSTALACION` reemplaza a `CANCHA`, se agregan `CARGO`/`PAGO_DETALLE`, `ROL`/`USUARIO`, `BLOQUEO_INSTALACION`, `MOVIMIENTO_STOCK` y `AUDITORIA`.
- Prototipo SQLite del Bloque A (`sql/sqlite/01_catalogos.sql`): 8 tablas, 78 tarifas, 49 horarios. Validado con pruebas negativas de constraints y FK compuesta.
- Stack instalado en la torre y **verificado funcional**: `GET /info.php` → 200 con `PHP 8.5.12` y `oci8: OK`.
- `httpd.conf` respaldado; `php-fpm` y `httpd` habilitados.
- Imagen `database/free:latest` descargada (13,8 GB).

Pendiente:
1. Crear el contenedor `oracle-free` (`--shm-size=1g` + volumen `oracle-free-data`).
2. Crear usuario/esquema de la aplicación en `FREEPDB1`.
3. Bloque B: `ROL`, `USUARIO`, `CLIENTE`, `RESERVA`, `CARGO`, `PAGO`, `PAGO_DETALLE` + trigger anti-solape.
4. DDL Oracle, aplicación PHP, 3 dashboards, video y PPT.
