#!/usr/bin/env bash
# Ejecutar contra una instancia local de pruebas conectada al esquema SGCD de 19 tablas.
set -euo pipefail

base=${SGCD_TEST_URL:-http://127.0.0.1:8080}
cookies=$(mktemp)
recinto=0 modalidad=0 cancha=0 horario=0 bloque=0 tarifa=0 segunda=0

status() {
  curl -sS -b "$cookies" -o /dev/null -w '%{http_code}' -H "X-CSRF-Token: $csrf" \
    -H 'Content-Type: application/json' --data "$3" "$base/dashboardadmin/api/$1.php?accion=$2"
}
get() {
  curl -fsS -b "$cookies" "$base/dashboardadmin/api/$1.php?$2"
}
post() {
  curl -fsS -b "$cookies" -H "X-CSRF-Token: $csrf" -H 'Content-Type: application/json' \
    --data "$3" "$base/dashboardadmin/api/$1.php?accion=$2"
}
cleanup() {
  for id in "$segunda" "$tarifa"; do
    if [[ $id != 0 ]]; then post tarifas borrar "{\"id\":$id}" >/dev/null || true; fi
  done
  for entity in bloque horario cancha modalidad recinto; do
    if [[ ${!entity} != 0 ]]; then post recintos "$entity-borrar" "{\"id\":${!entity}}" >/dev/null || true; fi
  done
  rm -f "$cookies"
}
trap cleanup EXIT

json() {
  jq -er "$1"
}
csrf=$(curl -fsS -c "$cookies" "$base/dashboardadmin/login.php" |
  sed -nE 's/.*name="csrf" value="([^"]+)".*/\1/p')
test -n "$csrf"
test "$(curl -fsS -b "$cookies" -c "$cookies" -o /dev/null -w '%{http_code}' \
  --data-urlencode "csrf=$csrf" --data-urlencode "login=${SGCD_TEST_LOGIN:-admin}" \
  --data-urlencode "password=${SGCD_TEST_PASSWORD:-admin}" "$base/dashboardadmin/login.php")" = 303
csrf=$(curl -fsS -b "$cookies" "$base/dashboardadmin/" |
  sed -nE 's/.*name="csrf-token" content="([^"]+)".*/\1/p')
test -n "$csrf"

sufijo="$(date +%s)-$$"
deporte=$(get recintos 'accion=modalidades' | json '.data.deportes[0].id')
recinto=$(post recintos recinto-guardar "{\"nombre\":\"Recinto prueba $sufijo\",\"direccion\":\"Calle de prueba\",\"estado\":\"ACTIVO\"}" | json '.data.id')
modalidad=$(post recintos modalidad-guardar "{\"nombre\":\"Modalidad prueba $sufijo\",\"deporte\":$deporte,\"maximo\":2}" | json '.data.id')
cancha=$(post recintos cancha-guardar "{\"nombre\":\"Cancha prueba\",\"recinto\":$recinto,\"tipo\":\"CANCHA\",\"estado\":\"DISPONIBLE\",\"modalidades\":[$modalidad]}" | json '.data.id')
cancha_invalida="{\"nombre\":\"Cancha inválida\",\"recinto\":$recinto,\"tipo\":\"CANCHA\",\"estado\":\"DISPONIBLE\",\"modalidades\":[$modalidad,999999999]}"
codigo=$(status recintos cancha-guardar "$cancha_invalida")
if [[ "$codigo" != 409 ]]; then
  echo "Se esperaba HTTP 409 al asignar una modalidad inexistente y se obtuvo $codigo." >&2
  exit 1
fi
get catalogo "" | json ".data.canchas | map(select(.recinto == $recinto)) | length == 1" >/dev/null
echo 'Altas de recinto, modalidad y cancha verificadas.'
get recintos "accion=cancha-modalidades&id=$cancha" | json ".data == [$modalidad]" >/dev/null
post recintos cancha-estado "{\"id\":$cancha,\"estado\":\"MANTENCION\"}" >/dev/null
get catalogo "" | json ".data.canchas[] | select(.id == $cancha) | .estado == \"MANTENCION\"" >/dev/null
horario=$(post recintos horario-guardar "{\"recinto\":$recinto,\"dia\":2,\"apertura\":\"08:00\",\"cierre\":\"12:00\"}" | json '.data.id')
bloque=$(post recintos bloque-guardar "{\"horario\":$horario,\"inicio\":\"08:00\",\"fin\":\"09:00\"}" | json '.data.id')
post recintos bloque-guardar "{\"id\":$bloque,\"inicio\":\"09:00\",\"fin\":\"10:00\"}" >/dev/null
get recintos "accion=bloques&id=$horario" | json ".data | length == 1 and .[0].inicio == \"09:00\"" >/dev/null
[[ $(status recintos horario-borrar "{\"id\":$horario}") == 409 ]]
echo 'Horarios, bloques y validación de dependencias verificados.'

vigencia=$(php -r 'echo (new DateTimeImmutable("+7 days"))->format("Y-m-d");')
tarifa=$(post tarifas crear "{\"cancha\":$cancha,\"modalidad\":$modalidad,\"dia\":2,\"inicio\":\"08:00\",\"fin\":\"12:00\",\"desde\":\"$vigencia\",\"valor\":10000}" | json '.data.id')
[[ $(status tarifas dividir "{\"id\":$tarifa,\"hora\":\"10:00\",\"valor\":0}") == 400 ]]
get tarifas "cancha=$cancha" | json '.data | length == 1 and .[0].fin == "12:00"' >/dev/null
[[ $(status recintos cancha-borrar "{\"id\":$cancha}") == 409 ]]
get recintos "accion=cancha-modalidades&id=$cancha" | json ".data == [$modalidad]" >/dev/null
segunda=$(post tarifas dividir "{\"id\":$tarifa,\"hora\":\"10:00\",\"valor\":12000}" | json '.data.id')
get tarifas "cancha=$cancha" | json ".data | length == 2 and .[0].fin == \"10:00\" and .[1].inicio == \"10:00\" and .[1].valor == 12000" >/dev/null
post tarifas estado "{\"id\":$segunda,\"estado\":\"INACTIVA\"}" >/dev/null
get tarifas "cancha=$cancha&estado=INACTIVA" | json ".data[0].id == $segunda" >/dev/null
post tarifas borrar "{\"id\":$segunda}" >/dev/null
segunda=0
post tarifas borrar "{\"id\":$tarifa}" >/dev/null
tarifa=0
post recintos bloque-borrar "{\"id\":$bloque}" >/dev/null
bloque=0
post recintos horario-borrar "{\"id\":$horario}" >/dev/null
horario=0
post recintos cancha-borrar "{\"id\":$cancha}" >/dev/null
cancha=0
post recintos modalidad-borrar "{\"id\":$modalidad}" >/dev/null
modalidad=0
post recintos recinto-borrar "{\"id\":$recinto}" >/dev/null
recinto=0
echo 'Tarifas, división de franja, estado y eliminación de registros verificados.'
