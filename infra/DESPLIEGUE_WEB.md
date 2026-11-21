# Desplegar el panel en Apache

El panel corre sobre el Apache 2.4 + PHP-FPM nativo de la torre, con `oci8` contra el contenedor
`oracle-free` que ya existe. **No** se usa `docker compose`: el `compose.yaml` de la entrega
levantaba un segundo Oracle en 1521 y un PHP 8.4 distinto al instalado.

- `DocumentRoot` = `/srv/http` (ya configurado en `httpd.conf`).
- PHP-FPM escucha en `/run/php-fpm/php-fpm.sock` y corre como `http`.
- `httpd.conf` ya envía los `.php` a ese socket (bloque `SetHandler` de la línea ~547).

Los comandos están en **fish**. Ejecutar desde la raíz del repositorio.

## 1. Variables de la base para PHP-FPM

`auth.php` y `catalogo-oracle.php` leen `SGCD_DB_*` con `getenv()`. Con PHP-FPM esas variables no
salen del shell: hay que declararlas en el pool. Se agregan al final de `www.conf`, que a esa
altura sigue dentro de `[www]`.

```fish
read -s -P "Clave del usuario SGCD: " SGCDPW

grep -q '^env\[SGCD_DB_HOST\]' /etc/php/php-fpm.d/www.conf
or printf 'env[SGCD_DB_HOST] = 127.0.0.1\nenv[SGCD_DB_PORT] = 1521\nenv[SGCD_DB_SERVICE] = FREEPDB1\nenv[SGCD_DB_USER] = SGCD\nenv[SGCD_DB_PASSWORD] = %s\n' "$SGCDPW" | sudo tee -a /etc/php/php-fpm.d/www.conf > /dev/null
```

La clave queda solo en `/etc/php/php-fpm.d/www.conf` (root, fuera del repo). El `read -s` evita
que aparezca en el historial de fish. El `grep` hace el paso repetible: si las variables ya están,
no las duplica.

## 2. Copiar el panel

```fish
sudo rsync -a --delete $PWD/web/ /srv/http/
sudo chown -R http:http /srv/http
```

`/srv/http` está dedicado al panel, por eso `--delete` no borra nada ajeno. El `chown` es necesario
porque PHP-FPM y Apache corren como `http`, no como `naiko`.

## 3. Recargar y comprobar

```fish
sudo systemctl restart php-fpm
systemctl is-active httpd php-fpm
curl -s -o /dev/null -w 'login %{http_code}\n' http://127.0.0.1/login.php
```

Debe responder `login 200`. Luego entra en <http://127.0.0.1/> con `ADMIN` / `admin`.

## 4. Si algo falla

| Síntoma | Revisar |
| --- | --- |
| `503 El acceso no está disponible` | Variables `SGCD_DB_*`: `sudo grep SGCD /etc/php/php-fpm.d/www.conf`, y que el contenedor esté `healthy` |
| El navegador descarga el `.php` | Falta el bloque `SetHandler` o no se reinició `httpd` |
| `Permission denied` al leer archivos | `sudo chown -R http:http /srv/http` |
| Página vieja tras editar | `rsync` no se ejecutó o Apache tiene caché: recarga con Ctrl+F5 |

Para revertir el despliegue: `sudo rsync -a --delete web/ /srv/http/` desde otro commit, o vaciar
`/srv/http`. Para quitar las variables: borrar las líneas `env[SGCD_DB_*]` de `www.conf` y
reiniciar `php-fpm`.

## 5. Mientras se desarrolla

No hace falta desplegar en cada cambio: el servidor embebido sirve `web/` directo desde el repo.

```fish
env SGCD_DB_HOST=127.0.0.1 SGCD_DB_PORT=1521 SGCD_DB_SERVICE=FREEPDB1 SGCD_DB_USER=SGCD \
    'SGCD_DB_PASSWORD=<clave>' php -d opcache.enable_cli=0 -S 127.0.0.1:8090 -t web
```

`php -S` trae OPcache activo para CLI y sirve la versión anterior de los archivos editados; por eso
se arranca con `-d opcache.enable_cli=0`. Si no, se pierde media hora persiguiendo errores que ya
no existen.

Para verlo desde otra máquina, cambia `127.0.0.1:8090` por `0.0.0.0:8090` (queda expuesto en la
red local; úsalo solo con datos de prueba).
