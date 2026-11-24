<?php
declare(strict_types=1);

/**
 * Consultas de lectura para la pantalla de pagos. La regla de cobro sigue en
 * SGCD_PKG_PAGOS; aqui solo se arma la cartera del dia.
 */

function pagosFilas(string $sql, array $binds = []): array
{
    $sentencia = authQuery($sql, $binds);
    $filas = [];
    oci_fetch_all($sentencia, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    oci_free_statement($sentencia);
    return $filas;
}

/** Pagos registrados entre dos fechas Y-m-d, ambas incluidas. */
function pagosLista(string $desde, string $hasta): array
{
    $siguiente = (new DateTimeImmutable($hasta))->modify('+1 day')->format('Y-m-d');
    $filas = pagosFilas(
        'SELECT p.ID_PAGO, p.ID_RESERVA, p.IMPORTE_PAGO, p.FECHA_PAGO, p.MEDIO_PAGO,
                p.ESTADO_PAGO, r.IMPORTE_ACORDADO, r.INICIO_RESERVA, r.ESTADO_RESERVA,
                c.NOMBRE_CLIENTE, ca.NOMBRE_CANCHA
           FROM SGCD_PAGOS p
           JOIN SGCD_RESERVAS r ON r.ID_RESERVA = p.ID_RESERVA
           JOIN SGCD_CANCHAS ca ON ca.ID_CANCHA = r.ID_CANCHA
           LEFT JOIN SGCD_CLIENTES c ON c.ID_CLIENTE = r.ID_CLIENTE
          WHERE p.FECHA_PAGO >= :desde AND p.FECHA_PAGO < :hasta
          ORDER BY p.FECHA_PAGO DESC, p.ID_PAGO DESC',
        ['desde' => $desde . ' 00:00:00', 'hasta' => $siguiente . ' 00:00:00']
    );
    return array_map(static fn(array $f): array => [
        'id' => (int) $f['ID_PAGO'],
        'reserva' => (int) $f['ID_RESERVA'],
        'importe' => (float) $f['IMPORTE_PAGO'],
        'fecha' => substr((string) $f['FECHA_PAGO'], 0, 10),
        'medio' => $f['MEDIO_PAGO'],
        'estado' => $f['ESTADO_PAGO'],
        'acordado' => (float) $f['IMPORTE_ACORDADO'],
        'cliente' => $f['NOMBRE_CLIENTE'],
        'cancha' => $f['NOMBRE_CANCHA'],
        'inicio' => $f['INICIO_RESERVA'],
        'estado_reserva' => $f['ESTADO_RESERVA'],
    ], $filas);
}

/** Reservas confirmadas que todavia no tienen un pago vigente. */
function reservasPorCobrar(?string $desde = null, ?string $hasta = null): array
{
    $sql = 'SELECT r.ID_RESERVA, r.INICIO_RESERVA, r.TERMINO_RESERVA, r.IMPORTE_ACORDADO,
                   r.ESTADO_RESERVA, c.NOMBRE_CLIENTE, ca.NOMBRE_CANCHA
              FROM SGCD_RESERVAS r
              JOIN SGCD_CANCHAS ca ON ca.ID_CANCHA = r.ID_CANCHA
              LEFT JOIN SGCD_CLIENTES c ON c.ID_CLIENTE = r.ID_CLIENTE
              LEFT JOIN SGCD_PAGOS p ON p.ID_RESERVA = r.ID_RESERVA AND p.ESTADO_PAGO = \'PAGADO\'
             WHERE r.ESTADO_RESERVA = \'CONFIRMADA\' AND p.ID_PAGO IS NULL';
    $binds = [];
    if ($desde !== null && $hasta !== null) {
        $siguiente = (new DateTimeImmutable($hasta))->modify('+1 day')->format('Y-m-d');
        $sql .= ' AND r.INICIO_RESERVA >= :desde AND r.INICIO_RESERVA < :hasta';
        $binds = ['desde' => $desde . ' 00:00:00', 'hasta' => $siguiente . ' 00:00:00'];
    }
    $sql .= ' ORDER BY r.INICIO_RESERVA, ca.NOMBRE_CANCHA';
    return array_map(static fn(array $f): array => [
        'reserva' => (int) $f['ID_RESERVA'],
        'inicio' => $f['INICIO_RESERVA'],
        'termino' => $f['TERMINO_RESERVA'],
        'importe' => (float) $f['IMPORTE_ACORDADO'],
        'estado' => $f['ESTADO_RESERVA'],
        'cliente' => $f['NOMBRE_CLIENTE'],
        'cancha' => $f['NOMBRE_CANCHA'],
    ], pagosFilas($sql, $binds));
}
