<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';
require_once __DIR__ . '/../../includes/reservas-dto.php';

/**
 * Reservas del panel. Toda la regla vive en SGCD_PKG_RESERVAS; aqui solo se
 * autoriza, se arma el DTO y se traduce el codigo HTTP.
 *
 *   GET  agenda      desde, hasta [cancha, cliente]
 *   GET  disponible  cancha, modalidad, fecha, hora, bloques
 *   GET  cotizar     cancha, modalidad, fecha, hora, bloques
 *   POST crear       cliente, cancha, modalidad, fecha, hora, bloques
 *   POST confirmar   id
 *   POST cancelar    id
 *   POST reprogramar id, fecha, hora, bloques
 */

$accion = (string) ($_GET['accion'] ?? 'agenda');
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
    case 'agenda':
        apiOk(agendaReservas($_GET));
        break;

    case 'disponible':
        apiOk(['disponible' => disponibilidadReservas($_GET)]);
        break;

    case 'cotizar':
        apiOk(cotizacionReservas($_GET));
        break;

    case 'crear':
        $r = apiLlamar(
            "BEGIN SGCD_PKG_RESERVAS.crear_reserva(:cliente, :admin, :cancha, :modalidad, "
            . ":fecha, :hora, :bloques, 'MOSTRADOR', :id); END;",
            [
                'cliente' => apiEntero($entrada['cliente'] ?? null, 'cliente'),
                'admin' => (int) $cuenta['PERSONAL'],
                'cancha' => apiEntero($entrada['cancha'] ?? null, 'cancha'),
                'modalidad' => apiEntero($entrada['modalidad'] ?? null, 'modalidad'),
                'fecha' => apiFecha((string) ($entrada['fecha'] ?? ''), 'fecha'),
                'hora' => apiHora((string) ($entrada['hora'] ?? '')),
                'bloques' => apiEntero($entrada['bloques'] ?? 1, 'bloques'),
                'id' => 0,
            ],
            true
        );
        apiOk(['id' => (int) $r['out']['id']], 201);
        break;

    case 'confirmar':
        apiLlamar('BEGIN SGCD_PKG_RESERVAS.confirmar_reserva(:id); END;',
            ['id' => apiEntero($entrada['id'] ?? null, 'id')], true);
        apiOk(['confirmada' => true]);
        break;

    case 'cancelar':
        apiLlamar('BEGIN SGCD_PKG_RESERVAS.cancelar_reserva(:id); END;',
            ['id' => apiEntero($entrada['id'] ?? null, 'id')], true);
        apiOk(['cancelada' => true]);
        break;

    case 'reprogramar':
        apiLlamar('BEGIN SGCD_PKG_RESERVAS.reprogramar_reserva(:id, :fecha, :hora, :bloques); END;',
            [
                'id' => apiEntero($entrada['id'] ?? null, 'id'),
                'fecha' => apiFecha((string) ($entrada['fecha'] ?? ''), 'fecha'),
                'hora' => apiHora((string) ($entrada['hora'] ?? '')),
                'bloques' => apiEntero($entrada['bloques'] ?? 1, 'bloques'),
            ],
            true);
        apiOk(['reprogramada' => true]);
        break;

    default:
        apiFail('Accion no valida.', 400);
}
