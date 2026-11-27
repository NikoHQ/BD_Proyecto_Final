#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://127.0.0.1:8080}"
tmpdir=$(mktemp -d)

curl -sS -c "$tmpdir/cookies" "$base_url/cliente/login.php" -o "$tmpdir/login.html"
csrf=$(sed -n 's/.*name="csrf" value="\([^"]*\)".*/\1/p' "$tmpdir/login.html" | head -n 1)
curl -sS -L -b "$tmpdir/cookies" -c "$tmpdir/cookies" \
  -d "csrf=$csrf&login=nuevo&password=SGCDdemo2026" "$base_url/cliente/login.php" -o /dev/null
curl -sS -b "$tmpdir/cookies" "$base_url/cliente/" -o "$tmpdir/portal.html"
token=$(sed -n 's/.*name="csrf-token" content="\([^"]*\)".*/\1/p' "$tmpdir/portal.html" | head -n 1)
codigo=$(curl -sS -o "$tmpdir/respuesta.json" -w '%{http_code}' -b "$tmpdir/cookies" \
  -H 'Content-Type: application/json' -H "X-CSRF-Token: $token" \
  -X POST "$base_url/api/reservas.php?accion=cancelar" --data '{"id":34}')

[[ "$codigo" == "403" ]] || {
  echo "Una reserva ajena debe rechazarse con 403, se obtuvo $codigo." >&2
  exit 1
}
grep -q 'No puedes cancelar esa reserva' "$tmpdir/respuesta.json" || {
  echo 'La API debe explicar que la reserva no pertenece al cliente.' >&2
  exit 1
}
echo 'Autorización de cancelación: OK'
