<?php
declare(strict_types=1);

function e(mixed $value): string { return htmlspecialchars((string) $value, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
function url(string $view = 'inicio', array $extra = []): string { return '/?' . http_build_query(['vista' => $view] + $extra); }
function input(string $key): string { return is_string($_POST[$key] ?? null) ? trim($_POST[$key]) : ''; }
function passwordInput(): string { return is_string($_POST['password'] ?? null) ? $_POST['password'] : ''; }
function icon(string $name): string { return '<i class="bi bi-' . e($name) . '" aria-hidden="true"></i>'; }
function money(int $value): string { return '$' . number_format($value, 0, ',', '.') . ' CLP'; }
function dateLabel(string $date): string {
    $day = new DateTimeImmutable($date);
    $weekdays = ['lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'];
    $months = ['enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio', 'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre'];
    return $weekdays[(int) $day->format('N') - 1] . ' ' . $day->format('j') . ' de ' .
        $months[(int) $day->format('n') - 1] . ' de ' . $day->format('Y');
}
function go(string $view, ?string $message = null, string $tone = 'warning', array $extra = []): never
{
    global $portal;
    $_SESSION['data'] = $portal->snapshot();
    if ($message !== null) $_SESSION['notice'] = [$tone, $message];
    header('Location: ' . url($view, $extra), true, 303);
    exit;
}
function csrf(): string { return '<input type="hidden" name="csrf" value="' . e($_SESSION['csrf']) . '">'; }
