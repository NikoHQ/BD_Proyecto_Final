#!/usr/bin/env bash
set -euo pipefail

base_url="${1:-http://127.0.0.1:8080}"

estado() {
  curl -sS -o /dev/null -w '%{http_code}' "$1"
}

[[ "$(estado "$base_url/cliente/")" == "200" ]] || {
  echo 'La portada del cliente debe poder abrirse sin iniciar sesión.' >&2
  exit 1
}
[[ "$(estado "$base_url/api/catalogo.php")" == "200" ]] || {
  echo 'El catálogo para armar la búsqueda debe ser público.' >&2
  exit 1
}
catalogo="$(curl -sS "$base_url/api/catalogo.php")"
printf '%s' "$catalogo" | grep -q '"bloques"' || {
  echo 'El catálogo público debe incluir los bloques reales configurados en Oracle.' >&2
  exit 1
}
jq -e '.data.modalidades | any(.nombre == "Fútbol 6" and .minimo == 6 and .maximo == 10)
  and any(.nombre == "Pádel dobles" and .minimo == 2 and .maximo == 2)
  and any(.nombre == "Tenis" and .minimo == 1 and .maximo == 1)' <<<"$catalogo" >/dev/null || {
  echo 'El catálogo debe publicar los rangos de jugadores de cada modalidad.' >&2
  exit 1
}
[[ "$(estado "$base_url/api/reservas.php?accion=disponible&cancha=1&modalidad=1&fecha=2026-12-01&hora=10:00&bloques=1")" == "401" ]] || {
  echo 'La consulta de disponibilidad debe seguir pidiendo inicio de sesión.' >&2
  exit 1
}

echo 'Portal público: OK'
