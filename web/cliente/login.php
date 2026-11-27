<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
authStart();

$error = '';
$login = '';
try {
    $cuenta = currentAccount();
    if ($cuenta) redirectTo($cuenta['ROL'] === 'CLIENTE' ? '/cliente/' : '/dashboardadmin/');
    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        checkCsrf();
        $login = strtolower(trim(post('login')));
        if (!preg_match('/^[a-z0-9._-]{3,50}$/D', $login)) {
            throw new DomainException('Ingresa un nombre de usuario válido.');
        }
        rateLimit('cliente-login', $login);
        $cuenta = accountBy('login', $login);
        $coincide = password_verify(post('password'), $cuenta['CLAVE'] ?? DUMMY_PASSWORD_HASH);
        if (!$coincide || !accountActive($cuenta)) throw new DomainException('Usuario o contraseña incorrectos.');
        if ($cuenta['ROL'] !== 'CLIENTE') {
            throw new DomainException('Esa cuenta es del personal. Ingresa por el panel de administración.');
        }
        startAccount($cuenta);
        redirectTo('/cliente/');
    }
} catch (DomainException $excepcion) {
    rollbackAccountWork();
    $error = $excepcion->getMessage();
} catch (Throwable $excepcion) {
    error_log('SGCD portal acceso: ' . $excepcion->getMessage());
    rollbackAccountWork();
    http_response_code(503);
    $error = 'El acceso no está disponible. Intenta nuevamente.';
}
?>
<!doctype html>
<html lang="es-CL">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Iniciar sesión · SGCD</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.13.1/font/bootstrap-icons.min.css">
  <link rel="stylesheet" href="/cliente/portal.css">
</head>
<body>
<header class="site-header">
  <div class="shell header-inner">
    <a class="brand" href="/cliente/"><span class="brand-mark"><i class="bi bi-calendar2-check" aria-hidden="true"></i></span><span><strong>SGCD</strong><small>Portal de reservas</small></span></a>
    <a class="btn btn-outline-success account" href="/dashboardadmin/login.php"><i class="bi bi-shield-lock" aria-hidden="true"></i> Personal de la sucursal</a>
  </div>
</header>
<main class="shell main">
  <div class="narrow">
    <h1 class="h2">Iniciar sesión</h1>
    <p>Ingresa con tu cuenta de cliente para reservar canchas e inscribir equipos.</p>
    <?php if ($error): ?><p class="alert alert-danger" role="alert"><?= esc($error) ?></p><?php endif; ?>
    <form class="surface account-form" method="post" action="/cliente/login.php">
      <?= csrfField() ?>
      <label>Usuario<input class="form-control" name="login" autocomplete="username" maxlength="50" value="<?= esc($login) ?>" required autofocus></label>
      <label>Contraseña<input class="form-control" type="password" name="password" autocomplete="current-password" maxlength="72" required></label>
      <button class="btn btn-success mt-3">Entrar</button>
    </form>
    <p class="small mt-3">¿No tienes cuenta? Solicítala en recepción: la ficha del cliente se verifica en persona.</p>
  </div>
</main>
</body>
</html>
