#!/usr/bin/env bash
# Publica web/ en /srv/http sin sudo, usando la ACL de naiko sobre el destino.
#
# Se usa rsync sin -p/-t a proposito: los archivos que ya existen son de
# http:http y naiko no es dueno, asi que no puede cambiarles permisos ni
# fechas. El contenido, la creacion y el borrado si estan permitidos por ACL.
#
# Uso:  bash infra/desplegar-web.sh
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINO="${DESTINO:-/srv/http}"

rsync -rl --no-perms --no-times --omit-dir-times --delete "$DIR/web/" "$DESTINO/"
echo "web desplegada en $DESTINO"
