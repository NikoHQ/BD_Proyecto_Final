<?php
function badge(string $status): string
{
    $labels = ['PENDIENTE' => 'Pendiente de confirmación', 'CONFIRMADA' => 'Confirmada', 'COMPLETADA' => 'Completada', 'CANCELADA' => 'Cancelada'];
    return '<span class="status ' . e(strtolower($status)) . '">' . e($labels[$status] ?? $status) . '</span>';
}

function summary(array $slot, string $title = 'Resumen de reserva'): void
{
    $items = [
        'bullseye' => ['Modalidad', DemoPortal::MODES[$slot['mode']]['label']],
        'geo-alt' => ['Recinto y cancha', DemoPortal::SITES[$slot['site']] . ' · ' . $slot['courtName']],
        'calendar3' => ['Fecha', dateLabel($slot['date'])],
        'clock' => ['Horario', $slot['start'] . '–' . $slot['end']],
        'hourglass-split' => ['Duración', ($slot['duration'] ?? (int) ((strtotime($slot['end']) - strtotime($slot['start'])) / 60)) . ' minutos'],
    ];
    ?>
    <section class="surface summary">
      <h2><?= e($title) ?></h2>
      <dl class="summary-data">
        <?php foreach ($items as $symbol => [$label, $value]): ?>
          <div><?= icon($symbol) ?><div><dt><?= e($label) ?></dt><dd><?= e($value) ?></dd></div></div>
        <?php endforeach; ?>
      </dl>
      <div class="summary-total"><span>Total</span><strong><?= e(money($slot['total'])) ?></strong></div>
    </section>
    <?php
}

$stage = match ($view) {
    'buscar' => 1, 'horarios' => 2, 'acceso', 'registro' => $showSelection ? 3 : null, 'revisar' => 4, default => null,
};
?>
<!doctype html>
<html lang="es-CL">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= e($titles[$view]) ?> · SGCD</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.13.1/font/bootstrap-icons.min.css">
  <link rel="stylesheet" href="/cliente/portal.css">
  <script src="/cliente/portal.js" defer></script>
</head>
<body>
<a class="visually-hidden-focusable skip" href="#contenido">Saltar al contenido</a>
<header class="site-header">
  <div class="shell header-inner">
    <a class="brand" href="<?= e(url()) ?>"><span class="brand-mark"><?= icon('calendar2-check') ?></span><span><strong>SGCD</strong><small>Portal de reservas</small></span></a>
    <nav class="site-nav" aria-label="Principal">
      <a href="<?= e(url()) ?>" <?= in_array($view, ['inicio','buscar','horarios','revisar','comprobante'], true) ? 'class="active"' : '' ?>><?= icon('calendar3') ?> Reservar cancha</a>
      <a href="<?= e(url('reservas')) ?>" <?= in_array($view, ['reservas','detalle'], true) ? 'class="active"' : '' ?>><?= icon('ticket-perforated') ?> Mis reservas</a>
      <a href="<?= e(url('torneos')) ?>" <?= in_array($view, TOURNAMENT_VIEWS, true) || $tournamentAccess ? 'aria-current="page" class="active"' : '' ?>><?= icon('trophy') ?> Torneos</a>
      <a href="<?= e(url('ayuda')) ?>" <?= $view === 'ayuda' ? 'class="active"' : '' ?>><?= icon('question-circle') ?> Ayuda</a>
    </nav>
    <a class="btn btn-outline-success account" href="<?= e($profile ? url('cuenta') : url('acceso', ['desde' => 'menu'])) ?>"><?= icon('person') ?> <?= $profile ? 'Mi cuenta' : 'Iniciar sesión' ?></a>
  </div>
</header>

<main id="contenido" class="shell main">
<?php if ($stage !== null): ?>
  <ol class="steps" aria-label="Progreso de la reserva">
    <?php foreach (['Buscar', 'Elegir horario', 'Acceso', 'Revisión'] as $i => $step): ?>
      <li <?= $stage === $i + 1 ? 'aria-current="step"' : '' ?> class="<?= $stage > $i + 1 ? 'done' : '' ?>"><span><?= $stage > $i + 1 ? icon('check-lg') : $i + 1 ?></span><?= e($step) ?></li>
    <?php endforeach; ?>
  </ol>
<?php endif; ?>
<?php if ($notice): ?><p role="status" class="alert alert-<?= e($notice[0]) ?>"><?= e($notice[1]) ?></p><?php endif; ?>
<?php foreach ($errors as $error): ?><p role="alert" class="alert alert-danger"><?= e($error) ?></p><?php endforeach; ?>

<?php
$template = match ($view) {
    'inicio', 'buscar', 'horarios' => 'buscar',
    'acceso', 'registro', 'cuenta' => 'cuenta',
    'revisar', 'comprobante', 'detalle', 'reservas' => 'reservas',
    'ayuda' => 'ayuda',
    default => 'torneos',
};
require __DIR__ . '/vistas/' . $template . '.php';
?>
</main>
<footer class="shell site-footer"><span>SGCD · Modo demostración</span><a href="<?= e(url('ayuda')) ?>">Ayuda</a></footer>
</body>
</html>
