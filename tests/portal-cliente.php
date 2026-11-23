<?php
declare(strict_types=1);

require __DIR__ . '/../web/cliente/demo.php';
require __DIR__ . '/../web/includes/portal-duration.php';

$service = new DemoPortal([], '2026-11-22', '12:00');
$filter = ['mode' => 'padel', 'date' => '2026-11-27', 'site' => 'rastras'];
$slots = $service->availability($filter);
$slot = static fn(array $slots, string $court, string $time): ?array =>
    array_find($slots, static fn(array $item): bool => $item['court'] === $court && $item['start'] === $time);
function check(bool $condition, string $message): void
{
    if (!$condition) throw new RuntimeException($message);
}
check($slot($slots, 'padel-1', '18:00')['total'] === 18000, 'Debe cotizar $18.000 a las 18:00.');
check($slot($slots, 'padel-1', '17:30')['total'] === 17000, 'Debe prorratear al cruzar las 18:00.');
check($slot($slots, 'padel-1', '16:00') === null, 'El torneo debe bloquear la cancha.');
check(count($service->availability(array_replace($filter, ['date' => '2026-11-23']))) === 0, 'El recinto debe estar cerrado el lunes.');
$tampered = $slot($service->availability(array_replace($filter, ['duration' => 90])), 'padel-1', '18:00');
check($tampered && $tampered['duration'] === 60, 'El cliente no puede imponer otra duración.');
$settings = tempnam(sys_get_temp_dir(), 'sgcd-duration-test-');
if ($settings === false) throw new RuntimeException('No se pudo crear el archivo temporal.');
try {
    $modes = array_keys(DemoPortal::MODES);
    $input = array_fill_keys($modes, '60');
    $input['padel'] = '90';
    savePortalDurations($input, $modes, $settings);
    $durations = loadPortalDurations($settings);
    check($durations['padel'] === 90, 'La duración debe quedar guardada.');
    try {
        savePortalDurations(array_replace($input, ['padel' => '91']), $modes, $settings);
        throw new RuntimeException('Debe rechazar duraciones fuera del catálogo.');
    } catch (InvalidArgumentException) {
        check(loadPortalDurations($settings) === $durations, 'Un cambio inválido debe preservar la configuración.');
    }
} finally {
    unlink($settings);
}
$configured = new DemoPortal([], '2026-11-22', '12:00', $durations);
$slot90 = $slot($configured->availability($filter), 'padel-1', '18:00');
check($slot90 && $slot90['end'] === '19:30' && $slot90['total'] === 27000, 'Debe respetar 90 minutos.');
$selected = $slot($slots, 'padel-1', '18:00');
check($configured->create('demo', $filter, $selected, 'stale')['error'] === 'DURATION_CHANGED', 'Un cambio de duración exige volver a elegir.');
$created = $service->create('demo', $filter, $selected, 'test-1');
check($created['booking']['status'] === 'PENDIENTE', 'Una solicitud web debe quedar pendiente.');
check($service->create('demo', $filter, $selected, 'test-1')['booking']['code'] === $created['booking']['code'], 'Reintentar no debe duplicar.');
check($service->create('demo', $filter, $selected, 'test-2')['error'] === 'SLOT_TAKEN', 'El horario nuevo debe estar ocupado.');
check($service->detail('nuevo', $created['booking']['code']) === null, 'Otra cuenta no puede ver el detalle.');
check($service->history('nuevo') === [], 'Una cuenta nueva debe poder ver su historial.');
$first = $slot($service->availability($filter), 'padel-2', '19:00');
$next = $slot($service->availability($filter), 'padel-2', '18:00');
$firstBooking = $service->create('nuevo', $filter, $first, 'new-1')['booking'];
check($service->detail('nuevo', $firstBooking['code']) !== null, 'La cuenta nueva puede abrir su primera reserva.');
check($service->create('nuevo', $filter, $first, 'new-1')['booking'] === $firstBooking, 'Reintentar la primera reserva debe ser idempotente.');
check($service->create('nuevo', $filter, $next, 'new-2')['error'] === 'FIRST_RESERVATION_PENDING', 'Solo se permite una solicitud hasta la primera confirmación.');
check($service->cancel('nuevo', $firstBooking['code']), 'La cuenta nueva puede cancelar la solicitud.');
$replacement = $service->create('nuevo', $filter, $next, 'new-3')['booking'];
check($replacement['status'] === 'PENDIENTE', 'Una primera solicitud cancelada se puede reemplazar.');
$service->syncRequestReviews(['new-3' => ['status' => 'CONFIRMADA', 'confirmed' => true]]);
check($service->detail('nuevo', $replacement['code'])['status'] === 'CONFIRMADA', 'La confirmación del personal se refleja en el portal.');
check($service->cancel('nuevo', $replacement['code']), 'Se puede cancelar después de confirmar.');
check(isset($service->create('nuevo', $filter, $first, 'new-4')['booking']), 'Una primera confirmación previa desbloquea solicitudes posteriores.');
check($service->cancel('demo', $created['booking']['code']), 'El cliente puede cancelar su próxima reserva.');
check($slot($service->availability($filter), 'padel-1', '18:00') !== null, 'Cancelar debe liberar la cancha.');
$service->scenario = 'PRICE_CHANGED';
check($service->create('demo', $filter, $selected, 'test-3')['error'] === 'PRICE_CHANGED', 'Un precio nuevo requiere aceptación.');
$scheduled = new DemoPortal([], '2026-11-22', '12:00');
$scheduled->useTournamentBlocks([[
    'state' => 'PLANIFICADO', 'site' => 'Las Rastras', 'blocks' => [[
        'courtName' => 'Pádel 1', 'date' => $filter['date'], 'start' => '18:00', 'end' => '19:00',
    ]],
]]);
check($scheduled->quote($filter, 'padel-1', '18:00') === null, 'La cancha del torneo se bloquea en el portal.');
check($scheduled->quote($filter, 'padel-2', '18:00') !== null, 'La otra cancha conserva su disponibilidad.');
$scheduled->useTournamentBlocks([]);
check($scheduled->quote($filter, 'padel-1', '16:00') !== null, 'La agenda compartida sustituye el bloque de torneo de ejemplo.');
echo "Servicio del portal verificado.\n";
