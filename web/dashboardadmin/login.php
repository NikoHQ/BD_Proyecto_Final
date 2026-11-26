<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
authStart();
$recover = isset($_GET['recuperar']);
$error = '';
$login = '';
try {
    if (currentAccount()) redirectTo('./');
    if ($_SERVER['REQUEST_METHOD'] === 'POST' && !$recover) {
        checkCsrf();
        $login = checkedLogin();
        rateLimit('login', $login);
        $account = accountBy('login', $login);
        $matches = password_verify(post('password'), $account['CLAVE'] ?? DUMMY_PASSWORD_HASH);
        if (!$matches || !accountActive($account)) throw new DomainException('Usuario o contraseña incorrectos.');
        startAccount($account);
        redirectTo('./');
    }
} catch (DomainException $exception) {
    rollbackAccountWork();
    $error = $exception->getMessage();
} catch (Throwable $exception) {
    error_log('SGCD acceso: ' . $exception->getMessage());
    rollbackAccountWork();
    http_response_code(503);
    $error = 'El acceso no está disponible. Intenta nuevamente.';
}
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title><?= $recover ? 'Recuperar contraseña' : 'Iniciar sesión' ?> · SGCD</title>
  <?php require __DIR__ . '/../includes/styles.php'; ?>
</head>
<body class="login-page sgcd-login">
  <main class="login-box">
    <div class="text-center mb-3"><span class="brand-mark mx-auto mb-2"><i class="bi bi-activity" aria-hidden="true"></i></span><strong class="fs-3">SGCD</strong></div>
    <div class="card card-outline card-primary">
      <div class="card-body p-4">
        <h1 class="h4 mb-3"><?= $recover ? 'Recuperar contraseña' : 'Iniciar sesión' ?></h1>
        <?php if ($error): ?><p class="alert alert-danger" role="alert"><?= esc($error) ?></p><?php endif; ?>
        <?php if ($recover): ?>
          <p class="alert alert-info">Solicita el restablecimiento de tu contraseña a un administrador del recinto.</p>
        <?php else: ?>
        <form method="post" action="login.php">
          <?= csrfField() ?>
          <label class="form-label w-100">Usuario<input class="form-control" name="login" autocomplete="username" maxlength="50" value="<?= esc($login) ?>" required autofocus></label>
          <label class="form-label w-100">Contraseña<input class="form-control" type="password" name="password" autocomplete="current-password" maxlength="72" required></label>
          <button class="btn btn-accent w-100 mt-2">Entrar</button>
        </form>
        <?php endif; ?>
        <a class="d-inline-block mt-3" href="<?= $recover ? 'login.php' : 'login.php?recuperar=1' ?>"><?= $recover ? 'Volver al inicio de sesión' : 'Olvidé mi contraseña' ?></a>
      </div>
    </div>
  </main>
</body>
</html>
