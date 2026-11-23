<?php
declare(strict_types=1);

// Bandeja de demostración compartida por el portal y el panel del mismo PHP.
function portalInbox(?callable $update = null): array
{
    $path = sys_get_temp_dir() . '/sgcd-portal-inbox-' . hash('sha256', __DIR__) . '.json';
    $lock = fopen($path . '.lock', 'c');
    if ($lock === false) throw new RuntimeException('No se pudo abrir la bandeja de reservas.');

    try {
        if (!flock($lock, $update === null ? LOCK_SH : LOCK_EX)) {
            throw new RuntimeException('No se pudo bloquear la bandeja de reservas.');
        }
        $requests = [];
        if (is_file($path)) {
            $json = file_get_contents($path);
            if ($json === false) throw new RuntimeException('No se pudo leer la bandeja de reservas.');
            $requests = json_decode($json, true, flags: JSON_THROW_ON_ERROR);
        }
        if ($update === null || !$update($requests)) return $requests;

        $temporary = tempnam(dirname($path), 'sgcd-inbox-');
        if ($temporary === false) throw new RuntimeException('No se pudo guardar la bandeja de reservas.');
        try {
            $json = json_encode($requests, JSON_THROW_ON_ERROR);
            if (file_put_contents($temporary, $json) !== strlen($json) || !rename($temporary, $path)) {
                throw new RuntimeException('No se pudo guardar la bandeja de reservas.');
            }
        } finally {
            if (is_file($temporary)) unlink($temporary);
        }
        return $requests;
    } finally {
        fclose($lock);
    }
}

function recordPortalRequest(array &$requests, array $booking, string $customer): bool
{
    $key = $booking['request'];
    if (isset($requests[$key])) return false;
    $fields = ['code', 'court', 'courtName', 'site', 'mode', 'date', 'start', 'end', 'status', 'total'];
    $requests[$key] = array_intersect_key($booking, array_flip($fields)) + ['customer' => $customer];
    return true;
}

function publishPortalRequest(array $booking, string $customer): void
{
    portalInbox(static function (array &$requests) use ($booking, $customer): bool {
        return recordPortalRequest($requests, $booking, $customer);
    });
}

function submitPortalRequest(DemoPortal $portal, string $user, string $customer, array $filter, array $selection, string $key): array
{
    $result = [];
    portalInbox(static function (array &$requests) use ($portal, $user, $customer, $filter, $selection, $key, &$result): bool {
        $portal->syncRequestReviews($requests);
        $portal->useRequestBlocks($requests);
        $result = $portal->create($user, $filter, $selection, $key);
        return isset($result['booking']) && recordPortalRequest($requests, $result['booking'], $customer);
    });
    return $result;
}

function reviewPortalRequest(string $key, string $status, bool $pendingOnly = true): bool
{
    $changed = false;
    portalInbox(static function (array &$requests) use ($key, $status, $pendingOnly, &$changed): bool {
        $current = $requests[$key]['status'] ?? null;
        if ($current !== 'PENDIENTE' && ($pendingOnly || $current !== 'CONFIRMADA')) return false;
        $requests[$key]['status'] = $status;
        return $changed = true;
    });
    return $changed;
}
