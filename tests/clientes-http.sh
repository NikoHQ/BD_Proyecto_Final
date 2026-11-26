#!/usr/bin/env bash
# Ejecutar contra una instancia local con el esquema de pruebas y las cuentas de 11_catalogos.
set -euo pipefail

base=${SGCD_TEST_URL:-http://127.0.0.1:8080}
cookies=$(mktemp)
trap 'unlink "$cookies"' EXIT

csrf=$(curl -fsS -c "$cookies" "$base/dashboardadmin/login.php" |
  sed -nE 's/.*name="csrf" value="([^"]+)".*/\1/p')
test -n "$csrf"
status=$(curl -fsS -b "$cookies" -c "$cookies" -o /dev/null -w '%{http_code}' \
  --data-urlencode "csrf=$csrf" --data-urlencode "login=${SGCD_TEST_LOGIN:-admin}" \
  --data-urlencode "password=${SGCD_TEST_PASSWORD:-admin}" "$base/dashboardadmin/login.php")
test "$status" = 303
csrf=$(curl -fsS -b "$cookies" "$base/dashboardadmin/" |
  sed -nE 's/.*name="csrf-token" content="([^"]+)".*/\1/p')
test -n "$csrf"

api="$base/api/clientes.php"
post() {
  curl -fsS -b "$cookies" -H "X-CSRF-Token: $csrf" -H 'Content-Type: application/json' \
    -d "$2" "$api?accion=$1"
}
check() {
  php -r '$r = json_decode(stream_get_contents(STDIN), true, 512, JSON_THROW_ON_ERROR);
    if (empty($r["ok"])) exit(1);
    $d = $r["data"]; '"$1"
}

# RUT reproducible que distingue esta prueba de las cuentas del catálogo.
ficha=$(post crear '{"rut":"31.000.004-3","nombre":"Prueba HTTP de clientes"}')
id=$(printf '%s' "$ficha" | check 'if (empty($d["creada"])) exit(1); echo $d["id"];')
trap 'post borrar "{\"id\":$id}" >/dev/null || true; unlink "$cookies"' EXIT
printf '%s' "$ficha" | check 'if ($d["reservas"] !== 0 || $d["cuenta_web"] !== false) exit(1);'

curl -fsS -b "$cookies" "$api?texto=31.000.004-3" |
  check 'if ($d["total"] !== 1 || $d["items"][0]["rut"] !== "31000004-3") exit(1);'
post actualizar "{\"id\":$id,\"nombre\":\"Prueba HTTP actualizada\"}" |
  check 'if ($d["nombre"] !== "Prueba HTTP actualizada" || $d["eventos_auditoria"] < 1) exit(1);'
post estado "{\"id\":$id,\"estado\":\"INACTIVO\"}" |
  check 'if ($d["estado"] !== "INACTIVO") exit(1);'

first=$(curl -fsS -b "$cookies" "$api?tamano=2&pagina=1")
second=$(curl -fsS -b "$cookies" "$api?tamano=2&pagina=2")
items() { printf '%s' "$1" | check 'echo implode(",", array_column($d["items"], "id"));'; }
test -n "$(items "$second")"
case ",$(items "$first")," in
  *,"$(items "$second" | cut -d, -f1)",*) exit 1 ;;
esac

post borrar "{\"id\":$id}" | check 'if ($d["borrado"] !== true) exit(1);'
trap 'unlink "$cookies"' EXIT
status=$(curl -sS -b "$cookies" -o /dev/null -w '%{http_code}' "$api?accion=ver&id=$id")
test "$status" = 404
echo 'Clientes HTTP: alta, búsqueda por RUT, detalle, edición, estado, paginación y baja correctos.'
