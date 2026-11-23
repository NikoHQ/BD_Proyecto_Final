<?php
declare(strict_types=1);

final class DemoPortal
{
    public const MODES = [
        'padel' => ['label' => 'Pádel dobles', 'players' => '2–4 personas', 'icon' => 'bullseye'],
        'futbol' => ['label' => 'Fútbol 5', 'players' => '5–10 personas', 'icon' => 'dribbble'],
        'voley' => ['label' => 'Vóleibol 6x6', 'players' => 'Hasta 12 personas', 'icon' => 'circle-half'],
    ];
    private const DEMO_RUTS = ['demo' => '30900001-3', 'nuevo' => '30900002-1'];
    public const SITES = ['rastras' => 'Las Rastras', 'parque' => 'Parque Sur'];
    private const COURTS = [
        'padel-1' => ['name' => 'Pádel 1', 'mode' => 'padel', 'site' => 'rastras', 'rates' => [16000, 18000]],
        'padel-2' => ['name' => 'Pádel 2', 'mode' => 'padel', 'site' => 'rastras', 'rates' => [16000, 17000]],
        'padel-3' => ['name' => 'Pádel 3', 'mode' => 'padel', 'site' => 'parque', 'rates' => [14000, 15000]],
        'futbol-1' => ['name' => 'Cancha Fútbol 5', 'mode' => 'futbol', 'site' => 'rastras', 'rates' => [18000, 22000]],
        'voley-1' => ['name' => 'Cancha Vóleibol', 'mode' => 'voley', 'site' => 'parque', 'rates' => [12000, 14000]],
    ];
    private array $bookings;
    private array $accounts;
    private array $rates;
    private array $sharedTournamentBlocks = [];
    public string $scenario = '';

    public function __construct(array $data, public readonly string $today, public readonly string $time,
        private readonly array $durations = [])
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
            'R-10452' => $this->seed('R-10452', 'demo', 'padel-3', $friday, '20:00', 'CONFIRMADA'),
            'R-10453' => $this->seed('R-10453', 'demo', 'padel-2', $friday, '20:00', 'PENDIENTE'),
            'R-10454' => $this->seed('R-10454', 'demo', 'padel-3', $day->modify('-2 days')->format('Y-m-d'), '18:00', 'CANCELADA'),
            'TORNEO' => $this->seed('TORNEO', '', 'padel-1', $friday, '16:00', 'CONFIRMADA'),
            'MANTENCION' => $this->seed('MANTENCION', '', 'padel-2', $friday, '16:00', 'MANTENCION'),
        ];
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

    public function validFilter(array $filter): bool
    {
        if (!preg_match('/^[0-9]{4}-[0-9]{2}-[0-9]{2}$/D', $filter['date'])) return false;
        $date = DateTimeImmutable::createFromFormat('!Y-m-d', $filter['date']);
        return $date && $date->format('Y-m-d') === $filter['date'] && $filter['date'] >= $this->today
            && isset(self::MODES[$filter['mode']])
            && ($filter['site'] === '' || isset(self::SITES[$filter['site']]));
    }

    public function durationFor(string $mode): int
    {
        return $this->durations[$mode] ?? 60;
    }

    public function availability(array $filter): array
    {
        if (!$this->validFilter($filter)) return [];
        $duration = $this->durationFor($filter['mode']);
        $day = (int) (new DateTimeImmutable($filter['date']))->format('N');
        $result = [];
        foreach (self::COURTS as $id => $court) {
            if ($court['mode'] !== $filter['mode'] || ($filter['site'] !== '' && $court['site'] !== $filter['site'])) continue;
            if ($day === 1 && $court['site'] === 'rastras') continue;
            $close = $day === 7 ? 20 * 60 : 22 * 60;
            for ($start = 16 * 60; $start + $duration <= $close; $start += 30) {
                $end = $start + $duration;
                $from = $this->clock($start);
                $until = $this->clock($end);
                if (($filter['date'] === $this->today && $from <= $this->time) ||
                    $this->overlaps($id, $filter['date'], $from, $until)) continue;
                $baseMinutes = max(0, min($end, 18 * 60) - $start);
                $rates = $court['rates'];
                $total = ($baseMinutes * $rates[0] + ($duration - $baseMinutes) * $rates[1]) / 60;
                $result[] = $this->slot($id, $filter['date'], $from, $until, (int) round($total) + ($this->rates[$id] ?? 0));
            }
        }
        usort($result, static fn($a, $b) => [$a['start'], $a['court']] <=> [$b['start'], $b['court']]);
        return $result;
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
        if ($this->awaitingFirstConfirmation($username)) return ['error' => 'FIRST_RESERVATION_PENDING'];
        if (($selection['duration'] ?? 60) !== $this->durationFor($filter['mode'])) {
            return ['error' => 'DURATION_CHANGED'];
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
            $slot['total'] += 2000;
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
                $booking['confirmed'] = $review['confirmed'];
            }
        }
    }

    public function awaitingFirstConfirmation(string $username): bool
    {
        $pending = false;
        foreach ($this->bookings as $booking) {
            if ($booking['owner'] !== $username) continue;
            if (!empty($booking['confirmed']) || in_array($booking['status'], ['CONFIRMADA', 'COMPLETADA'], true)) {
                return false;
            }
            $pending = $pending || $booking['status'] === 'PENDIENTE';
        }
        return $pending;
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
                foreach (self::COURTS as $id => $court) {
                    if (self::SITES[$court['site']] !== $tournament['site']) continue;
                    if ($block['courtName'] !== $court['name']
                        && !($id === 'futbol-1' && $block['courtName'] === 'Fútbol 5')) continue;
                    $this->sharedTournamentBlocks[] = $block + ['court' => $id, 'status' => 'CONFIRMADA'];
                }
            }
        }
    }

    private function overlaps(string $court, string $date, string $start, string $end): bool
    {
        foreach ([...$this->bookings, ...$this->sharedTournamentBlocks] as $booking) {
            if ($booking['court'] === $court && $booking['date'] === $date && $booking['status'] !== 'CANCELADA'
                && $booking['start'] < $end && $booking['end'] > $start) return true;
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
        return ['court' => $id, 'courtName' => $court['name'], 'mode' => $court['mode'], 'site' => $court['site'], 'date' => $date,
            'start' => $start, 'end' => $end, 'total' => $total,
            'duration' => (int) ((strtotime($end) - strtotime($start)) / 60)];
    }

    private function seed(string $code, string $owner, string $court, string $date, string $start, string $status): array
    {
        $end = $this->clock((int) substr($start, 0, 2) * 60 + 60);
        $rate = self::COURTS[$court]['rates'][$start < '18:00' ? 0 : 1];
        return $this->slot($court, $date, $start, $end, $rate) + ['code' => $code, 'owner' => $owner, 'status' => $status];
    }
}
