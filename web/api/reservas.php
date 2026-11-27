<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/api.php';
require_once __DIR__ . '/../includes/reservas-dto.php';

/**
 * Reservas del portal de clientes. La sesion define al cliente: nunca se
 * acepta un ID de cliente por parametro.
 *
 *   GET  disponible  cancha, modalidad, fecha, hora, bloques
 *   GET  cotizar     cancha, modalidad, fecha, hora, bloques
 *   POST solicitar   cancha, modalidad, fecha, hora, bloques
 *   POST cancelar    id (sólo una solicitud pendiente del cliente en sesión)
 *   GET  mias        desde, hasta
 */

$accion = (string) ($_GET['accion'] ?? 'mias');
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$entrada = apiEntrada();

if (!in_array($metodo, ['GET', 'POST'], true)) {
    apiFail('Metodo no permitido.', 405);
}
if ($metodo === 'POST') {
    apiCsrf();
}
$cuenta = apiSesion(['CLIENTE']);
$idCliente = (int) ($cuenta['PERSONAL'] ?? 0);
if ($idCliente <= 0) {
    apiFail('Tu cuenta no tiene ficha de cliente. Contacta a la sucursal.', 403);
}

switch ($accion) {
    case 'disponible':
        apiOk(['disponible' => disponibilidadReservas($_GET)]);
        break;

    case 'cotizar':
        apiOk(cotizacionReservas($_GET));
        break;

    case 'solicitar':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_RESERVAS.crear_solicitud_web(:cliente, :cancha, :modalidad, '
            . ':fecha, :hora, :bloques, :id); END;',
            [
                'cliente' => $idCliente,
                'cancha' => apiEntero($entrada['cancha'] ?? null, 'cancha'),
                'modalidad' => apiEntero($entrada['modalidad'] ?? null, 'modalidad'),
                'fecha' => apiFecha((string) ($entrada['fecha'] ?? ''), 'fecha'),
                'hora' => apiHora((string) ($entrada['hora'] ?? '')),
                'bloques' => apiEntero($entrada['bloques'] ?? 1, 'bloques'),
                'id' => 0,
            ],
            true
        );
        apiOk(['id' => (int) $r['out']['id'], 'estado' => 'PENDIENTE'], 201);
        break;

    case 'cancelar':
        $idReserva = apiEntero($entrada['id'] ?? null, 'id');
        // El bloqueo mantiene la reserva pendiente y propia hasta que Oracle
        // complete la transición. Así no se puede cancelar un ID ajeno ni una
        // solicitud que recepción haya confirmado entre ambas operaciones.
        $reserva = authRow(
            'SELECT ID_RESERVA, ESTADO_RESERVA
               FROM SGCD_RESERVAS
              WHERE ID_RESERVA = :id AND ID_CLIENTE = :cliente
              FOR UPDATE',
            ['id' => $idReserva, 'cliente' => $idCliente]
        );
        if (!$reserva) {
            apiFail('No puedes cancelar esa reserva.', 403);
        }
        if ($reserva['ESTADO_RESERVA'] !== 'PENDIENTE') {
            apiFail('Sólo puedes cancelar solicitudes pendientes.', 409);
        }
        apiLlamar('BEGIN SGCD_PKG_RESERVAS.cancelar_reserva(:id); END;', ['id' => $idReserva], true);
        apiOk(['cancelada' => true]);
        break;

    case 'mias':
        apiOk(agendaReservas($_GET, $idCliente));
        break;

    default:
        apiFail('Accion no valida.', 400);
}
