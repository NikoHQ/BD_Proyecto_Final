<?php
declare(strict_types=1);

final class DemoPortal
{
    public const MODES = [
        'padel' => ['label' => 'Pádel dobles', 'players' => 'Juego en parejas', 'icon' => 'bullseye'],
        'futbol' => ['label' => 'Fútbol 6', 'players' => 'Canchas individuales o cancha grande', 'icon' => 'dribbble'],
        'tenis' => ['label' => 'Tenis', 'players' => 'Cancha de demostración', 'icon' => 'circle-half'],
    ];
    public const SITES = ['rastras' => 'Las Rastras'];
    public const BLOCK_MINUTES = 60;
    private const OPEN_HOUR = 8;
    private const CLOSE_HOUR = 22;
    public const MAX_BLOCKS = self::CLOSE_HOUR - self::OPEN_HOUR;
    private const DEMO_RUTS = ['demo' => '30900001-3', 'nuevo' => '30900002-1'];
    private const FOOTBALL_COMPONENTS = ['futbol-1', 'futbol-2', 'futbol-3'];
    private const FOOTBALL_RATES = [18000, 22000];
    private const COURTS = [
        'padel-1' => ['name' => 'Pádel 1', 'mode' => 'padel', 'rates' => [16000, 18000]],
        'padel-2' => ['name' => 'Pádel 2', 'mode' => 'padel', 'rates' => [16000, 17000]],
        'futbol-1' => ['name' => 'Fútbol 6 · Cancha 1', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-2' => ['name' => 'Fútbol 6 · Cancha 2', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-3' => ['name' => 'Fútbol 6 · Cancha 3', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-4' => ['name' => 'Fútbol 6 · Cancha 4', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-5' => ['name' => 'Fútbol 6 · Cancha 5', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-6' => ['name' => 'Fútbol 6 · Cancha 6', 'mode' => 'futbol', 'rates' => self::FOOTBALL_RATES],
        'futbol-grande' => ['name' => 'Cancha grande', 'mode' => 'futbol', 'rates' => [45000, 55000]],
        'tenis-1' => ['name' => 'Tenis 1', 'mode' => 'tenis', 'rates' => [14000, 16000]],
    ];
    private array $bookings;
    private array $accounts;
    private array $rates;
    private array $sharedTournamentBlocks = [];
    private array $sharedRequestBlocks = [];
    public string $scenario = '';

    public function __construct(array $data, public readonly string $today, public readonly string $time)
    {
        $this->rates = $data['rates'] ?? [];
        $this->scenario = $data['scenario'] ?? '';
        $this->accounts = $data['accounts'] ?? [
            'demo' => ['name' => 'María Pérez'],
            'nuevo' => ['name' => 'Álex Soto'],
        ];
        $day = new DateTimeImmutable($today);
        $friday = $this->sampleDate();
        $this->bookings = $data['bookings'] ?? [
            'R-10451' => $this->seed('R-10451', 'demo', 'padel-2', $day->modify('-7 days')->format('Y-m-d'), '17:00', 'COMPLETADA'),
            'R-10452' => $this->seed('R-10452', 'demo', 'padel-1', $friday, '20:00', 'CONFIRMADA'),
            'R-10453' => $this->seed('R-10453', 'demo', 'padel-2', $friday, '20:00', 'PENDIENTE'),
            'R-10454' => $this->seed('R-10454', 'demo', 'padel-2', $day->modify('-2 days')->format('Y-m-d'), '18:00', 'CANCELADA'),
            'TORNEO' => $this->seed('TORNEO', '', 'padel-1', $friday, '16:00', 'CONFIRMADA'),
        ];
        unset($this->bookings['MANTENCION']);
    }

    public function snapshot(): array
    {
        return ['bookings' => $this->bookings, 'accounts' => $this->accounts,
            'rates' => $this->rates, 'scenario' => $this->scenario];
    }

    public function sampleDate(): string
    {
        $day = new DateTimeImmutable($this->today);
        return ($day->format('N') === '5' && $this->time < '16:00' ? $day : $day->modify('next friday'))->format('Y-m-d');
    }

    public function profile(?string $username): ?array
    {
        $account = $this->accounts[$username ?? ''] ?? null;
        return $account ? ['name' => $account['name'], 'rut' => $account['rut'] ?? self::DEMO_RUTS[$username] ?? '',
            'identity' => isset($account['hash']) ? hash('sha256', $account['hash']) : 'demo-' . $username] : null;
    }

    public function login(string $username, string $password): bool
    {
        $account = $this->accounts[$username] ?? null;
        if (!$account) return false;
        return isset($account['hash']) ? password_verify($password, $account['hash']) : $password === 'SGCDdemo2026';
    }

    public function register(string $name, string $rut, string $username, string $password): ?string
    {
        if (!preg_match('/^[a-z0-9._-]{3,30}$/D', $username) || !preg_match('/^.{2,100}$/uD', $name) ||
            strlen($password) < 8 || strlen($password) > 72 || str_contains($password, "\0")) {
            return 'Revisa el nombre, el usuario y la contraseña de demostración.';
        }
        $rut = strtoupper(str_replace(['.', '-', ' '], '', $rut));
        if (!preg_match('/^[1-9][0-9]{0,7}[0-9K]$/D', $rut)) return 'Ingresa un RUT ficticio válido.';
        $sum = 0;
        foreach (str_split(strrev(substr($rut, 0, -1))) as $i => $digit) {
            $sum += (int) $digit * ($i % 6 + 2);
        }
        if (substr($rut, -1) !== '0K987654321'[$sum % 11]) return 'Revisa el dígito verificador del RUT.';
        if (isset($this->accounts[$username]) || in_array($rut, array_column($this->accounts, 'rut'), true) ||
            in_array($rut, array_map(static fn(string $value): string => str_replace('-', '', $value), self::DEMO_RUTS), true)) {
            return 'El usuario o el RUT ya se encuentra registrado en esta demo.';
        }
        $this->accounts[$username] = ['name' => $name, 'rut' => $rut,
            'hash' => password_hash($password, PASSWORD_DEFAULT)];
        return null;
    }

    public static function siteName(string $site): string
    {
        return self::SITES[$site] ?? ($site === 'parque' ? 'Parque Sur' : $site);
    }

    public static function bookingMode(array $booking): string
    {
        return $booking['modeLabel'] ?? match ($booking['mode']) {
            'futbol' => ($booking['courtName'] ?? '') === 'Cancha Fútbol 5' ? 'Fútbol 5' : self::MODES['futbol']['label'],
            'voley' => 'Vóleibol 6x6',
            default => self::MODES[$booking['mode']]['label'] ?? $booking['mode'],
        };
    }

    public function validFilter(array $filter): bool
    {
        $blocks = $filter['blocks'] ?? 1;
        if (!is_int($blocks) || $blocks < 1 || $blocks > self::MAX_BLOCKS ||
            !preg_match('/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/D', $filter['date'])) return false;
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', $filter['date']);
        return $date && $date->format('Y-m-d') === $filter['date'] && $filter['date'] >= $this->today
            && isset(self::MODES[$filter['mode']])
            && ($filter['site'] === '' || isset(self::SITES[$filter['site']]));
    }

    public function availability(array $filter): array
    {
        if (!$this->validFilter($filter)) return [];
        $duration = ($filter['blocks'] ?? 1) * self::BLOCK_MINUTES;
        $day = (int) (new DateTimeImmutable($filter['date']))->format('N');
        if ($day === 1) return [];
        $close = ($day === 7 ? 20 : self::CLOSE_HOUR) * self::BLOCK_MINUTES;
        $result = [];
        foreach (self::COURTS as $id => $court) {
            if ($court['mode'] !== $filter['mode']) continue;
            for ($start = self::OPEN_HOUR * self::BLOCK_MINUTES; $start + $duration <= $close; $start += self::BLOCK_MINUTES) {
                $end = $start + $duration;
                $from = $this->clock($start);
                $until = $this->clock($end);
                if (($filter['date'] === $this->today && $from <= $this->time) ||
                    $this->overlaps($id, $filter['date'], $from, $until)) continue;
                $total = 0;
                for ($block = $start; $block < $end; $block += self::BLOCK_MINUTES) {
                    $total += $court['rates'][$block < 18 * self::BLOCK_MINUTES ? 0 : 1] + ($this->rates[$id] ?? 0);
                }
                $result[] = $this->slot($id, $filter['date'], $from, $until, $total);
            }
        }
        usort($result, static fn($a, $b) => [$a['start'], $a['court']] <=> [$b['start'], $b['court']]);
        return $result;
    }

    public function selectionMatches(array $filter, array $selection): bool
    {
        if (!$this->validFilter($filter)) return false;
        $court = self::COURTS[$selection['court'] ?? ''] ?? null;
        $start = $selection['start'] ?? '';
        $blocks = $filter['blocks'] ?? 1;
        $duration = $blocks * self::BLOCK_MINUTES;
        return $court && $court['mode'] === $filter['mode'] && ($selection['mode'] ?? null) === $filter['mode']
            && ($selection['site'] ?? null) === 'rastras' && ($selection['date'] ?? null) === $filter['date']
            && ($selection['blocks'] ?? null) === $blocks && ($selection['duration'] ?? null) === $duration
            && preg_match('/^(?:[01][0-9]|2[0-3]):00$/D', $start)
            && ($selection['end'] ?? null) === $this->clock((int) $start * self::BLOCK_MINUTES + $duration);
    }

    public function quote(array $filter, string $court, string $start): ?array
    {
        foreach ($this->availability($filter) as $slot) {
            if ($slot['court'] === $court && $slot['start'] === $start) return $slot;
        }
        return null;
    }

    public function create(string $username, array $filter, array $selection, string $key): array
    {
        if (!$this->profile($username)) return ['error' => 'SESSION_EXPIRED'];
        foreach ($this->bookings as $booking) {
            if ($booking['owner'] === $username && ($booking['request'] ?? null) === $key) return ['booking' => $booking];
        }
        if (!$this->selectionMatches($filter, $selection)) {
            return ['error' => 'SELECTION_CHANGED'];
        }
        $scenario = $this->scenario;
        $this->scenario = '';
        if (in_array($scenario, ['UNAVAILABLE', 'SESSION_EXPIRED'], true)) return ['error' => $scenario];
        $slot = $this->quote($filter, $selection['court'], $selection['start']);
        if (!$slot) return ['error' => 'SLOT_TAKEN'];
        if ($scenario === 'SLOT_TAKEN') {
            $this->bookings['externa-' . $key] = $slot + ['owner' => '', 'status' => 'CONFIRMADA'];
            return ['error' => 'SLOT_TAKEN'];
        }
        if ($scenario === 'PRICE_CHANGED') {
            $this->rates[$slot['court']] = ($this->rates[$slot['court']] ?? 0) + 2000;
            $slot['total'] += 2000 * $slot['blocks'];
        }
        if ($slot['total'] !== $selection['total']) return ['error' => 'PRICE_CHANGED', 'quote' => $slot];
        $code = 'R-' . strtoupper(bin2hex(random_bytes(6)));
        $booking = $slot + ['code' => $code, 'owner' => $username, 'status' => 'PENDIENTE', 'request' => $key];
        $this->bookings[$code] = $booking;
        return ['booking' => $booking];
    }

    public function syncRequestReviews(array $reviews): void
    {
        foreach ($this->bookings as &$booking) {
            $review = $reviews[$booking['request'] ?? ''] ?? null;
            if ($review !== null) {
                $booking['status'] = $review['status'];
            }
        }
    }

    public function history(string $username): ?array
    {
        if (!$this->profile($username)) return null;
        $items = array_values(array_filter($this->bookings, static fn($booking) => $booking['owner'] === $username));
        usort($items, static fn($a, $b) => [$a['date'], $a['start']] <=> [$b['date'], $b['start']]);
        return $items;
    }

    public function detail(string $username, string $code): ?array
    {
        if (!$this->profile($username)) return null;
        return $this->receipt($username, $code);
    }

    public function receipt(string $username, string $code): ?array
    {
        $booking = $this->bookings[$code] ?? null;
        return $booking && $booking['owner'] === $username ? $booking : null;
    }

    public function canCancel(array $booking): bool
    {
        return in_array($booking['status'], ['PENDIENTE', 'CONFIRMADA'], true)
            && [$booking['date'], $booking['start']] > [$this->today, $this->time];
    }

    public function cancel(string $username, string $code): bool
    {
        $booking = $this->detail($username, $code);
        if (!$booking || !$this->canCancel($booking)) return false;
        $this->bookings[$code]['status'] = 'CANCELADA';
        return true;
    }

    public function useTournamentBlocks(array $tournaments): void
    {
        unset($this->bookings['TORNEO']);
        $this->sharedTournamentBlocks = [];
        foreach ($tournaments as $tournament) {
            if ($tournament['state'] === 'CANCELADO') continue;
            foreach ($tournament['blocks'] as $block) {
                $court = self::courtId($block['courtName'], $tournament['site']);
                if ($court !== null) {
                    $this->sharedTournamentBlocks[] = $block + ['court' => $court, 'status' => 'CONFIRMADA'];
                }
            }
        }
    }

    public function useRequestBlocks(array $requests): void
    {
        $this->sharedRequestBlocks = [];
        foreach ($requests as $request) {
            $court = $request['court'] ?? self::courtId($request['courtName'], self::siteName($request['site']));
            if ($court !== null) $this->sharedRequestBlocks[] = ['court' => $court] + $request;
        }
    }

    private static function courtId(string $name, string $site): ?string
    {
        if ($site !== self::SITES['rastras']) return null;
        if (in_array($name, ['Fútbol 5', 'Cancha Fútbol 5', 'Fútbol 7'], true)) return 'futbol-1';
        foreach (self::COURTS as $id => $court) {
            if ($name === $court['name']) return $id;
        }
        return null;
    }

    public static function namedCourtsShareSpace(string $first, string $second, string $site): bool
    {
        if ($first === $second) return true;
        $a = self::courtId($first, $site);
        $b = self::courtId($second, $site);
        return $a !== null && $b !== null && self::courtsShareSpace($a, $b);
    }

    private static function courtsShareSpace(string $a, string $b): bool
    {
        return $a === $b
            || ($a === 'futbol-grande' && in_array($b, self::FOOTBALL_COMPONENTS, true))
            || ($b === 'futbol-grande' && in_array($a, self::FOOTBALL_COMPONENTS, true));
    }

    private function overlaps(string $court, string $date, string $start, string $end): bool
    {
        foreach ([...$this->bookings, ...$this->sharedTournamentBlocks, ...$this->sharedRequestBlocks] as $booking) {
            if (self::courtsShareSpace($court, $booking['court']) && $booking['date'] === $date
                && $booking['status'] !== 'CANCELADA' && $booking['start'] < $end && $booking['end'] > $start) return true;
        }
        return false;
    }

    private function clock(int $minutes): string
    {
        return sprintf('%02d:%02d', intdiv($minutes, 60), $minutes % 60);
    }

    private function slot(string $id, string $date, string $start, string $end, int $total): array
    {
        $court = self::COURTS[$id];
        $blocks = (int) $end - (int) $start;
        return ['court' => $id, 'courtName' => $court['name'], 'mode' => $court['mode'],
            'modeLabel' => self::MODES[$court['mode']]['label'], 'site' => 'rastras', 'date' => $date,
            'start' => $start, 'end' => $end, 'total' => $total,
            'duration' => $blocks * self::BLOCK_MINUTES, 'blocks' => $blocks];
    }

    private function seed(string $code, string $owner, string $court, string $date, string $start, string $status): array
    {
        $end = $this->clock((int) substr($start, 0, 2) * 60 + 60);
        $rate = self::COURTS[$court]['rates'][$start < '18:00' ? 0 : 1];
        return $this->slot($court, $date, $start, $end, $rate) + ['code' => $code, 'owner' => $owner, 'status' => $status];
    }
}
