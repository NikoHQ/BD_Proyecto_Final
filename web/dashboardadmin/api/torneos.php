<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';
require_once __DIR__ . '/../../includes/torneos-dto.php';

/**
 * Torneos del panel. La regla vive en SGCD_PKG_TORNEOS.
 *
 *   GET  torneos       [modalidad, estado, cliente]
 *   GET  inscripciones [torneo, cliente]
 *   GET  inscripcion   id
 *   POST crear         modalidad, nombre, inicio, fin, cupos [maximo]
 *   POST inscribir     torneo, cliente, equipo
 *   POST agregar       inscripcion, rut, nombre
 *   POST retirar       inscripcion
 *   POST maximo        torneo, maximo
 *   POST programar     torneo, cancha, fecha, desde, hasta
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
apiSesion(['ADMINISTRADOR']);

switch ($accion) {
    case 'torneos':
        apiOk(torneosLista($_GET));
        break;

    case 'inscripciones':
        apiOk(inscripcionesLista($_GET));
        break;

    case 'inscripcion':
        $detalle = inscripcionDetalle(apiEntero($_GET['id'] ?? null, 'id'));
        $detalle === null ? apiFail('La inscripcion no existe.', 404) : apiOk($detalle);
        break;

    case 'crear':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.crear_torneo(:modalidad, :nombre, :inicio, :termino, '
            . ':cupos, :maximo, :id); END;',
            [
                'modalidad' => apiEntero($entrada['modalidad'] ?? null, 'modalidad'),
                'nombre' => (string) ($entrada['nombre'] ?? ''),
                'inicio' => apiFecha((string) ($entrada['inicio'] ?? ''), 'inicio'),
                'termino' => apiFecha((string) ($entrada['fin'] ?? ''), 'fin'),
                'cupos' => apiEntero($entrada['cupos'] ?? null, 'cupos'),
                'maximo' => isset($entrada['maximo']) && $entrada['maximo'] !== ''
                    ? apiEntero($entrada['maximo'], 'maximo') : null,
                'id' => 0,
            ],
            true
        );
        apiOk(['id' => (int) $r['out']['id']], 201);
        break;

    case 'inscribir':
        $r = apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(:torneo, :cliente, :equipo, :id); END;',
            [
                'torneo' => apiEntero($entrada['torneo'] ?? null, 'torneo'),
                'cliente' => apiEntero($entrada['cliente'] ?? null, 'cliente'),
                'equipo' => (string) ($entrada['equipo'] ?? ''),
                'id' => 0,
            ],
            true
        );
        apiOk(['id' => (int) $r['out']['id']], 201);
        break;

    case 'agregar':
        [$rut, $dv] = apiRutPartes((string) ($entrada['rut'] ?? ''));
        apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(:inscripcion, :rut, :dv, :nombre); END;',
            [
                'inscripcion' => apiEntero($entrada['inscripcion'] ?? null, 'inscripcion'),
                'rut' => $rut,
                'dv' => $dv,
                'nombre' => (string) ($entrada['nombre'] ?? ''),
            ],
            true
        );
        apiOk(['agregado' => true], 201);
        break;

    case 'retirar':
        apiLlamar('BEGIN SGCD_PKG_TORNEOS.retirar_equipo(:inscripcion); END;',
            ['inscripcion' => apiEntero($entrada['inscripcion'] ?? null, 'inscripcion')], true);
        apiOk(['retirado' => true]);
        break;

    case 'maximo':
        apiLlamar('BEGIN SGCD_PKG_TORNEOS.ajustar_maximo(:torneo, :maximo); END;', [
            'torneo' => apiEntero($entrada['torneo'] ?? null, 'torneo'),
            'maximo' => apiEntero($entrada['maximo'] ?? null, 'maximo'),
        ], true);
        apiOk(['ajustado' => true]);
        break;

    case 'programar':
        apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.programar_torneo(:torneo, :cancha, :fecha, :desde, :hasta); END;',
            [
                'torneo' => apiEntero($entrada['torneo'] ?? null, 'torneo'),
                'cancha' => apiEntero($entrada['cancha'] ?? null, 'cancha'),
                'fecha' => apiFecha((string) ($entrada['fecha'] ?? ''), 'fecha'),
                'desde' => apiHora((string) ($entrada['desde'] ?? '')),
                'hasta' => apiHora((string) ($entrada['hasta'] ?? '')),
            ],
            true
        );
        apiOk(['programado' => true], 201);
        break;

    default:
        apiFail('Accion no valida.', 400);
}
