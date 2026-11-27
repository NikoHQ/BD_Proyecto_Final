#!/usr/bin/env bash
# Verifica que el portal no pueda dejar una plantilla incompleta en Oracle.
set -euo pipefail

base_url="${1:-http://127.0.0.1:8080}"
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT

curl -sS -c "$tmpdir/cookies" "$base_url/cliente/login.php" -o "$tmpdir/login.html"
csrf=$(sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' "$tmpdir/login.html" | head -n 1)
# El cliente demo tiene inscripciones en torneos con maximo mayor que uno,
# que es lo que necesita este contrato para intentar una plantilla incompleta.
curl -sS -L -b "$tmpdir/cookies" -c "$tmpdir/cookies" \
  -d "csrf=$csrf&login=demo&password=SGCDdemo2026" "$base_url/cliente/login.php" -o /dev/null
curl -sS -b "$tmpdir/cookies" "$base_url/cliente/" -o "$tmpdir/portal.html"
token=$(sed -n 's/.*name="csrf-token" content="\([^"]*\)".*/\1/p' "$tmpdir/portal.html" | head -n 1)

curl -sS -b "$tmpdir/cookies" "$base_url/api/torneos.php?accion=torneos" -o "$tmpdir/torneos.json"
inscripcion=$(jq -er '.data[] | select(.mi_inscripcion != null and .maximo > 1) | .mi_inscripcion' "$tmpdir/torneos.json" | head -n 1)
curl -sS -b "$tmpdir/cookies" "$base_url/api/torneos.php?accion=detalle&id=$inscripcion" -o "$tmpdir/antes.json"
codigo=$(curl -sS -o "$tmpdir/respuesta.json" -w '%{http_code}' -b "$tmpdir/cookies" \
  -H 'Content-Type: application/json' -H "X-CSRF-Token: $token" \
  -X POST "$base_url/api/torneos.php?accion=actualizar" \
  --data "{\"inscripcion\":$inscripcion,\"equipo\":\"No debe cambiar\",\"jugadores\":[]}")
[[ "$codigo" == "400" ]] || { echo "Se esperaba HTTP 400 y se obtuvo $codigo." >&2; exit 1; }
grep -q 'La plantilla debe tener al menos' "$tmpdir/respuesta.json" || {
  echo 'La API debe explicar que la plantilla no está completa.' >&2
  exit 1
}
curl -sS -b "$tmpdir/cookies" "$base_url/api/torneos.php?accion=detalle&id=$inscripcion" -o "$tmpdir/despues.json"
cmp -s "$tmpdir/antes.json" "$tmpdir/despues.json" || {
  echo 'Una plantilla incompleta no puede alterar la inscripción.' >&2
  exit 1
}
echo 'Plantilla completa de torneo: OK'
