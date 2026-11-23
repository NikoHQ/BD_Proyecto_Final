<?php
declare(strict_types=1);

require __DIR__ . '/../web/includes/tournament-store.php';

function expect(bool $condition, string $message): void
{
    if (!$condition) throw new RuntimeException($message);
}

function rejects(string $reason, callable $action): void
{
    try {
        $action();
    } catch (TournamentRule $error) {
        expect($error->reason === $reason, $error->getMessage());
        return;
    }
    throw new RuntimeException('Faltó rechazar ' . $reason);
}

$path = sys_get_temp_dir() . '/sgcd-tournament-test-' . bin2hex(random_bytes(8));
$importPath = $path . '-import';
$now = new DateTimeImmutable('2026-11-22 12:00', new DateTimeZone('America/Santiago'));
$captain = ['name' => 'María Pérez', 'rut' => '12.345.678-5', 'identity' => 'test-captain'];
$other = ['name' => 'Martín Soto', 'rut' => '11111111-1'];
$player = ['name' => 'Daniela Pérez', 'rut' => '22.222.222-2'];

try {
    $legacyStore = new TournamentStore($importPath, $now);
    $legacy = $legacyStore->adminSnapshot();
    $legacy['tournaments'][0]['name'] = 'Torneo recuperado';
    $recovered = $legacyStore->replaceAdminSnapshot($legacy, true);
    expect($recovered['tournaments'][0]['name'] === 'Torneo recuperado' && $recovered['version'] > 1,
        'Una instancia nueva permite importar la copia del navegador.');
    rejects('STALE', fn() => $legacyStore->replaceAdminSnapshot($recovered, true));
    $store = new TournamentStore($path, $now);
    $admin = $store->adminSnapshot();
    $firstBlock = $admin['tournamentBookings'][0];
    $crossing = $admin;
    $crossing['tournamentBookings'][] = array_replace($firstBlock, ['id' => 98000, 'court' => 6, 'courtName' => 'Cancha grande']);
    rejects('INVALID_TEAM', fn() => $store->replaceAdminSnapshot($crossing));
    $padel = $admin['tournaments'][1];
    $padel['capacity'] = count($padel['roster']) + 1;
    $admin['tournaments'][1] = $padel;
    $admin = $store->replaceAdminSnapshot($admin);
    $tournament = $store->catalog()[1];
    expect($tournament['registration'] === 'OPEN' && $tournament['remaining'] === 1, 'Debe quedar el último cupo abierto.');
    expect(!isset($tournament['roster']), 'El catálogo es público.');
    rejects('INVALID_TEAM', fn() => $store->saveTeam($padel['id'], $captain, 'Exceso',
        [$player, $other], 'too-many', null, 2));
    rejects('INVALID_TEAM', fn() => $store->saveTeam($padel['id'], $captain, 'Incompleto',
        [['name' => 'Persona de prueba', 'rut' => '']], 'missing-rut', null, 2));
    expect($store->catalog()[1]['remaining'] === 1, 'Los intentos inválidos conservan el cupo.');
    rejects('DUPLICATE_RUT', fn() => $store->saveTeam($padel['id'], $captain, 'Red', [$captain], 'duplicate', null, 2));
    rejects('SIZE_CHANGED', fn() => $store->saveTeam($padel['id'], $captain, 'Red', [$player], 'wrong-size', null, 4));
    $team = $store->saveTeam($padel['id'], $captain, 'Red', [$player], 'first', null, 2);
    expect(count($team['players']) === 2 && $team['players'][0]['rut'] === '12345678-5', 'Debe incluir al capitán autenticado.');
    expect($store->saveTeam($padel['id'], $captain, 'Red', [$player], 'first')['id'] === $team['id'], 'El reintento debe dar el mismo equipo.');
    expect($store->entries($other['rut']) === [], 'Otro capitán no puede consultar el equipo.');
    expect($store->entries($captain['rut'], 'otro-perfil') === [], 'El mismo RUT en otra cuenta demo no comparte el historial.');
    rejects('FORBIDDEN', fn() => $store->withdrawTeam($padel['id'], $team['id'], $other['rut']));
    rejects('FULL', fn() => $store->saveTeam($padel['id'], $other, 'Otro equipo', [$player], 'second'));
    rejects('STALE', fn() => $store->replaceAdminSnapshot($admin));
    $team = $store->saveTeam($padel['id'], $captain, 'Red y Punto', [], 'edit', $team['id'], 2);
    expect(count($team['players']) === 1, 'Puede guardar sólo a su capitán con máximo de dos.');
    $increase = $store->adminSnapshot();
    $increase['tournaments'][1]['teamSize'] = 3;
    $increase = $store->replaceAdminSnapshot($increase);
    expect($increase['tournaments'][1]['teamSize'] === 3, 'Se puede aumentar el máximo con equipos inscritos.');
    $reduce = $increase;
    $reduce['tournaments'][1]['teamSize'] = 1;
    rejects('SIZE_CHANGED', fn() => $store->replaceAdminSnapshot($reduce));
    $increase['tournaments'][1]['teamSize'] = 2;
    $reduce = $store->replaceAdminSnapshot($increase);
    expect($reduce['tournaments'][1]['teamSize'] === 2, 'Se puede reducir el máximo sin afectar a las plantillas activas.');
    $late = new TournamentStore($path, new DateTimeImmutable($tournament['deadline'], new DateTimeZone('America/Santiago')));
    rejects('CLOSED', fn() => $late->withdrawTeam($padel['id'], $team['id'], $captain['rut'], $captain['identity']));
    $store->withdrawTeam($padel['id'], $team['id'], $captain['rut'], $captain['identity']);
    expect($store->entries($captain['rut'], $captain['identity'])[0]['withdrawn'], 'Retirar debe conservar el historial.');
    expect($store->saveTeam($padel['id'], $other, 'Otro equipo', [$player], 'second')['name'] === 'Otro equipo', 'El retiro libera cupo y RUT.');
    $store->withdrawTeam($padel['id'], $store->entries($other['rut'])[0]['id'], $other['rut']);
    // Dos procesos PHP independientes compiten por el mismo último cupo.
    $worker = <<<'WORKER'
require $argv[1];
[$path, $tournament, $start, $unique, $rut, $partner] = array_slice($argv, 2);
$store = new TournamentStore($path, new DateTimeImmutable('2026-11-22 12:00', new DateTimeZone('America/Santiago')));
$delay = max(0, (int) ((floatval($start) - microtime(true)) * 1000000));
if ($delay) usleep($delay);
try {
    $store->saveTeam($tournament, ['name' => 'Capitán ' . $unique, 'rut' => $rut],
        'Equipo ' . $unique, [['name' => 'Jugador ' . $unique, 'rut' => $partner]], 'race-' . $unique);
    echo 'INSCRITO';
} catch (TournamentRule $error) {
    echo $error->reason;
}
WORKER;
    $start = (string) (microtime(true) + 0.4);
    $storage = __DIR__ . '/../web/includes/tournament-store.php';
    $workers = [];
    foreach ([['uno', '12345678-5', '22222222-2'], ['dos', '11111111-1', '30900002-1']] as $input) {
        $process = proc_open([PHP_BINARY, '-r', $worker, $storage, $path, $padel['id'], $start, ...$input],
            [1 => ['pipe', 'w']], $pipes);
        if ($process === false) throw new RuntimeException('No se pudo iniciar el proceso de prueba.');
        $workers[] = [$process, $pipes[1]];
    }
    $results = [];
    foreach ($workers as [$process, $stream]) {
        $results[] = stream_get_contents($stream);
        fclose($stream);
        expect(proc_close($process) === 0, 'Falló un proceso de prueba.');
    }
    sort($results);
    expect($results === ['FULL', 'INSCRITO'], 'Sólo un proceso puede reservar el último cupo.');
    $tennisConfig = $store->adminSnapshot();
    $tennis = $tennisConfig['tournaments'][2];
    $tennisConfig['tournaments'][2]['teamSize'] = 3;
    $store->replaceAdminSnapshot($tennisConfig);
    $retired = $store->saveTeam($tennis['id'], $captain, 'Raquetas', [$player], 'tennis', null, 3);
    $store->withdrawTeam($tennis['id'], $retired['id'], $captain['rut'], $captain['identity']);
    $tennisConfig = $store->adminSnapshot();
    $tennisConfig['tournaments'][2]['teamSize'] = 1;
    $tennisConfig = $store->replaceAdminSnapshot($tennisConfig);
    expect(count(end($tennisConfig['tournaments'][2]['roster'])['players']) === 2,
        'Reducir el máximo conserva la plantilla retirada.');

    echo "Inscripción a torneos verificada.\n";
} finally {
    foreach ([$path, $path . '.lock', $importPath, $importPath . '.lock'] as $file) {
        if (is_file($file)) unlink($file);
    }
}
