<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
require_once __DIR__ . '/../includes/portal-duration.php';
require_once __DIR__ . '/../cliente/demo.php';
authStart();
$account = requireAccount();
if ($account['ROL'] !== 'ADMINISTRADOR') {
    http_response_code(403);
    exit('Esta sección requiere el rol Administrador.');
}
$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
    try {
        savePortalDurations(is_array($_POST['durations'] ?? null) ? $_POST['durations'] : [], array_keys(DemoPortal::MODES));
        $_SESSION['portal_duration_saved'] = true;
        redirectTo('/dashboardadmin/duraciones.php');
    } catch (InvalidArgumentException|RuntimeException $exception) {
        $error = $exception->getMessage();
    }
}
$saved = !empty($_SESSION['portal_duration_saved']);
unset($_SESSION['portal_duration_saved']);
$durations = loadPortalDurations();
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Duración de reservas · SGCD</title>
  <?php require __DIR__ . '/../includes/styles.php'; ?>
</head>
<body>
<main class="container py-4 account-workspace">
  <a href="/dashboardadmin/">← Volver al panel</a>
  <h1 class="mt-2">Duración de reservas</h1>
  <p>Fija la duración de las nuevas reservas web para cada modalidad.</p>
  <?php if ($saved): ?><p class="alert alert-success" role="status">Duraciones guardadas.</p><?php endif; ?>
  <?php if ($error): ?><p class="alert alert-danger" role="alert"><?= esc($error) ?></p><?php endif; ?>
  <section class="card"><div class="card-body">
    <form method="post">
      <?= csrfField() ?>
      <?php foreach (DemoPortal::MODES as $key => $mode): ?>
        <label class="form-label w-100"><?= esc($mode['label']) ?>
          <select class="form-select" name="durations[<?= esc($key) ?>]">
            <?php foreach (PORTAL_DURATION_OPTIONS as $minutes): ?>
              <option value="<?= $minutes ?>" <?= ($durations[$key] ?? 60) === $minutes ? 'selected' : '' ?>><?= $minutes ?> minutos</option>
            <?php endforeach; ?>
          </select>
        </label>
      <?php endforeach; ?>
      <button class="btn btn-accent">Guardar duraciones</button>
    </form>
  </div></section>
</main>
</body>
</html>
