<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/api.php';
require_once __DIR__ . '/../includes/torneos-dto.php';

/**
 * Torneos del portal. El cliente siempre sale de la sesion.
 *
 *   GET  torneos    cartelera con mi inscripcion si existe
 *   GET  mias       mis inscripciones
 *   GET  detalle    id (solo si es mia)
 *   POST inscribir  torneo, equipo
 *   POST agregar    inscripcion, rut, nombre
 *   POST retirar    inscripcion
 */

$accion = (string) ($_GET['accion'] ?? 'torneos');
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
    case 'torneos':
        apiOk(torneosLista(['cliente' => $idCliente]));
        break;

    case 'mias':
        apiOk(inscripcionesLista([], $idCliente));
        break;

    case 'detalle':
        $detalle = inscripcionPropia(apiEntero($_GET['id'] ?? null, 'id'), $idCliente);
        $detalle === null ? apiFail('La inscripcion no existe.', 404) : apiOk($detalle);
        break;

    case 'inscribir':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(:torneo, :cliente, :equipo, :id); END;',
            [
                'torneo' => apiEntero($entrada['torneo'] ?? null, 'torneo'),
                'cliente' => $idCliente,
                'equipo' => (string) ($entrada['equipo'] ?? ''),
                'id' => 0,
            ],
            true
        );
        apiOk(['id' => (int) $r['out']['id']], 201);
        break;

    case 'agregar':
        $idInscripcion = apiEntero($entrada['inscripcion'] ?? null, 'inscripcion');
        if (inscripcionPropia($idInscripcion, $idCliente) === null) {
            apiFail('La inscripcion no existe.', 404);
        }
        [$rut, $dv] = apiRutPartes((string) ($entrada['rut'] ?? ''));
        apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(:inscripcion, :rut, :dv, :nombre); END;',
            [
                'inscripcion' => $idInscripcion,
                'rut' => $rut,
                'dv' => $dv,
                'nombre' => (string) ($entrada['nombre'] ?? ''),
            ],
            true
        );
        apiOk(['agregado' => true], 201);
        break;

    case 'retirar':
        $idInscripcion = apiEntero($entrada['inscripcion'] ?? null, 'inscripcion');
        if (inscripcionPropia($idInscripcion, $idCliente) === null) {
            apiFail('La inscripcion no existe.', 404);
        }
        apiLlamar('BEGIN SGCD_PKG_TORNEOS.retirar_equipo(:inscripcion); END;',
            ['inscripcion' => $idInscripcion], true);
        apiOk(['retirado' => true]);
        break;

    default:
        apiFail('Accion no valida.', 400);
}
