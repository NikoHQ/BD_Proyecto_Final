<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';
require_once __DIR__ . '/../../includes/pagos-dto.php';

/**
 * Pagos de una reserva. La regla vive en SGCD_PKG_PAGOS.
 *
 *   GET  ver        reserva
 *   GET  saldo      reserva
 *   GET  listar     desde, hasta
 *   GET  pendientes [desde, hasta]
 *   POST registrar  reserva, medio
 *   POST diferencia reserva, medio
 *   POST anular     reserva
 */

$accion = (string) ($_GET['accion'] ?? 'ver');
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$entrada = apiEntrada();

if (!in_array($metodo, ['GET', 'POST'], true)) {
    apiFail('Metodo no permitido.', 405);
}
if ($metodo === 'POST') {
    apiCsrf();
}
$cuenta = apiSesion(['ADMINISTRADOR']);

switch ($accion) {
    case 'listar':
        apiOk(pagosLista(
            apiFechaCorta($_GET['desde'] ?? null, 'desde'),
            apiFechaCorta($_GET['hasta'] ?? null, 'hasta')
        ));
        break;

    case 'pendientes':
        $desde = isset($_GET['desde']) && $_GET['desde'] !== '' ? apiFechaCorta($_GET['desde'], 'desde') : null;
        $hasta = isset($_GET['hasta']) && $_GET['hasta'] !== '' ? apiFechaCorta($_GET['hasta'], 'hasta') : null;
        apiOk(reservasPorCobrar($desde, $hasta));
        break;

    case 'ver':
        $idReserva = apiEntero($_GET['reserva'] ?? null, 'reserva');
        $r = apiLlamar(
            'BEGIN :pago := SGCD_PKG_PAGOS.pago_de_reserva(:reserva); END;',
            ['reserva' => $idReserva],
            false,
            'pago'
        );
        $fila = $r['filas'][0] ?? null;
        apiOk($fila === null ? null : [
            'id' => (int) $fila['ID_PAGO'],
            'reserva' => (int) $fila['ID_RESERVA'],
            'importe' => (float) $fila['IMPORTE_PAGO'],
            'fecha' => $fila['FECHA_PAGO'],
            'medio' => $fila['MEDIO_PAGO'],
            'estado' => $fila['ESTADO_PAGO'],
            'acordado' => (float) $fila['IMPORTE_ACORDADO'],
            'saldo' => (float) $fila['SALDO'],
        ]);
        break;

    case 'saldo':
        $idReserva = apiEntero($_GET['reserva'] ?? null, 'reserva');
        $r = apiLlamar(
            'BEGIN :saldo := SGCD_PKG_PAGOS.saldo_reserva(:reserva); END;',
            ['reserva' => $idReserva, 'saldo' => 0]
        );
        apiOk(['saldo' => (float) $r['out']['saldo']]);
        break;

    case 'registrar':
    case 'diferencia':
        $idReserva = apiEntero($entrada['reserva'] ?? null, 'reserva');
        $medio = (string) ($entrada['medio'] ?? '');
        $plsql = $accion === 'registrar'
            ? 'BEGIN SGCD_PKG_PAGOS.registrar_pago(:reserva, :medio, :admin); END;'
            : 'BEGIN SGCD_PKG_PAGOS.cobrar_diferencia(:reserva, :medio, :admin); END;';
        apiLlamar($plsql, [
            'reserva' => $idReserva,
            'medio' => $medio,
            'admin' => (int) $cuenta['PERSONAL'],
        ], true);
        apiOk(['registrado' => true]);
        break;

    case 'anular':
        $idReserva = apiEntero($entrada['reserva'] ?? null, 'reserva');
        apiLlamar('BEGIN SGCD_PKG_PAGOS.anular_pago(:reserva, :admin); END;', [
            'reserva' => $idReserva,
            'admin' => (int) $cuenta['PERSONAL'],
        ], true);
        apiOk(['anulado' => true]);
        break;

    default:
        apiFail('Accion no valida.', 400);
}
