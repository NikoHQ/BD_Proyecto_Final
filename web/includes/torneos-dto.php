<?php
declare(strict_types=1);

/**
 * DTO y consultas compartidas de torneos entre el panel y el portal.
 */

function torneosLista(array $filtros = []): array
{
    $r = apiLlamar(
        'BEGIN SGCD_PKG_TORNEOS.listar_torneos(:modalidad, :estado, :cliente, :cursor); END;',
        [
            'modalidad' => isset($filtros['modalidad']) && $filtros['modalidad'] !== ''
                ? apiEntero($filtros['modalidad'], 'modalidad') : null,
            'estado' => isset($filtros['estado']) && $filtros['estado'] !== ''
                ? (string) $filtros['estado'] : null,
            'cliente' => isset($filtros['cliente']) && $filtros['cliente'] !== ''
                ? apiEntero($filtros['cliente'], 'cliente') : null,
        ],
        false,
        'cursor'
    );
    return array_map(static fn(array $f): array => [
        'id' => (int) $f['ID_TORNEO'],
        'nombre' => $f['NOMBRE_TORNEO'],
        'modalidad' => ['id' => (int) $f['ID_MODALIDAD'], 'nombre' => $f['NOMBRE_MODALIDAD']],
        'inicio' => substr((string) $f['FECHA_INICIO'], 0, 10),
        'termino' => substr((string) $f['FECHA_TERMINO'], 0, 10),
        'cupos' => (int) $f['CUPOS_TORNEO'],
        'inscritos' => (int) $f['INSCRITOS'],
        'minimo' => (int) $f['MIN_JUGADORES_POR_EQUIPO'],
        'maximo' => (int) $f['MAX_JUGADORES_POR_EQUIPO'],
        'estado' => $f['ESTADO_TORNEO'],
        'mi_inscripcion' => $f['MI_INSCRIPCION'] === null ? null : (int) $f['MI_INSCRIPCION'],
    ], $r['filas']);
}

function inscripcionesLista(array $filtros = [], ?int $idCliente = null): array
{
    $r = apiLlamar(
        'BEGIN SGCD_PKG_TORNEOS.listar_inscripciones(:torneo, :cliente, :cursor); END;',
        [
            'torneo' => isset($filtros['torneo']) && $filtros['torneo'] !== ''
                ? apiEntero($filtros['torneo'], 'torneo') : null,
            'cliente' => $idCliente ?? (isset($filtros['cliente']) && $filtros['cliente'] !== ''
                ? apiEntero($filtros['cliente'], 'cliente') : null),
        ],
        false,
        'cursor'
    );
    return array_map(static fn(array $f): array => [
        'id' => (int) $f['ID_INSCRIPCION'],
        'torneo' => ['id' => (int) $f['ID_TORNEO'], 'nombre' => $f['NOMBRE_TORNEO']],
        'equipo' => $f['NOMBRE_EQUIPO'],
        'cantidad' => (int) $f['CANTIDAD_JUGADORES'],
        'fecha' => substr((string) $f['FECHA_INSCRIPCION'], 0, 10),
        'estado' => $f['ESTADO_INSCRIPCION'],
        'capitan' => ['id' => (int) $f['ID_CLIENTE'], 'nombre' => $f['CAPITAN']],
    ], $r['filas']);
}

function inscripcionDetalle(int $id): ?array
{
    $r = apiLlamar(
        'BEGIN SGCD_PKG_TORNEOS.inscripcion(:id, :cursor); END;',
        ['id' => $id],
        false,
        'cursor'
    );
    $f = $r['filas'][0] ?? null;
    if ($f === null) {
        return null;
    }
    $j = apiLlamar(
        'BEGIN SGCD_PKG_TORNEOS.jugadores_inscripcion(:id, :cursor); END;',
        ['id' => $id],
        false,
        'cursor'
    );
    return [
        'id' => (int) $f['ID_INSCRIPCION'],
        'torneo' => ['id' => (int) $f['ID_TORNEO'], 'nombre' => $f['NOMBRE_TORNEO']],
        'equipo' => $f['NOMBRE_EQUIPO'],
        'capitan' => ['id' => (int) $f['ID_CLIENTE'], 'nombre' => $f['CAPITAN']],
        'cantidad' => (int) $f['CANTIDAD_JUGADORES'],
        'fecha' => substr((string) $f['FECHA_INSCRIPCION'], 0, 10),
        'estado' => $f['ESTADO_INSCRIPCION'],
        'minimo' => (int) $f['MIN_JUGADORES_POR_EQUIPO'],
        'maximo' => (int) $f['MAX_JUGADORES_POR_EQUIPO'],
        'jugadores' => array_map(static fn(array $p): array => [
            'id' => (int) $p['ID_JUGADOR'],
            'rut' => $p['RUT'],
            'nombre' => $p['NOMBRE_JUGADOR'],
            'capitan' => (int) ($p['ES_CAPITAN'] ?? 0) === 1,
        ], $j['filas']),
    ];
}

/** Detalle solo si la inscripcion es del cliente de la sesion. */
function inscripcionPropia(int $id, int $idCliente): ?array
{
    $detalle = inscripcionDetalle($id);
    if ($detalle === null || $detalle['capitan']['id'] !== $idCliente) {
        return null;
    }
    return $detalle;
}
