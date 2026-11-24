<?php
declare(strict_types=1);

require_once __DIR__ . '/../cliente/demo.php';

final class TournamentRule extends RuntimeException
{
    public function __construct(public readonly string $reason, string $message)
    {
        parent::__construct($message);
    }
}

final class TournamentStore
{
    public const STATES = ['PLANIFICADO', 'EN_CURSO', 'FINALIZADO', 'CANCELADO'];
    private readonly string $path;
    private readonly DateTimeImmutable $now;

    public function __construct(?string $path = null, ?DateTimeImmutable $now = null)
    {
        $this->path = $path ?? sys_get_temp_dir() . '/sgcd-tournaments-' . hash('sha256', __DIR__) . '.json';
        $zone = new DateTimeZone('America/Santiago');
        $this->now = $now?->setTimezone($zone) ?? new DateTimeImmutable('now', $zone);
    }

    public static function normalizeRut(string $rut): ?string
    {
        $rut = strtoupper(str_replace(['.', '-', ' '], '', trim($rut)));
        if (!preg_match('/^[1-9][0-9]{0,7}[0-9K]$/D', $rut)) return null;
        $body = substr($rut, 0, -1);
        $sum = 0;
        foreach (str_split(strrev($body)) as $index => $digit) {
            $sum += (int) $digit * ($index % 6 + 2);
        }
        $check = '0K987654321'[$sum % 11];
        return $rut[-1] === $check ? $body . '-' . $check : null;
    }

    public function catalog(): array
    {
        return $this->read(function (array $data): array {
            $catalog = [];
            foreach ($data['tournaments'] as $index => $tournament) {
                [$blocks, $deadline] = $this->schedule($data, $index);
                $remaining = max(0, $tournament['capacity'] - $tournament['teams']);
                $registration = $this->registration($tournament, $deadline, $remaining);
                $public = array_intersect_key($tournament, array_flip([
                    'id', 'name', 'sport', 'site', 'siteName', 'days', 'capacity', 'teamSize', 'state', 'teams',
                ]));
                $catalog[] = $public + ['siteName' => $tournament['site'], 'blocks' => $blocks, 'deadline' => $deadline,
                    'remaining' => $remaining, 'registration' => $registration,
                    'canManage' => $this->acceptsChanges($tournament, $deadline)];
            }
            return $catalog;
        });
    }

    public function entries(string $captainRut, string $identity = ''): array
    {
        return $this->read(static function (array $data) use ($captainRut, $identity): array {
            $captainRut = self::normalizeRut($captainRut);
            if ($captainRut === null) return [];
            $entries = [];
            foreach ($data['tournaments'] as $tournament) {
                foreach ($tournament['roster'] as $team) {
                    if (self::owns($team, $captainRut, $identity)) {
                        $entries[] = array_intersect_key($team, array_flip(['id', 'name', 'players', 'withdrawn']))
                            + ['tournamentId' => $tournament['id']];
                    }
                }
            }
            return $entries;
        });
    }

    public function validateTeam(string $tournamentId, array $captain, string $name, array $players,
        ?string $teamId = null, ?int $expectedMaximum = null): array
    {
        return $this->read(function (array $data) use ($tournamentId, $captain, $name, $players, $teamId, $expectedMaximum): array {
            $index = $this->tournamentIndex($data, $tournamentId);
            return $this->checkedTeam($data, $index, $captain, $name, $players, $teamId, $expectedMaximum);
        });
    }

    public function saveTeam(string $tournamentId, array $captain, string $name, array $players, string $requestKey,
        ?string $teamId = null, ?int $expectedMaximum = null): array
    {
        return $this->update(function (array &$data) use ($tournamentId, $captain, $name, $players, $requestKey, $teamId, $expectedMaximum): array {
            $index = $this->tournamentIndex($data, $tournamentId);
            $tournament = &$data['tournaments'][$index];
            $rut = self::normalizeRut($captain['rut'] ?? '');
            if ($rut === null) throw new TournamentRule('FORBIDDEN', 'Tu ficha requiere un RUT válido.');
            if ($requestKey === '' || strlen($requestKey) > 128) {
                throw new TournamentRule('INVALID_TEAM', 'Recarga el formulario y vuelve a intentarlo.');
            }
            $identity = $captain['identity'] ?? '';
            $retry = hash('sha256', serialize([$tournamentId, $rut, $identity, $teamId, $requestKey]));
            if (isset($data['requests'][$retry])) return $data['requests'][$retry];

            $clean = $this->checkedTeam($data, $index, $captain, $name, $players, $teamId, $expectedMaximum);
            $teamIndex = $teamId === null ? count($tournament['roster']) : $this->teamIndex($tournament, $teamId);
            $existing = $tournament['roster'][$teamIndex] ?? [];
            $team = array_replace($existing, $clean, ['id' => $teamId ?? self::newId(), 'withdrawn' => false, 'owner' => $identity]);
            $tournament['roster'][$teamIndex] = $team;
            $tournament['teams'] = $this->countTeams($tournament['roster']);
            return $data['requests'][$retry] = $team + ['tournamentId' => $tournamentId];
        });
    }

    public function withdrawTeam(string $tournamentId, string $teamId, string $captainRut, string $identity = ''): void
    {
        $this->update(function (array &$data) use ($tournamentId, $teamId, $captainRut, $identity): void {
            $index = $this->tournamentIndex($data, $tournamentId);
            $tournament = &$data['tournaments'][$index];
            $teamIndex = $this->teamIndex($tournament, $teamId);
            $team = &$tournament['roster'][$teamIndex];
            if (!self::owns($team, self::normalizeRut($captainRut), $identity)) {
                throw new TournamentRule('FORBIDDEN', 'Sólo el capitán puede retirar este equipo.');
            }
            if ($team['withdrawn']) return;
            [, $deadline] = $this->schedule($data, $index);
            if (!$this->acceptsChanges($tournament, $deadline)) {
                throw new TournamentRule('CLOSED', 'El torneo ya no admite cambios de equipo.');
            }
            $team['withdrawn'] = true;
            $tournament['teams'] = $this->countTeams($tournament['roster']);
        });
    }

    private function checkedTeam(array $data, int $index, array $captain, string $name, array $players,
        ?string $teamId, ?int $expectedMaximum, bool $staff = false, bool $import = false, bool $withdrawn = false): array
    {
        $tournament = $data['tournaments'][$index];
        $captainRut = self::normalizeRut($captain['rut'] ?? '');
        if ($captainRut === null) throw new TournamentRule('FORBIDDEN', 'Tu ficha requiere un RUT válido.');
        [, $deadline] = $this->schedule($data, $index);
        if ($teamId !== null) {
            $current = $tournament['roster'][$this->teamIndex($tournament, $teamId)];
            if (!$staff && !self::owns($current, $captainRut, $captain['identity'] ?? '')) {
                throw new TournamentRule('FORBIDDEN', 'Sólo el capitán puede modificar este equipo.');
            }
            if ($current['withdrawn'] || (!$this->acceptsChanges($tournament, $deadline)
                && !($staff && in_array($tournament['state'], ['PLANIFICADO', 'EN_CURSO'], true)))) {
                throw new TournamentRule('CLOSED', 'El torneo ya no admite cambios de equipo.');
            }
        } elseif (!$import) {
            $registration = $this->registration($tournament, $deadline, $tournament['capacity'] - $tournament['teams']);
            if ($registration === 'FULL') throw new TournamentRule('FULL', 'Ya se ocuparon todos los cupos.');
            if ($registration !== 'OPEN') throw new TournamentRule('CLOSED', 'El torneo ya no admite inscripciones.');
        }
        if ($expectedMaximum !== null && $expectedMaximum !== $tournament['teamSize']) {
            throw new TournamentRule('SIZE_CHANGED', 'Cambió el máximo de jugadores. Revisa tu plantilla.');
        }
        if (!$withdrawn && count($players) >= $tournament['teamSize']) {
            throw new TournamentRule('INVALID_TEAM', 'La plantilla admite hasta ' . $tournament['teamSize'] . ' jugadores, incluido el capitán.');
        }
        $clean = [];
        foreach ([$captain, ...$players] as $player) {
            $rut = self::normalizeRut(is_string($player['rut'] ?? null) ? $player['rut'] : '');
            $playerName = trim(is_string($player['name'] ?? null) ? $player['name'] : '');
            if ($rut === null || !$this->validName($playerName)) {
                throw new TournamentRule('INVALID_TEAM', 'Revisa el nombre y el RUT de cada jugador.');
            }
            if (isset($clean[$rut])) throw new TournamentRule('DUPLICATE_RUT', 'Hay un RUT repetido en la plantilla.');
            $clean[$rut] = ['name' => $playerName, 'rut' => $rut];
        }
        $name = trim($name);
        $taken = [];
        foreach ($tournament['roster'] as $other) {
            if ($other['id'] === $teamId) continue;
            $taken[$this->nameKey($other['name'])] = true;
            if (!$withdrawn && !$other['withdrawn'] && array_intersect_key($clean, array_column($other['players'], null, 'rut'))) {
                throw new TournamentRule('PLAYER_TAKEN', 'Un integrante ya participa en otro equipo activo de este torneo.');
            }
        }
        if ($tournament['teamSize'] === 1 && !$staff) {
            $name = $clean[$captainRut]['name'];
            $base = mb_substr($name, 0, 94);
            for ($suffix = 2; isset($taken[$this->nameKey($name)]); $suffix++) $name = $base . ' (' . $suffix . ')';
        }
        if (!$this->validName($name)) throw new TournamentRule('INVALID_TEAM', 'Ingresa un nombre de equipo de 1 a 100 caracteres.');
        if (isset($taken[$this->nameKey($name)])) throw new TournamentRule('NAME_TAKEN', 'Ya existe una inscripción con ese nombre de equipo.');
        return ['name' => $name, 'players' => array_values($clean)];
    }

    private static function owns(array $team, ?string $rut, string $identity): bool
    {
        return $team['players'][0]['rut'] === $rut && ($team['owner'] ?? '') === $identity;
    }

    private function validName(string $name): bool
    {
        return preg_match('/^[^\p{C}]{1,100}$/uD', $name) === 1;
    }

    private function nameKey(string $name): string
    {
        return mb_strtolower(preg_replace('/\s+/u', ' ', trim($name)));
    }

    private function tournamentIndex(array $data, string $id): int
    {
        foreach ($data['tournaments'] as $index => $tournament) {
            if ($tournament['id'] === $id) return $index;
        }
        throw new TournamentRule('NOT_FOUND', 'No encontramos ese torneo.');
    }

    private function teamIndex(array $tournament, string $id): int
    {
        foreach ($tournament['roster'] as $index => $team) {
            if ($team['id'] === $id) return $index;
        }
        throw new TournamentRule('NOT_FOUND', 'No encontramos esa inscripción.');
    }

    private function schedule(array $data, int $index): array
    {
        $blocks = [];
        foreach ($data['tournamentBookings'] as $block) {
            if ($block['tournamentId'] !== $index || $block['status'] === 'cancelled') continue;
            $blocks[] = array_intersect_key($block, array_flip(['date', 'start', 'end', 'courtName', 'activity']));
        }
        usort($blocks, static fn(array $a, array $b): int => [$a['date'], $a['start']] <=> [$b['date'], $b['start']]);
        return [$blocks, $blocks ? $blocks[0]['date'] . ' ' . $blocks[0]['start'] : null];
    }

    private function registration(array $tournament, ?string $deadline, int $remaining): string
    {
        if ($tournament['state'] !== 'PLANIFICADO' || $this->now->format('Y-m-d') > end($tournament['days'])
            || ($deadline !== null && $this->now->format('Y-m-d H:i') >= $deadline)) return 'CLOSED';
        if ($deadline === null) return 'UNSCHEDULED';
        return $remaining > 0 ? 'OPEN' : 'FULL';
    }

    private function acceptsChanges(array $tournament, ?string $deadline): bool
    {
        return $tournament['state'] === 'PLANIFICADO'
            && $this->now->format('Y-m-d H:i') < ($deadline ?? $tournament['days'][0] . ' 00:00');
    }

    private function countTeams(array $roster): int
    {
        return count(array_filter($roster, static fn(array $team): bool => !$team['withdrawn']));
    }

    private static function newId(): string
    {
        return bin2hex(random_bytes(12));
    }

    public function adminSnapshot(): array
    {
        return $this->read(fn(array $data): array => $this->publicAdminSnapshot($data));
    }

    public function replaceAdminSnapshot(array $snapshot, bool $import = false): array
    {
        $this->update(function (array &$data) use ($snapshot, $import): void {
            if (($snapshot['version'] ?? null) !== $data['version']) {
                throw new TournamentRule('STALE', 'Los torneos cambiaron. Revisa los datos actualizados e inténtalo otra vez.');
            }
            if ($import) {
                if ($data['version'] !== 1) {
                    throw new TournamentRule('STALE', 'La instancia ya tiene cambios compartidos. Se conserva la copia del navegador.');
                }
                $data['tournaments'] = [];
                $data['tournamentBookings'] = [];
            }
            $proposed = $data;
            $tournaments = $snapshot['tournaments'] ?? null;
            $blocks = $snapshot['tournamentBookings'] ?? null;
            if (!is_array($tournaments) || !array_is_list($tournaments) || !$tournaments || count($tournaments) < count($data['tournaments'])
                || !is_array($blocks) || !array_is_list($blocks)) {
                throw new TournamentRule('INVALID_TEAM', 'Los datos del torneo están incompletos.');
            }

            $names = [];
            foreach ($tournaments as $index => $tournament) {
                $previous = $data['tournaments'][$index] ?? null;
                $saved = $this->adminTournament($tournament, $previous, $import);
                $key = $this->nameKey($saved['site']) . '/' . $this->nameKey($saved['name']);
                if (isset($names[$key])) throw new TournamentRule('NAME_TAKEN', 'Ya existe un torneo con ese nombre en este recinto.');
                $names[$key] = true;
                $proposed['tournaments'][$index] = $saved;
            }
            $proposed['tournamentBookings'] = $this->adminBlocks($blocks, $proposed['tournaments'], $data['tournamentBookings'], $import);

            foreach ($tournaments as $index => $tournament) {
                $previous = $data['tournaments'][$index]['roster'] ?? [];
                $teams = $tournament['roster'] ?? [];
                if (!is_array($teams) || !array_is_list($teams) || count($teams) < count($previous)) {
                    throw new TournamentRule('INVALID_TEAM', 'Retira el equipo para conservar su historial.');
                }
                foreach ($teams as $teamIndex => $team) {
                    $saved = $this->adminTeam($proposed, $index, $team, $previous[$teamIndex] ?? null, $import);
                    $proposed['tournaments'][$index]['roster'][$teamIndex] = $saved;
                    $proposed['tournaments'][$index]['teams'] = $this->countTeams($proposed['tournaments'][$index]['roster']);
                }
                $configured = $proposed['tournaments'][$index];
                if ($configured['teams'] > $configured['capacity']) {
                    throw new TournamentRule('FULL', 'La cantidad de equipos supera los cupos del torneo.');
                }
                foreach ($configured['roster'] as $team) {
                    if (!$team['withdrawn'] && count($team['players']) > $configured['teamSize']) {
                        throw new TournamentRule('SIZE_CHANGED', 'El máximo no puede quedar por debajo de una plantilla inscrita.');
                    }
                }
            }
            $data = $proposed;
        });
        return $this->adminSnapshot();
    }

    private function adminTournament(array $input, ?array $previous, bool $import): array
    {
        $name = trim((string) ($input['name'] ?? ''));
        $site = trim((string) ($input['site'] ?? ''));
        $siteName = trim((string) ($input['siteName'] ?? $site));
        $sport = trim((string) ($input['sport'] ?? ''));
        $days = $input['days'] ?? [];
        $state = $input['state'] ?? '';
        $capacity = $input['capacity'] ?? null;
        $teamSize = $input['teamSize'] ?? null;
        $discount = $previous['discount'] ?? ($import ? ($input['discount'] ?? 0) : 0);
        if (!$this->validName($name) || !$this->validName($site) || !$this->validName($siteName) || !$this->validName($sport)
            || !is_array($days) || !array_is_list($days) || !$days
            || !in_array($state, self::STATES, true) || !is_int($capacity) || $capacity < 2 || $capacity > 128
            || !is_int($teamSize) || $teamSize < 1 || $teamSize > 50 || !is_numeric($discount) || $discount < 0 || $discount > 100) {
            throw new TournamentRule('INVALID_TEAM', 'Revisa la configuración, las fechas, los cupos y el tamaño del equipo.');
        }
        foreach ($days as $day) {
            if (!$this->validDate($day)) throw new TournamentRule('INVALID_TEAM', 'Revisa las fechas del torneo.');
        }
        $days = array_values(array_unique($days));
        sort($days);
        $allowed = match ($previous['state'] ?? null) {
            'PLANIFICADO' => ['PLANIFICADO', 'EN_CURSO', 'CANCELADO'],
            'EN_CURSO' => ['EN_CURSO', 'FINALIZADO', 'CANCELADO'],
            null => $import ? self::STATES : ['PLANIFICADO'],
            default => [$previous['state']],
        };
        if (!in_array($state, $allowed, true) || ($previous && $previous['id'] !== ($input['id'] ?? null))) {
            throw new TournamentRule('STALE', 'Revisa el torneo o el cambio de estado solicitado.');
        }
        if ($previous && $previous['state'] !== 'PLANIFICADO' && $teamSize !== $previous['teamSize']) {
            throw new TournamentRule('CLOSED', 'El máximo se puede ajustar mientras el torneo está planificado.');
        }
        $id = $previous['id'] ?? self::newId();
        $roster = $previous['roster'] ?? [];
        return compact('id', 'name', 'site', 'siteName', 'sport', 'days', 'state', 'capacity', 'teamSize', 'discount', 'roster')
            + ['teams' => $previous['teams'] ?? 0];
    }

    private function adminBlocks(array $input, array $tournaments, array $previous, bool $import): array
    {
        $old = array_column($previous, null, 'id');
        $blocks = [];
        foreach ($input as $block) {
            $id = $block['id'] ?? null;
            $index = $block['tournamentId'] ?? null;
            $tournament = is_int($index) ? ($tournaments[$index] ?? null) : null;
            $day = $block['date'] ?? '';
            $start = $block['start'] ?? '';
            $end = $block['end'] ?? '';
            $court = $block['court'] ?? null;
            $courtName = trim((string) ($block['courtName'] ?? ''));
            $activity = trim((string) ($block['activity'] ?? ''));
            $status = $block['status'] ?? '';
            if (!is_int($id) || $id < 1 || isset($blocks[$id]) || !$tournament || !$this->validDate($day)
                || $day < $tournament['days'][0] || $day > end($tournament['days'])
                || !is_int($court) || $court < 0 || !$this->validName($courtName) || !$this->validName($activity)
                || !preg_match('/^(?:[01]\d|2[0-3]):[0-5]\d$/D', $start)
                || !preg_match('/^(?:(?:[01]\d|2[0-3]):[0-5]\d|24:00)$/D', $end) || $start >= $end
                || !in_array($status, ['confirmed', 'cancelled'], true)) {
                throw new TournamentRule('INVALID_TEAM', 'Revisa la cancha y las horas del bloque.');
            }
            if (isset($old[$id]) && ($old[$id]['tournamentId'] !== $index
                || ($old[$id]['status'] === 'cancelled' && $status !== 'cancelled'))) {
                throw new TournamentRule('STALE', 'El bloque cambió. Recarga la agenda.');
            }
            if (!$import && !isset($old[$id]) && substr($start, -2) !== substr($end, -2)) {
                throw new TournamentRule('INVALID_TEAM', 'Programa bloques completos de una hora.');
            }
            if (!$import && !isset($old[$id]) && !in_array($tournament['state'], ['PLANIFICADO', 'EN_CURSO'], true)) {
                throw new TournamentRule('CLOSED', 'Este torneo ya no admite nuevos bloques.');
            }
            if ($status === 'confirmed') {
                foreach ($blocks as $other) {
                    if ($other['status'] === 'confirmed' && $other['date'] === $day
                        && $tournaments[$other['tournamentId']]['site'] === $tournament['site']
                        && DemoPortal::namedCourtsShareSpace($other['courtName'], $courtName, $tournament['site'])
                        && $other['start'] < $end && $other['end'] > $start) {
                        throw new TournamentRule('INVALID_TEAM', 'La cancha ya tiene un bloque de torneo en ese horario.');
                    }
                }
            }
            $blocks[$id] = compact('id', 'court', 'courtName', 'start', 'end', 'activity', 'status')
                + ['date' => $day, 'tournamentId' => $index, 'client' => $tournament['name'], 'origin' => 'Torneo', 'amount' => 0];
        }
        if (array_diff_key($old, $blocks)) throw new TournamentRule('STALE', 'Libera el bloque para conservar su historial.');
        return array_values($blocks);
    }

    private function adminTeam(array $data, int $index, array $team, ?array $previous, bool $import): array
    {
        $name = $team['name'] ?? '';
        $players = $team['players'] ?? [];
        $withdrawn = $team['withdrawn'] ?? false;
        if (!is_bool($withdrawn) || !is_array($players) || !array_is_list($players) || !isset($players[0])
            || ($previous && ($team['id'] ?? null) !== $previous['id'])) {
            throw new TournamentRule('INVALID_TEAM', 'Revisa la plantilla del equipo.');
        }
        if ($previous && $previous['name'] === $name && $previous['players'] === $players && $previous['withdrawn'] === $withdrawn) {
            return $previous;
        }
        if ($withdrawn && !$import) {
            if (!$previous || $data['tournaments'][$index]['state'] !== 'PLANIFICADO') {
                throw new TournamentRule('CLOSED', 'Este equipo ya no se puede retirar.');
            }
            return array_replace($previous, ['withdrawn' => true]);
        }
        $checked = $this->checkedTeam($data, $index, $players[0], $name, array_slice($players, 1), $previous['id'] ?? null, null, true, $import, $withdrawn);
        $rut = $checked['players'][0]['rut'];
        $owner = ($previous['players'][0]['rut'] ?? '') === $rut ? ($previous['owner'] ?? '') : '';
        if ($owner === '') {
            $owner = match ($rut) {
                '30900001-3' => 'demo-demo',
                '30900002-1' => 'demo-nuevo',
                default => $this->registeredCaptain($data, $rut),
            };
        }
        return array_replace($previous ?? [], $checked, [
            'id' => $previous['id'] ?? self::newId(), 'withdrawn' => $withdrawn, 'owner' => $owner,
        ]);
    }

    private function registeredCaptain(array $data, string $rut): string
    {
        $owners = [];
        foreach ($data['tournaments'] as $tournament) {
            foreach ($tournament['roster'] as $team) {
                if ($team['players'][0]['rut'] === $rut && !empty($team['owner'])) $owners[$team['owner']] = true;
            }
        }
        return count($owners) === 1 ? (string) array_key_first($owners) : '';
    }

    private function validDate(mixed $date): bool
    {
        return is_string($date) && preg_match('/^(\d{4})-(\d{2})-(\d{2})$/D', $date, $parts)
            && checkdate((int) $parts[2], (int) $parts[3], (int) $parts[1]);
    }

    private function publicAdminSnapshot(array $data): array
    {
        unset($data['requests']);
        foreach ($data['tournaments'] as $index => &$tournament) {
            [, $deadline] = $this->schedule($data, $index);
            foreach ($tournament['roster'] as &$team) unset($team['owner']);
            unset($team);
            $tournament['registration'] = $this->registration($tournament, $deadline, $tournament['capacity'] - $tournament['teams']);
        }
        return $data;
    }

    private function read(callable $operation): mixed
    {
        return $this->withLock($operation, false);
    }

    private function update(callable $operation): mixed
    {
        return $this->withLock($operation, true);
    }

    private function withLock(callable $operation, bool $write): mixed
    {
        $lock = fopen($this->path . '.lock', 'c');
        if ($lock === false) throw new RuntimeException('No se pudo abrir el almacenamiento de torneos.');
        try {
            if (!flock($lock, $write ? LOCK_EX : LOCK_SH)) throw new RuntimeException('No se pudo acceder a los torneos.');
            $data = is_file($this->path)
                ? json_decode(file_get_contents($this->path), true, flags: JSON_THROW_ON_ERROR) : $this->seed();
            $before = $data;
            $result = $operation($data);
            if ($write && $data !== $before) {
                $data['version']++;
                $temporary = tempnam(dirname($this->path), 'sgcd-tournaments-');
                if ($temporary === false) throw new RuntimeException('No se pudo guardar el torneo.');
                try {
                    $json = json_encode($data, JSON_THROW_ON_ERROR);
                    if (file_put_contents($temporary, $json) !== strlen($json) || !rename($temporary, $this->path)) {
                        throw new RuntimeException('No se pudo guardar el torneo.');
                    }
                } finally {
                    if (is_file($temporary)) unlink($temporary);
                }
            }
            return $result;
        } finally {
            fclose($lock);
        }
    }

    private function seed(): array
    {
        $year = $this->now->format('Y');
        $first = new DateTimeImmutable($year . '-11-20', $this->now->getTimezone());
        $padel = new DateTimeImmutable($year . '-12-05', $this->now->getTimezone());
        if ($padel <= $this->now) $padel = $this->now->modify('+7 days');
        $fixtures = [
            ['copa-primavera', 'Copa Primavera Fútbol 6', 'Las Rastras', 'Fútbol 6', $first, 3, 16, 10, 6, 0, 'Fútbol 6 · Cancha 1',
                ['Los Robles', 'Atlético del Valle', 'Deportivo Maule', 'Rayo Norte', 'Club Lircay', 'Unión Talca',
                    'Los Halcones', 'Cancha Abierta', 'Estrella del Sur', 'Barrio Central', 'Los Alerces', 'Ribera FC']],
            ['padel-mixto', 'Torneo Pádel Mixto', 'Las Rastras', 'Pádel dobles', $padel, 2, 12, 2, 2, 7, 'Pádel 1',
                ['Doble Rebote', 'Punto de Oro', 'Red Central', 'Saque Cruzado', 'Pádel Sur', 'Set Decisivo', 'Viboras del Maule', 'Red de Talca']],
            ['copa-tenis', 'Copa de Tenis Las Rastras', 'Las Rastras', 'Tenis', $padel->modify('+7 days'), 2, 8, 1, 1, 9, 'Tenis 1',
                ['Saque Alto', 'Club Horizonte', 'Red del Maule', 'Punto Final']],
        ];
        $tournaments = [];
        $blocks = [];
        foreach ($fixtures as $index => [$id, $name, $site, $sport, $start, $length, $capacity, $teamSize, $rosterSize, $court, $courtName, $names]) {
            $days = [];
            for ($i = 0; $i < $length; $i++) {
                $days[] = $start->modify("+$i days")->format('Y-m-d');
                $blocks[] = ['id' => 90001 + $index * 100 + $i, 'tournamentId' => $index, 'court' => $court,
                    'courtName' => $courtName, 'date' => $days[$i], 'start' => '10:00', 'end' => '13:00',
                    'activity' => $i === 0 ? 'Primera jornada' : 'Rondas finales', 'client' => $name,
                    'status' => 'confirmed', 'origin' => 'Torneo', 'amount' => 0];
            }
            $state = $this->now->format('Y-m-d') < $days[0] ? 'PLANIFICADO'
                : ($this->now->format('Y-m-d') > $days[$length - 1] ? 'FINALIZADO' : 'EN_CURSO');
            $roster = [];
            foreach ($names as $teamIndex => $teamName) {
                $players = [];
                $firstNames = ['Ana', 'Javier', 'Isabel', 'Tomás', 'Paula', 'Bruno', 'Claudia'];
                $lastNames = ['Torres', 'Vidal', 'Reyes', 'Silva', 'Leiva', 'Molina', 'Díaz', 'Ortiz', 'Ríos', 'Lagos', 'Soto', 'Pardo'];
                for ($i = 0; $i < $rosterSize; $i++) {
                    $body = (string) (32000000 + $index * 10000 + $teamIndex * 50 + $i);
                    $given = $firstNames[($teamIndex + $i) % count($firstNames)];
                    $last = $lastNames[($teamIndex + $i * 3) % count($lastNames)];
                    foreach (str_split('0123456789K') as $digit) {
                        $rut = self::normalizeRut($body . $digit);
                        if ($rut !== null) break;
                    }
                    $players[] = ['name' => $given . ' ' . $last, 'rut' => $rut];
                }
                $roster[] = ['id' => $id . '-' . ($teamIndex + 1), 'name' => $teamName,
                    'players' => $players, 'withdrawn' => false];
            }
            $tournaments[] = compact('id', 'name', 'site', 'sport', 'days', 'capacity', 'teamSize', 'state', 'roster')
                + ['teams' => count($roster), 'discount' => 0];
        }
        return ['version' => 1, 'tournaments' => $tournaments, 'tournamentBookings' => $blocks, 'requests' => []];
    }
}
