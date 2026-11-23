<?php
declare(strict_types=1);

// Almacenamiento de demo compartido por el panel y el portal en esta instancia PHP.
const PORTAL_DURATION_OPTIONS = [30, 60, 90, 120, 150, 180];

function portalDurationPath(): string
{
    return sys_get_temp_dir() . '/sgcd-portal-durations-' . hash('sha256', __DIR__) . '.json';
}

function loadPortalDurations(?string $path = null): array
{
    $path ??= portalDurationPath();
    if (!is_file($path)) return [];
    $raw = @file_get_contents($path);
    $values = $raw === false ? null : json_decode($raw, true);
    return is_array($values) ? array_filter($values, static fn($value) => in_array($value, PORTAL_DURATION_OPTIONS, true)) : [];
}

function savePortalDurations(array $input, array $modes, ?string $path = null): void
{
    $values = [];
    foreach ($modes as $mode) {
        $value = $input[$mode] ?? null;
        if (!is_scalar($value) || !in_array((string) $value, array_map('strval', PORTAL_DURATION_OPTIONS), true)) {
            throw new InvalidArgumentException('Selecciona una duración válida para cada modalidad.');
        }
        $values[$mode] = (int) $value;
    }
    $path ??= portalDurationPath();
    $temporary = tempnam(dirname($path), 'sgcd-dur-');
    if ($temporary === false) throw new RuntimeException('No se pudo guardar la configuración.');
    try {
        $json = json_encode($values, JSON_THROW_ON_ERROR);
        if (file_put_contents($temporary, $json) !== strlen($json) || !rename($temporary, $path)) {
            throw new RuntimeException('No se pudo guardar la configuración.');
        }
    } finally {
        if (is_file($temporary)) unlink($temporary);
    }
}
