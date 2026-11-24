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
    apiFail('Tu cuenta no tiene ficha de cliente. Contacta al recinto.', 403);
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

    case 'mias':
        apiOk(agendaReservas($_GET, $idCliente));
        break;

    default:
        apiFail('Accion no valida.', 400);
}
