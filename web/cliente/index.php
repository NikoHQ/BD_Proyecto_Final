<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/auth.php';
authStart();

$cuenta = currentAccount();
if ($cuenta && $cuenta['ROL'] !== 'CLIENTE') {
    redirectTo('/dashboardadmin/');
}
$clienteId = (int) ($cuenta['PERSONAL'] ?? 0);
$clienteNombre = $cuenta['NOMBRE'] ?? '';
$csrf = csrfToken();
?>
<!doctype html>
<html lang="es-CL">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="csrf-token" content="<?= esc($csrf) ?>">
  <title>Portal de reservas · SGCD</title>
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/css/bootstrap.min.css">
  <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.13.1/font/bootstrap-icons.min.css">
  <link rel="stylesheet" href="/cliente/portal.css">
  <script defer src="/assets/js/data/api.js"></script>
  <script defer src="/cliente/portal.js"></script>
</head>
<body data-cliente="<?= $clienteId ?>" data-cliente-nombre="<?= esc($clienteNombre) ?>" data-autenticado="<?= $cuenta ? '1' : '0' ?>">
<a class="visually-hidden-focusable skip" href="#vista">Saltar al contenido</a>
<header class="site-header">
  <div class="shell header-inner">
    <a class="brand" href="#reservar"><span class="brand-mark"><i class="bi bi-calendar2-check" aria-hidden="true"></i></span><span><strong>SGCD</strong><small>Portal de reservas</small></span></a>
    <nav class="site-nav" aria-label="Principal">
      <a href="#reservar" data-seccion="reservar"><i class="bi bi-calendar3" aria-hidden="true"></i> Reservar cancha</a>
      <a href="#reservas" data-seccion="reservas"><i class="bi bi-ticket-perforated" aria-hidden="true"></i> Mis reservas</a>
      <a href="#torneos" data-seccion="torneos"><i class="bi bi-trophy" aria-hidden="true"></i> Torneos</a>
      <?php if ($cuenta): ?>
        <a href="#cuenta" data-seccion="cuenta"><i class="bi bi-person" aria-hidden="true"></i> Mi cuenta</a>
      <?php endif; ?>
    </nav>
    <?php if ($cuenta): ?>
      <a class="account small text-nowrap" href="#cuenta"><i class="bi bi-person-circle" aria-hidden="true"></i> <?= esc($clienteNombre) ?></a>
    <?php else: ?>
      <a class="account btn btn-outline-success btn-sm" href="/cliente/login.php"><i class="bi bi-person-circle" aria-hidden="true"></i> Iniciar sesión</a>
    <?php endif; ?>
  </div>
</header>

<main class="shell main">
  <div id="vista" aria-live="polite"></div>
</main>

</body>
</html>
