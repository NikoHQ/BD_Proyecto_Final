<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';

/**
 * Reportes del recinto. Rango obligatorio; la regla vive en
 * SGCD_PKG_CONSULTAS y el reporte de ingresos es solo de administracion.
 *
 *   GET ingresos  desde, hasta
 *   GET canchas   desde, hasta [cliente]
 *   GET clientes  desde, hasta [cliente]
 */

$accion = (string) ($_GET['accion'] ?? 'ingresos');
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';

if ($metodo !== 'GET') {
    apiFail('Metodo no permitido.', 405);
}
apiSesion(['ADMINISTRADOR']);

// El rango es obligatorio: sin dos fechas Y-m-d el reporte no tiene sentido y
// el codigo viaja como 20080, el mismo que usa SGCD_PKG_CONSULTAS.
$desdeCrudo = is_scalar($_GET['desde'] ?? null) ? (string) $_GET['desde'] : '';
$hastaCrudo = is_scalar($_GET['hasta'] ?? null) ? (string) $_GET['hasta'] : '';
$fechaValida = static function (string $valor): bool {
    $fecha = DateTimeImmutable::createFromFormat('!Y-m-d', $valor);
    return $fecha !== false && $fecha->format('Y-m-d') === $valor;
};
if (!$fechaValida($desdeCrudo) || !$fechaValida($hastaCrudo)) {
    apiFail(API_ERRORES[20080][1], 400, 20080);
}

$desde = apiFecha($desdeCrudo, 'desde');
$hasta = apiFecha($hastaCrudo, 'hasta');
$cliente = isset($_GET['cliente']) && $_GET['cliente'] !== ''
    ? apiEntero($_GET['cliente'], 'cliente') : null;

switch ($accion) {
    case 'ingresos':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_CONSULTAS.ingresos(:desde, :hasta, :cursor); END;',
            ['desde' => $desde, 'hasta' => $hasta],
            false,
            'cursor'
        );
        apiOk(array_map(static fn(array $f): array => [
            'dia' => substr((string) $f['DIA'], 0, 10),
            'pagos' => (int) $f['PAGOS'],
            'total' => (float) $f['TOTAL'],
        ], $r['filas']));
        break;

    case 'canchas':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_CONSULTAS.reservas_por_cancha(:desde, :hasta, :cliente, :cursor); END;',
            ['desde' => $desde, 'hasta' => $hasta, 'cliente' => $cliente],
            false,
            'cursor'
        );
        apiOk(array_map(static fn(array $f): array => [
            'cancha' => $f['CANCHA'],
            'modalidad' => $f['MODALIDAD'],
            'reservas' => (int) $f['RESERVAS'],
            'horas' => (float) $f['HORAS'],
            'importe' => (float) $f['IMPORTE'],
        ], $r['filas']));
        break;

    case 'clientes':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_CONSULTAS.clientes_por_reservas(:desde, :hasta, :cliente, :cursor); END;',
            ['desde' => $desde, 'hasta' => $hasta, 'cliente' => $cliente],
            false,
            'cursor'
        );
        apiOk(array_map(static fn(array $f): array => [
            'id' => (int) $f['ID_CLIENTE'],
            'cliente' => $f['CLIENTE'],
            'rut' => $f['RUT'],
            'reservas' => (int) $f['RESERVAS'],
            'horas' => (float) $f['HORAS'],
            'importe' => (float) $f['IMPORTE'],
        ], $r['filas']));
        break;

    default:
        apiFail('Accion no valida.', 400);
}
