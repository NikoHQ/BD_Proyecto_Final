<?php
declare(strict_types=1);
require_once __DIR__ . '/includes/auth.php';
authStart();

header('Content-Type: application/json; charset=utf-8');
header('Cache-Control: no-store');

try {
    if (!currentAccount()) {
        http_response_code(401);
        echo json_encode(['error' => 'Inicia sesión para consultar el catálogo.']);
        exit;
    }
    $service = '//' . getenv('SGCD_DB_HOST') . ':' . getenv('SGCD_DB_PORT') . '/' . getenv('SGCD_DB_SERVICE');
    $connection = @oci_connect(getenv('SGCD_DB_USER'), getenv('SGCD_DB_PASSWORD'), $service, 'AL32UTF8');
    if (!$connection) {
        throw new RuntimeException('Conexión a Oracle no disponible.');
    }
    $queries = [
        'recintos' => 'SELECT ID_RECINTO, NOMBRE_RECINTO, COMUNA_RECINTO, DIRECCION_RECINTO, ESTADO_RECINTO
                       FROM SGCD_RECINTOS ORDER BY ID_RECINTO',
        'horarios' => 'SELECT ID_RECINTO, DIA_SEMANA_HORARIO, HORA_APERTURA_HORARIO, HORA_CIERRE_HORARIO
                        FROM SGCD_HORARIOS ORDER BY ID_RECINTO, DIA_SEMANA_HORARIO',
        'canchas' => "SELECT c.ID_RECINTO, c.ID_CANCHA, c.NOMBRE_CANCHA, c.TIPO_CANCHA, c.ESTADO_CANCHA,
                       c.SUPERFICIE_CANCHA, m.NOMBRE_MODALIDAD, d.NOMBRE_DEPORTE,
                       (SELECT COUNT(*) FROM SGCD_TARIFAS t WHERE t.ID_CANCHA = c.ID_CANCHA
                        AND t.ID_MODALIDAD = m.ID_MODALIDAD AND t.ESTADO_TARIFA = 'ACTIVA') AS TARIFAS_ACTIVAS
                       FROM SGCD_CANCHAS c
                       LEFT JOIN SGCD_CANCHAS_MODALIDADES cm ON c.ID_CANCHA = cm.ID_CANCHA
                       LEFT JOIN SGCD_MODALIDADES m ON cm.ID_MODALIDAD = m.ID_MODALIDAD
                       LEFT JOIN SGCD_DEPORTES d ON m.ID_DEPORTE = d.ID_DEPORTE
                       ORDER BY c.ID_RECINTO, c.ID_CANCHA, m.NOMBRE_MODALIDAD",
    ];
    $catalog = [];
    foreach ($queries as $name => $query) {
        $statement = oci_parse($connection, $query);
        if (!$statement || !@oci_execute($statement, OCI_NO_AUTO_COMMIT)) {
            throw new RuntimeException('Error al consultar el catálogo.');
        }
        oci_fetch_all($statement, $catalog[$name], 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
        oci_free_statement($statement);
    }
    echo json_encode($catalog, JSON_THROW_ON_ERROR);
} catch (Throwable $error) {
    http_response_code(503);
    echo json_encode(['error' => 'No se pudo consultar el catálogo de Oracle.']);
}
