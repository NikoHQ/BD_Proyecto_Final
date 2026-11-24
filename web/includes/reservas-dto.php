<?php
declare(strict_types=1);

/**
 * Traduccion compartida entre el panel y el portal para el cursor de
 * SGCD_PKG_RESERVAS.agenda. Vive aqui para que las dos caras devuelvan el
 * mismo DTO.
 */

function reservaFila(array $f): array
{
    return [
        'id' => (int) $f['ID_RESERVA'],
        'inicio' => $f['INICIO_RESERVA'],
        'termino' => $f['TERMINO_RESERVA'],
        'cancha' => ['id' => (int) $f['ID_CANCHA'], 'nombre' => $f['NOMBRE_CANCHA']],
        'modalidad' => ['id' => (int) $f['ID_MODALIDAD'], 'nombre' => $f['NOMBRE_MODALIDAD']],
        'cliente' => [
            'id' => $f['ID_CLIENTE'] === null ? null : (int) $f['ID_CLIENTE'],
            'nombre' => $f['NOMBRE_CLIENTE'],
        ],
        'torneo' => [
            'id' => $f['ID_TORNEO'] === null ? null : (int) $f['ID_TORNEO'],
            'nombre' => $f['NOMBRE_TORNEO'],
        ],
        'origen' => $f['ORIGEN_RESERVA'],
        'estado' => $f['ESTADO_RESERVA'],
        'importe' => (float) $f['IMPORTE_ACORDADO'],
    ];
}

function disponibilidadReservas(array $entrada): bool
{
    $r = apiLlamar(
        'BEGIN :libre := SGCD_PKG_RESERVAS.disponible(:cancha, :modalidad, :fecha, :hora, :bloques); END;',
        [
            'cancha' => apiEntero($entrada['cancha'] ?? null, 'cancha'),
            'modalidad' => apiEntero($entrada['modalidad'] ?? null, 'modalidad'),
            'fecha' => apiFecha((string) ($entrada['fecha'] ?? ''), 'fecha'),
            'hora' => apiHora((string) ($entrada['hora'] ?? '')),
            'bloques' => apiEntero($entrada['bloques'] ?? 1, 'bloques'),
            'libre' => 0,
        ]
    );
    return (int) $r['out']['libre'] === 1;
}

function agendaReservas(array $entrada, ?int $idCliente = null): array
{
    $desde = apiFecha((string) ($entrada['desde'] ?? ''), 'desde');
    $hasta = apiFecha((string) ($entrada['hasta'] ?? ''), 'hasta');
    $cancha = isset($entrada['cancha']) && $entrada['cancha'] !== ''
        ? apiEntero($entrada['cancha'], 'cancha') : null;
    $cliente = $idCliente ?? (isset($entrada['cliente']) && $entrada['cliente'] !== ''
        ? apiEntero($entrada['cliente'], 'cliente') : null);

    $r = apiLlamar(
        'BEGIN SGCD_PKG_RESERVAS.agenda(:desde, :hasta, :cancha, :cliente, :cursor); END;',
        ['desde' => $desde, 'hasta' => $hasta, 'cancha' => $cancha, 'cliente' => $cliente],
        false,
        'cursor'
    );
    return array_map('reservaFila', $r['filas']);
}
