<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/portal-inbox.php';
require_once __DIR__ . '/../cliente/demo.php';

authStart();
$account = requireStaff();
$canConfirm = $account['ROL'] === 'ADMINISTRADOR';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
    $status = match (post('action')) {
        'confirm' => 'CONFIRMADA',
        'cancel' => 'CANCELADA',
        default => '',
    };
    if ($status === 'CONFIRMADA' && !$canConfirm) {
        http_response_code(403);
        exit('Sólo un administrador puede confirmar la reserva.');
    }
    $key = post('request');
    $_SESSION['portal_review_notice'] = $status !== '' && preg_match('/^[a-f0-9]{32}$/D', $key)
        && reviewPortalRequest($key, $status)
        ? ['success', $status === 'CONFIRMADA' ? 'Reserva confirmada.' : 'Solicitud cancelada.']
        : ['warning', 'La solicitud ya fue resuelta o no está disponible.'];
    redirectTo('/dashboardadmin/solicitudes-web.php');
}

$notice = $_SESSION['portal_review_notice'] ?? null;
unset($_SESSION['portal_review_notice']);
$pending = array_filter(portalInbox(), static fn(array $request): bool => $request['status'] === 'PENDIENTE');
uasort($pending, static fn(array $a, array $b): int => [$a['date'], $a['start']] <=> [$b['date'], $b['start']]);
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Solicitudes web · SGCD</title>
  <?php require __DIR__ . '/../includes/styles.php'; ?>
</head>
<body>
<main class="container py-4">
  <a href="/dashboardadmin/#reservas">← Volver a Reservas</a>
  <h1 class="mt-2">Solicitudes web</h1>
  <p>Confirma o cancela las reservas pendientes del portal de clientes. Modo demostración.</p>
  <?php if ($notice): ?><p class="alert alert-<?= esc($notice[0]) ?>" role="status"><?= esc($notice[1]) ?></p><?php endif; ?>
  <section class="card">
    <?php if (!$pending): ?><p class="card-body mb-0">No hay solicitudes web pendientes.</p>
    <?php else: ?><div class="table-responsive">
      <table class="table align-middle mb-0">
        <thead><tr><th>Código</th><th>Cliente</th><th>Cancha</th><th>Horario</th><th>Acciones</th></tr></thead>
        <tbody>
          <?php foreach ($pending as $key => $request): ?>
            <tr>
              <th scope="row"><?= esc($request['code']) ?></th>
              <td><?= esc($request['customer']) ?></td>
              <td><?= esc($request['courtName']) ?> · <?= esc(DemoPortal::siteName($request['site'])) ?></td>
              <td><?= esc($request['date']) ?> · <?= esc($request['start'] . '–' . $request['end']) ?></td>
              <td><form class="d-flex flex-wrap gap-2" method="post">
                <?= csrfField() ?><input type="hidden" name="request" value="<?= esc($key) ?>">
                <?php if ($canConfirm): ?><button class="btn btn-accent btn-sm" name="action" value="confirm">Confirmar reserva</button><?php endif; ?>
                <button class="btn btn-outline-danger btn-sm" name="action" value="cancel">Cancelar solicitud</button>
              </form></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div><?php endif; ?>
  </section>
</main>
</body>
</html>
