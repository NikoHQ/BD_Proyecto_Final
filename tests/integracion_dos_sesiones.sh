#!/usr/bin/env bash
# =====================================================================
# Integracion con dos sesiones reales de Oracle (unidad 11, fase 3).
#
# Cinco carreras entre dos conexiones SQL*Plus distintas. En cada una la
# sesion A hace la operacion, duerme dentro de la transaccion y recien
# despues confirma; la sesion B intenta lo mismo y debe esperar el candado
# y recibir el codigo exacto que define el paquete.
#
#   1. Dos reservas del mismo bloque            -> una OK, otra -20043
#   2. Grande contra cancha 1                   -> la segunda -20043
#   3. Cancha 2 contra grande                   -> la segunda -20043
#   4. Ultimo cupo de un torneo                 -> una OK, otra -20063
#   5. Doble pago de la misma reserva           -> uno OK, otro -20053
#
# Uso:  bash tests/integracion_dos_sesiones.sh
#       KEEP=1 bash tests/integracion_dos_sesiones.sh   (deja el fixture)
#
# Los datos de prueba se crean y se borran con COMMIT, porque las sesiones
# tienen que verlos. El script limpia al empezar y al terminar, asi que se
# puede correr dos veces seguidas.
# =====================================================================

set -uo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$DIR/.." && pwd)"
CONT="${CONT:-sgcd-oracle}"
DBUSER="${DBUSER:-SGCD19}"
DBPASS="${DBPASS:-${SGCD_DB_PASSWORD:-}}"
if [ -z "$DBPASS" ] && [ -f "$ROOT/.env" ]; then
    DBPASS="$(sed -n 's/^SGCD_DB_PASSWORD=//p' "$ROOT/.env" | head -n 1)"
fi
: "${DBPASS:?Define DBPASS o SGCD_DB_PASSWORD para ejecutar esta prueba.}"
DBSVC="${DBSVC:-localhost/FREEPDB1}"
TMP="$(mktemp -d)"
FALLAS=0

trap 'rm -rf "$TMP"' EXIT

sql() {
    docker exec -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 -i "$CONT" \
        sqlplus -s -L "$DBUSER/$DBPASS@$DBSVC"
}

sesion() {
    docker exec -e LANG=C.UTF-8 -e NLS_LANG=AMERICAN_AMERICA.AL32UTF8 -i "$CONT" \
        sqlplus -s -L "$DBUSER/$DBPASS@$DBSVC" @/tmp/integracion/sesion.sql "$1" "$2"
}

contar() {
    printf 'SET PAGESIZE 0 FEEDBACK OFF HEADING OFF VERIFY OFF\n%s\n' "$1" \
        | sql | tr -d '[:space:]'
}

comprobar() { # descripcion, esperado, obtenido
    if [ "$2" = "$3" ]; then
        echo "OK    $1"
    else
        echo "FALLA $1 (esperaba '$2', obtuvo '$3')"
        FALLAS=$((FALLAS + 1))
    fi
}

token() { # archivo, linea esperada, descripcion
    if grep -q "$2" "$1"; then
        echo "OK    $3"
    else
        echo "FALLA $3"
        FALLAS=$((FALLAS + 1))
        sed 's/^/      /' "$1"
    fi
}

limpiar() {
    sql <<'SQL'
SET PAGESIZE 0 FEEDBACK OFF
DELETE FROM SGCD_PAGOS
WHERE  ID_RESERVA IN (
    SELECT r.ID_RESERVA
    FROM   SGCD_RESERVAS r
    WHERE  r.ID_CLIENTE IN (SELECT c.ID_CLIENTE FROM SGCD_CLIENTES c
                            WHERE c.RUT_CLIENTE BETWEEN 39000001 AND 39000003)
       OR  r.ID_TORNEO IN (SELECT t.ID_TORNEO FROM SGCD_TORNEOS t
                           WHERE t.NOMBRE_TORNEO LIKE 'CONCURRENCIA%'));
DELETE FROM SGCD_RESERVAS
WHERE  ID_CLIENTE IN (SELECT c.ID_CLIENTE FROM SGCD_CLIENTES c
                      WHERE c.RUT_CLIENTE BETWEEN 39000001 AND 39000003)
   OR  ID_TORNEO IN (SELECT t.ID_TORNEO FROM SGCD_TORNEOS t
                     WHERE t.NOMBRE_TORNEO LIKE 'CONCURRENCIA%');
DELETE FROM SGCD_EQUIPOS_JUGADORES
WHERE  ID_INSCRIPCION IN (
    SELECT i.ID_INSCRIPCION
    FROM   SGCD_INSCRIPCIONES_TORNEO i
    WHERE  i.ID_CLIENTE IN (SELECT c.ID_CLIENTE FROM SGCD_CLIENTES c
                            WHERE c.RUT_CLIENTE BETWEEN 39000001 AND 39000003)
       OR  i.ID_TORNEO IN (SELECT t.ID_TORNEO FROM SGCD_TORNEOS t
                           WHERE t.NOMBRE_TORNEO LIKE 'CONCURRENCIA%'));
DELETE FROM SGCD_INSCRIPCIONES_TORNEO
WHERE  ID_CLIENTE IN (SELECT c.ID_CLIENTE FROM SGCD_CLIENTES c
                      WHERE c.RUT_CLIENTE BETWEEN 39000001 AND 39000003)
   OR  ID_TORNEO IN (SELECT t.ID_TORNEO FROM SGCD_TORNEOS t
                     WHERE t.NOMBRE_TORNEO LIKE 'CONCURRENCIA%');
DELETE FROM SGCD_JUGADORES
WHERE  ID_CLIENTE IN (SELECT c.ID_CLIENTE FROM SGCD_CLIENTES c
                      WHERE c.RUT_CLIENTE BETWEEN 39000001 AND 39000003);
DELETE FROM SGCD_TORNEOS WHERE NOMBRE_TORNEO LIKE 'CONCURRENCIA%';
DELETE FROM SGCD_CLIENTES WHERE RUT_CLIENTE BETWEEN 39000001 AND 39000003;
COMMIT;
SQL
}

fixture() {
    sql <<'SQL'
SET SERVEROUTPUT OFF
DECLARE
    V_CLI    NUMBER;
    V_CREADA BOOLEAN;
    V_ADMIN  NUMBER;
    V_TORNEO NUMBER;
    V_RES    NUMBER;
BEGIN
    SELECT MIN(a.ID_ADMINISTRADOR) INTO V_ADMIN
    FROM   SGCD_ADMINISTRADORES a
    WHERE  a.ESTADO_ADMINISTRADOR = 'ACTIVO';
    SGCD_PKG_CLIENTES.crear_ficha(39000001, '4', 'Concurrencia A', NULL, NULL, V_CLI, V_CREADA);
    SGCD_PKG_CLIENTES.crear_ficha(39000002, '2', 'Concurrencia B', NULL, NULL, V_CLI, V_CREADA);
    SGCD_PKG_CLIENTES.crear_ficha(39000003, '0', 'Concurrencia C', NULL, NULL, V_CLI, V_CREADA);
    SGCD_PKG_TORNEOS.crear_torneo(1, 'CONCURRENCIA CUPO', TRUNC(SYSDATE, 'IW') + 8,
                                  TRUNC(SYSDATE, 'IW') + 15, 1, 5, V_TORNEO);
    SELECT c.ID_CLIENTE INTO V_CLI FROM SGCD_CLIENTES c WHERE c.RUT_CLIENTE = 39000001;
    SGCD_PKG_RESERVAS.crear_reserva(V_CLI, V_ADMIN, 4, 1, TRUNC(SYSDATE, 'IW') + 8,
                                    '13:00', 1, 'MOSTRADOR', V_RES);
    COMMIT;
END;
/
SQL
}

echo "== Integracion con dos sesiones (SGCD19 sobre $CONT) =="

docker exec "$CONT" mkdir -p /tmp/integracion
docker cp "$DIR/sesion.sql" "$CONT:/tmp/integracion/sesion.sql" >/dev/null

echo "-- limpieza previa"
limpiar
echo "-- fixture"
fixture

# Caso 1: mismo bloque en la misma cancha
sesion 1 A > "$TMP/a1" 2>&1 &
PID=$!
sleep 3
sesion 1 B > "$TMP/b1" 2>&1
wait "$PID"
token "$TMP/a1" "RESULTADO: OK" "caso 1: la sesion A reserva y confirma"
token "$TMP/b1" "RESULTADO: ERROR -20043" "caso 1: la sesion B recibe choque de horario"
comprobar "caso 1: queda una sola reserva en el bloque" "1" \
    "$(contar "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ID_CANCHA = 4 AND INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 10/24;")"

# Caso 2: la grande primero, despues su componente 1
sesion 2 A > "$TMP/a2" 2>&1 &
PID=$!
sleep 3
sesion 2 B > "$TMP/b2" 2>&1
wait "$PID"
token "$TMP/a2" "RESULTADO: OK" "caso 2: la sesion A ocupa la cancha grande"
token "$TMP/b2" "RESULTADO: ERROR -20043" "caso 2: la componente 1 no se puede ocupar"
comprobar "caso 2: la grande queda con una reserva" "1" \
    "$(contar "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ID_CANCHA = 7 AND INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 11/24;")"
comprobar "caso 2: la componente 1 queda libre" "0" \
    "$(contar "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ID_CANCHA = 1 AND INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 11/24;")"

# Caso 3: la componente 2 primero, despues la grande
sesion 3 A > "$TMP/a3" 2>&1 &
PID=$!
sleep 3
sesion 3 B > "$TMP/b3" 2>&1
wait "$PID"
token "$TMP/a3" "RESULTADO: OK" "caso 3: la sesion A ocupa la cancha 2"
token "$TMP/b3" "RESULTADO: ERROR -20043" "caso 3: la grande no se puede ocupar"
comprobar "caso 3: la cancha 2 queda con una reserva" "1" \
    "$(contar "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ID_CANCHA = 2 AND INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 12/24;")"
comprobar "caso 3: la grande queda libre a esa hora" "0" \
    "$(contar "SELECT COUNT(*) FROM SGCD_RESERVAS WHERE ID_CANCHA = 7 AND INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 12/24;")"

# Caso 4: el ultimo cupo del torneo
sesion 4 A > "$TMP/a4" 2>&1 &
PID=$!
sleep 3
sesion 4 B > "$TMP/b4" 2>&1
wait "$PID"
token "$TMP/a4" "RESULTADO: OK" "caso 4: la sesion A toma el ultimo cupo"
token "$TMP/b4" "RESULTADO: ERROR -20063" "caso 4: la sesion B recibe torneo sin cupos"
comprobar "caso 4: queda una sola inscripcion" "1" \
    "$(contar "SELECT COUNT(*) FROM SGCD_INSCRIPCIONES_TORNEO i JOIN SGCD_TORNEOS t ON t.ID_TORNEO = i.ID_TORNEO WHERE t.NOMBRE_TORNEO = 'CONCURRENCIA CUPO';")"

# Caso 5: doble pago de la misma reserva
sesion 5 A > "$TMP/a5" 2>&1 &
PID=$!
sleep 3
sesion 5 B > "$TMP/b5" 2>&1
wait "$PID"
token "$TMP/a5" "RESULTADO: OK" "caso 5: la sesion A registra el pago"
token "$TMP/b5" "RESULTADO: ERROR -20053" "caso 5: la sesion B recibe pago ya registrado"
comprobar "caso 5: queda un solo pago" "1" \
    "$(contar "SELECT COUNT(*) FROM SGCD_PAGOS p JOIN SGCD_RESERVAS r ON r.ID_RESERVA = p.ID_RESERVA WHERE r.INICIO_RESERVA = TRUNC(SYSDATE,'IW') + 8 + 13/24;")"

if [ "${KEEP:-0}" = "1" ]; then
    echo "-- fixture conservado (KEEP=1)"
else
    echo "-- limpieza final"
    limpiar
fi

echo "---"
if [ "$FALLAS" = "0" ]; then
    echo "RESULTADO: todas las comprobaciones pasaron"
    exit 0
else
    echo "RESULTADO: $FALLAS fallas"
    exit 1
fi
