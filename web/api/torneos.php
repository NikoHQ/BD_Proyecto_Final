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
 *   POST inscribir  torneo, equipo, jugadores (plantilla completa)
 *   POST actualizar inscripcion, equipo, jugadores (plantilla completa)
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
    apiFail('Tu cuenta no tiene ficha de cliente. Contacta a la sucursal.', 403);
}

/** Torneo visible para el cliente y apto para validar el tamano de plantilla. */
function torneoPortal(int $idTorneo, int $idCliente): array
{
    foreach (torneosLista(['cliente' => $idCliente]) as $torneo) {
        if ($torneo['id'] === $idTorneo) {
            return $torneo;
        }
    }
    apiFail('El torneo no existe.', 404);
}

/** Valida y normaliza a los companeros; el capitan viene de la sesion. */
function plantillaEntrada(mixed $entrada, int $minimo, int $maximo): array
{
    if (!is_array($entrada)) {
        apiFail('Completa los datos de todos los integrantes del equipo.', 400);
    }
    $minimoCompaneros = max(0, $minimo - 1);
    $maximoCompaneros = max(0, $maximo - 1);
    if (count($entrada) > $maximoCompaneros) {
        apiFail('La plantilla supera el máximo de ' . $maximo . ' jugadores.', 400);
    }
    $jugadores = [];
    $vistos = [];
    foreach ($entrada as $indice => $jugador) {
        if (!is_array($jugador)) {
            apiFail('Revisa los datos del integrante ' . ((int) $indice + 1) . '.', 400);
        }
        $nombre = trim((string) ($jugador['nombre'] ?? ''));
        $rutCrudo = trim((string) ($jugador['rut'] ?? ''));
        if ($nombre === '' && $rutCrudo === '') {
            continue;
        }
        if ($nombre === '' || $rutCrudo === '') {
            apiFail('Completa el nombre y RUT de cada integrante agregado.', 400);
        }
        [$rut, $dv] = apiRutPartes($rutCrudo);
        $clave = $rut . '-' . $dv;
        if (isset($vistos[$clave])) {
            apiFail('No repitas el mismo RUT en la plantilla.', 400);
        }
        $vistos[$clave] = true;
        $jugadores[] = ['rut' => $rut, 'dv' => $dv, 'nombre' => $nombre];
    }
    if (count($jugadores) < $minimoCompaneros) {
        apiFail('La plantilla debe tener al menos ' . $minimo . ' jugadores, incluido el capitan.', 400);
    }
    return $jugadores;
}

/** Agrega los companeros y confirma solo cuando el lote completo es valido. */
function guardarPlantilla(int $idInscripcion, array $jugadores): void
{
    foreach ($jugadores as $jugador) {
        apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.agregar_jugador(:inscripcion, :rut, :dv, :nombre); END;',
            ['inscripcion' => $idInscripcion, 'rut' => $jugador['rut'], 'dv' => $jugador['dv'], 'nombre' => $jugador['nombre']]
        );
    }
    apiConfirmar();
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
        $idTorneo = apiEntero($entrada['torneo'] ?? null, 'torneo');
        $torneo = torneoPortal($idTorneo, $idCliente);
        $jugadores = plantillaEntrada($entrada['jugadores'] ?? null, $torneo['minimo'], $torneo['maximo']);
        $r = apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.inscribir_equipo(:torneo, :cliente, :equipo, :id); END;',
            [
                'torneo' => $idTorneo,
                'cliente' => $idCliente,
                'equipo' => (string) ($entrada['equipo'] ?? ''),
                'id' => 0,
            ]
        );
        guardarPlantilla((int) $r['out']['id'], $jugadores);
        apiOk(['id' => (int) $r['out']['id']], 201);
        break;

    case 'actualizar':
        $idInscripcion = apiEntero($entrada['inscripcion'] ?? null, 'inscripcion');
        $detalle = inscripcionPropia($idInscripcion, $idCliente);
        if ($detalle === null) {
            apiFail('La inscripcion no existe.', 404);
        }
        $jugadores = plantillaEntrada($entrada['jugadores'] ?? null, $detalle['minimo'], $detalle['maximo']);
        apiLlamar(
            'BEGIN SGCD_PKG_TORNEOS.preparar_plantilla(:inscripcion, :equipo); END;',
            ['inscripcion' => $idInscripcion, 'equipo' => (string) ($entrada['equipo'] ?? '')]
        );
        guardarPlantilla($idInscripcion, $jugadores);
        apiOk(inscripcionPropia($idInscripcion, $idCliente));
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
