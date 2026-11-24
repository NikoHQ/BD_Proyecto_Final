<?php
declare(strict_types=1);

require __DIR__ . '/../web/cliente/demo.php';

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
check($slot($slots, 'padel-1', '17:30') === null, 'Los bloques empiezan a la hora exacta.');
check($slot($slots, 'padel-1', '16:00') === null, 'El torneo debe bloquear la cancha.');
check(count($service->availability(array_replace($filter, ['date' => '2026-11-23']))) === 0, 'El recinto debe estar cerrado el lunes.');
$twoHours = array_replace($filter, ['blocks' => 2]);
$long = $service->quote($twoHours, 'padel-1', '17:00');
check($long && $long['end'] === '19:00' && $long['total'] === 34000 && $long['blocks'] === 2,
    'Dos bloques consecutivos suman la tarifa de cada franja.');
check($service->quote($twoHours, 'padel-1', '15:00') === null, 'Un bloque intermedio ocupado invalida todo el intervalo.');
check($service->quote($twoHours, 'padel-1', '21:00') === null, 'El intervalo completo debe terminar antes del cierre.');
check($service->quote($filter, 'padel-1', '08:00') !== null, 'El horario publicado comienza a las ocho.');
check($service->availability(array_replace($filter, ['blocks' => 0])) === [], 'La cantidad debe ser positiva.');
check($service->availability(array_replace($filter, ['blocks' => '2'])) === [], 'La búsqueda espera una cantidad entera ya validada.');
$stale = $long;
unset($stale['blocks']);
check($service->create('demo', $twoHours, $stale, 'old')['error'] === 'SELECTION_CHANGED',
    'Una selección guardada antes del cambio de bloques se debe elegir de nuevo.');
check($service->create('demo', $filter, $long, 'different')['error'] === 'SELECTION_CHANGED',
    'El intervalo cotizado debe coincidir con la cantidad buscada.');
check($service->create('demo', array_replace($twoHours, ['date' => '2026-11-28']), $long, 'different-day')['error']
    === 'SELECTION_CHANGED', 'Cambiar la fecha invalida una cotización anterior.');
$selected = $slot($slots, 'padel-1', '18:00');
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
$secondBooking = $service->create('nuevo', $filter, $next, 'new-2')['booking'] ?? null;
check($secondBooking && $secondBooking['status'] === 'PENDIENTE', 'Una cuenta nueva puede enviar otra reserva sin aprobación previa.');
$service->syncRequestReviews(['new-2' => ['status' => 'CONFIRMADA']]);
check($service->detail('nuevo', $secondBooking['code'])['status'] === 'CONFIRMADA', 'La aprobación se refleja en la reserva seleccionada.');
check($service->detail('nuevo', $firstBooking['code'])['status'] === 'PENDIENTE', 'La otra reserva sigue pendiente de aprobación.');
check($service->cancel('nuevo', $firstBooking['code']), 'El cliente puede cancelar una solicitud pendiente.');
check(isset($service->create('nuevo', $filter, $first, 'new-3')['booking']), 'Cancelar debe liberar el horario.');
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
$football = ['mode' => 'futbol', 'date' => $filter['date'], 'site' => 'rastras', 'blocks' => 2];
$courts = array_column($scheduled->availability($football), 'court', 'court');
check(count($courts) === 7, 'El catálogo de fútbol debe ofrecer seis canchas y la cancha grande.');
check(array_keys(DemoPortal::SITES) === ['rastras'] && isset(DemoPortal::MODES['tenis']) && !isset(DemoPortal::MODES['voley']),
    'La oferta debe limitarse a Las Rastras y a los deportes del modelo.');
$small = $scheduled->quote($football, 'futbol-2', '17:00');
$large = $scheduled->quote($football, 'futbol-grande', '18:00');
check($small && $large, 'Ambas cotizaciones existen antes de reservar.');
check(isset($scheduled->create('demo', $football, $small, 'small')['booking']), 'Debe guardar los dos bloques de la cancha 2.');
check($scheduled->create('demo', $football, $large, 'large-stale')['error'] === 'SLOT_TAKEN',
    'El guardado debe detectar el solape en el primer bloque de la cancha grande.');
check($scheduled->quote($football, 'futbol-1', '18:00') !== null, 'Las canchas pequeñas no se bloquean entre ellas.');
$large = $scheduled->quote($football, 'futbol-grande', '19:00');
$largeBooking = $scheduled->create('demo', $football, $large, 'large')['booking'] ?? null;
check($largeBooking && $largeBooking['total'] === 110000 && $largeBooking['end'] === '21:00',
    'El horario adyacente se puede reservar y conserva su precio total.');
foreach (range(1, 6) as $number) {
    check(($scheduled->quote($football, 'futbol-' . $number, '19:00') === null) === ($number <= 3),
        'Solo las canchas 1 a 3 comparten espacio con la cancha grande.');
}
$scheduled->useTournamentBlocks([[
    'state' => 'PLANIFICADO', 'site' => 'Las Rastras', 'blocks' => [[
        'courtName' => 'Fútbol 6 · Cancha 3', 'date' => $filter['date'], 'start' => '10:00', 'end' => '11:00',
    ]],
]]);
check($scheduled->quote($football, 'futbol-grande', '09:00') === null, 'Un torneo en la cancha 3 bloquea el segundo tramo de la grande.');
$scheduled->useRequestBlocks(['other-session' => [
    'courtName' => 'Cancha grande', 'site' => 'rastras', 'date' => $filter['date'],
    'start' => '12:00', 'end' => '14:00', 'status' => 'PENDIENTE',
]]);
check($scheduled->quote($football, 'futbol-3', '11:00') === null, 'Una solicitud de otra sesión bloquea las canchas que ocupa.');
check($scheduled->quote($football, 'futbol-6', '11:00') !== null, 'Una solicitud de otra sesión no afecta a la cancha 6.');
$scheduled->useRequestBlocks(['cancelled-elsewhere' => [
    'courtName' => 'Cancha grande', 'site' => 'rastras', 'date' => $filter['date'],
    'start' => '12:00', 'end' => '14:00', 'status' => 'CANCELADA',
]]);
check($scheduled->quote($football, 'futbol-3', '11:00') !== null, 'Cancelar en otra sesión libera los bloques compartidos.');
check(DemoPortal::siteName('parque') === 'Parque Sur'
    && DemoPortal::bookingMode(['mode' => 'voley']) === 'Vóleibol 6x6', 'Se conservan los datos de reservas antiguas.');
echo "Servicio del portal verificado.\n";
