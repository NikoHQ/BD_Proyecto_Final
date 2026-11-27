#!/usr/bin/env bash
# =====================================================================
# Deja el esquema SGCD en la foto curada de la demostración.
#
# Borra y recrea las 19 tablas, carga los catálogos, compila los paquetes y
# agrega los datos operativos del script 15. Sirve para volver al estado
# inicial después de un ensayo, en un solo comando.
#
# ADVERTENCIA: elimina TODAS las tablas SGCD_* del esquema indicado. No usar
# sobre una base con información real.
#
# Uso:
#   bash infra/reiniciar-demo.sh          (pide confirmación)
#   bash infra/reiniciar-demo.sh --si     (sin confirmación, para guiones)
#
# Variables:
#   CONT     contenedor de Oracle        (por defecto oracle-free)
#   DBUSER   esquema de la aplicación    (por defecto SGCD)
#   DBPASS   clave del esquema           (si falta, se busca en .env y en
#                                         el pool de php-fpm)
#   DBSVC    servicio TNS                (por defecto localhost/FREEPDB1)
# =====================================================================

set -euo pipefail
cd "$(dirname "$0")/.."

CONT="${CONT:-oracle-free}"
DBUSER="${DBUSER:-SGCD}"
DBSVC="${DBSVC:-localhost/FREEPDB1}"

fallar() {
    printf 'ERROR: %s\n' "$1" >&2
    exit 1
}

# --- clave -----------------------------------------------------------
DBPASS="${DBPASS:-${SGCD_DB_PASSWORD:-}}"
if [[ -z "$DBPASS" && -f .env ]]; then
    DBPASS="$(sed -n 's/^SGCD_DB_PASSWORD=//p' .env | head -n 1)"
fi
if [[ -z "$DBPASS" && -r /etc/php/php-fpm.d/www.conf ]]; then
    DBPASS="$(sed -n 's/^env\[SGCD_DB_PASSWORD\][[:space:]]*=[[:space:]]*//p' \
        /etc/php/php-fpm.d/www.conf | head -n 1)"
fi
if [[ -z "$DBPASS" ]]; then
    fallar 'Define DBPASS o SGCD_DB_PASSWORD (o revisa .env / el pool de php-fpm).'
fi
if [[ "$DBPASS" == *'"'* || "$DBPASS" == *$'\n'* || "$DBPASS" == *$'\r'* ]]; then
    fallar 'La clave no puede contener comillas dobles ni saltos de línea.'
fi

# --- argumentos ------------------------------------------------------
confirmado=false
for opcion in "$@"; do
    case "$opcion" in
        --si) confirmado=true ;;
        *) fallar "Opción desconocida: $opcion. Usa --si para omitir la confirmación." ;;
    esac
done

if [[ "$confirmado" != true ]]; then
    printf 'Se borrarán TODAS las tablas SGCD_* de %s en el contenedor %s.\n' "$DBUSER" "$CONT"
    printf 'Escribe REINICIAR para continuar: '
    read -r respuesta </dev/tty || fallar 'No se pudo leer la confirmación.'
    [[ "$respuesta" == 'REINICIAR' ]] || fallar 'Cancelado.'
fi

# --- fecha de referencia ---------------------------------------------
referencia="$(sed -n "s/.*c_referencia CONSTANT DATE := DATE '\([0-9-]*\)'.*/\1/p" \
    sql/oracle/15_datos_operativos_sgcd_19.sql | head -n 1)"
hoy="$(date +%F)"
if [[ -n "$referencia" && "$referencia" != "$hoy" ]]; then
    printf '\nADVERTENCIA: los datos están fechados el %s y hoy es %s.\n' "$referencia" "$hoy"
    printf 'La agenda mostrará como pasadas las reservas de la referencia.\n'
    printf 'Actualiza c_referencia en sql/oracle/15_datos_operativos_sgcd_19.sql si la demo es otro día.\n\n'
fi

# --- contenedor ------------------------------------------------------
docker inspect "$CONT" >/dev/null 2>&1 || fallar "No existe el contenedor $CONT."
if [[ "$(docker inspect -f '{{.State.Running}}' "$CONT")" != true ]]; then
    echo "Levantando $CONT..."
    docker start "$CONT" >/dev/null
fi
for _ in $(seq 1 40); do
    estado="$(docker inspect -f '{{if .State.Health}}{{.State.Health.Status}}{{else}}sin-healthcheck{{end}}' "$CONT")"
    [[ "$estado" == healthy || "$estado" == sin-healthcheck ]] && break
    sleep 3
done
[[ "$estado" == healthy || "$estado" == sin-healthcheck ]] \
    || fallar "El contenedor $CONT no quedó disponible (estado: $estado)."

# --- utilidades SQL --------------------------------------------------
# La clave viaja por stdin, no como argumento del proceso.
sql_archivo() {
    local archivo=$1
    {
        printf 'whenever sqlerror exit failure rollback\n'
        printf 'whenever oserror exit failure\n'
        printf 'set define off echo off verify off feedback off pagesize 0 heading off\n'
        printf 'connect %s/"%s"@%s\n' "$DBUSER" "$DBPASS" "$DBSVC"
        cat "$archivo"
        printf '\nexit\n'
    } | docker exec -i -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
        "$CONT" sqlplus -s -L /nolog
}

sql_valor() {
    local consulta=$1
    {
        printf 'set pagesize 0 heading off feedback off verify off\n'
        printf 'connect %s/"%s"@%s\n' "$DBUSER" "$DBPASS" "$DBSVC"
        printf '%s\n' "$consulta"
        printf 'exit\n'
    } | docker exec -i -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 \
        "$CONT" sqlplus -s -L /nolog | tr -d '[:space:]'
}

paso() {
    printf '  %-44s' "$1"
}

# --- reconstrucción --------------------------------------------------
echo "Reiniciando la demo en $DBUSER@$DBSVC (contenedor $CONT)."

paso '19 tablas y secuencias (10_ddl)'
sql_archivo sql/oracle/10_ddl_sgcd_19.sql >/dev/null
echo 'OK'

paso 'catálogos y cuentas (11_catalogos)'
sql_archivo sql/oracle/11_catalogos_sgcd_19.sql >/dev/null
echo 'OK'

for paquete in 12a_pkg_auth 12b_pkg_clientes 12c_mantenedores_catalogo \
               12d_mantenedores_horario 12e_mantenedor_tarifas 12f_pkg_tarifas \
               12g_pkg_reservas 12h_pkg_pagos 12i_pkg_torneos 12j_pkg_consultas; do
    paso "paquete $paquete"
    sql_archivo "sql/oracle/$paquete.sql" >/dev/null
    echo 'OK'
done

paso 'objetos válidos y sin errores'
invalidos="$(sql_valor "SELECT COUNT(*) FROM USER_OBJECTS WHERE STATUS <> 'VALID' AND OBJECT_NAME LIKE 'SGCD%';")"
errores="$(sql_valor 'SELECT COUNT(*) FROM USER_ERRORS;')"
if [[ "$invalidos" != 0 || "$errores" != 0 ]]; then
    echo "FALLA (inválidos=$invalidos, errores=$errores)"
    fallar 'Revisa USER_ERRORS antes de continuar.'
fi
echo 'OK'

paso 'datos operativos (15)'
sql_archivo sql/oracle/15_datos_operativos_sgcd_19.sql >/dev/null
echo 'OK'

# --- resumen ---------------------------------------------------------
reservas="$(sql_valor 'SELECT COUNT(*) FROM SGCD_RESERVAS;')"
pagos="$(sql_valor "SELECT COUNT(*) FROM SGCD_PAGOS WHERE ESTADO_PAGO = 'PAGADO';")"
clientes="$(sql_valor 'SELECT COUNT(*) FROM SGCD_CLIENTES;')"
inscripciones="$(sql_valor 'SELECT COUNT(*) FROM SGCD_INSCRIPCIONES_TORNEO;')"
torneos="$(sql_valor 'SELECT COUNT(*) FROM SGCD_TORNEOS;')"
pendientes="$(sql_valor "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ORIGEN_RESERVA = 'WEB' AND ESTADO_RESERVA = 'PENDIENTE';")"

echo
echo 'Foto de la demo:'
printf '  %-22s %s\n' 'Reservas' "$reservas"
printf '  %-22s %s\n' '  web pendientes' "$pendientes"
printf '  %-22s %s\n' 'Pagos vigentes' "$pagos"
printf '  %-22s %s\n' 'Clientes' "$clientes"
printf '  %-22s %s\n' 'Inscripciones' "$inscripciones"
printf '  %-22s %s\n' 'Torneos' "$torneos"

if [[ "$reservas" != 48 || "$pagos" != 31 || "$clientes" != 21 || \
      "$inscripciones" != 10 || "$torneos" != 3 || "$pendientes" != 4 ]]; then
    printf '\nADVERTENCIA: los totales no coinciden con la foto esperada (48/31/21/10/3/4).\n' >&2
    printf 'Revisa la salida del script 15 antes de la demostración.\n' >&2
    exit 1
fi

echo
echo 'Listo. Panel: http://localhost/dashboardadmin/  (admin / admin)'
echo '       Portal: http://localhost/cliente/        (demo / SGCDdemo2026)'
