<?php
declare(strict_types=1);
require_once __DIR__ . '/includes/auth.php';
authStart();
$account = requireAccount();
preg_match_all('/(?:^|\s)(\p{L})/u', $account['NOMBRE'], $initials);
$avatar = strtoupper(implode('', array_slice($initials[1], 0, 2))) ?: 'SG';
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>SGCD · Administración</title>
  <?php require __DIR__ . '/includes/styles.php'; ?>
  <link rel="stylesheet" href="assets/css/agenda.css">
  <link rel="stylesheet" href="assets/css/listas.css">
  <link rel="stylesheet" href="assets/css/torneos.css">
  <script defer src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.8/dist/js/bootstrap.bundle.min.js"></script>
  <script defer src="https://cdn.jsdelivr.net/npm/admin-lte@4.0.0/dist/js/adminlte.min.js"></script>
  <?php foreach ([
      'shared/format', 'shared/components', 'demo/fixtures', 'demo/store',
      'shared/list-view', 'pages/agenda', 'pages/reservas', 'pages/clientes', 'pages/pagos',
      'pages/recintos', 'pages/tarifas', 'pages/torneos', 'shared/search', 'app',
  ] as $script): ?>
    <script defer src="assets/js/<?= $script ?>.js"></script>
  <?php endforeach; ?>
</head>
<body class="sidebar-expand-lg layout-fixed" data-account-role="<?= esc($account['ROL']) ?>">
<div class="app-wrapper">
  <header class="app-header navbar bg-white">
    <div class="container-fluid px-3 gap-3">
      <button class="btn" data-lte-toggle="sidebar" aria-label="Mostrar u ocultar menú"><i class="bi bi-list fs-5"></i></button>
      <nav class="panel-breadcrumb small" aria-label="Ruta de navegación">
        <ol class="breadcrumb mb-0" id="current-section"><li class="breadcrumb-item active" aria-current="page">Agenda</li></ol>
      </nav>
      <button class="btn header-search ms-auto" data-action="search" aria-label="Buscar reserva o cliente"><i class="bi bi-search" aria-hidden="true"></i> <span class="d-none d-sm-inline">Buscar reserva o cliente</span></button>
      <div class="nav-item dropdown">
        <button type="button" class="btn p-0 d-flex align-items-center gap-2" data-bs-toggle="dropdown" aria-expanded="false" aria-label="Menú de usuario">
          <span class="avatar"><?= esc($avatar) ?></span><i class="bi bi-chevron-down small" aria-hidden="true"></i>
        </button>
        <ul class="dropdown-menu dropdown-menu-end account-menu shadow">
          <li class="px-3 py-2"><strong class="d-block"><?= esc($account['NOMBRE']) ?></strong>
            <small class="text-secondary"><?= $account['ROL'] === 'ADMINISTRADOR' ? 'Administrador' : 'Operador' ?></small></li>
          <li><hr class="dropdown-divider"></li>
          <li><a class="dropdown-item" href="account.php"><i class="bi bi-person me-2" aria-hidden="true"></i>Mi perfil</a></li>
          <li><a class="dropdown-item" href="account.php?vista=seguridad"><i class="bi bi-gear me-2" aria-hidden="true"></i>Configuración y seguridad</a></li>
          <?php if ($account['ROL'] === 'ADMINISTRADOR'): ?>
            <li><a class="dropdown-item" href="account.php?vista=usuarios"><i class="bi bi-people me-2" aria-hidden="true"></i>Usuarios del personal</a></li>
          <?php endif; ?>
          <li><hr class="dropdown-divider"></li>
          <li><form method="post" action="logout.php"><?= csrfField() ?>
            <button class="dropdown-item text-danger"><i class="bi bi-box-arrow-right me-2" aria-hidden="true"></i>Cerrar sesión</button>
          </form></li>
        </ul>
      </div>
    </div>
  </header>
  <aside class="app-sidebar" data-bs-theme="dark">
    <div class="sidebar-brand">
      <a href="#agenda" class="brand-link"><span class="brand-mark"><i class="bi bi-activity"></i></span><span><strong>SGCD</strong><small>Centros deportivos</small></span></a>
    </div>
    <div class="sidebar-wrapper">
      <nav class="mt-3" aria-label="Menú principal"><ul id="menu" class="nav sidebar-menu flex-column"></ul></nav>
      <div class="side-foot"><i class="bi bi-circle-fill me-1"></i> Modo demostración</div>
    </div>
  </aside>
  <main class="app-main"><div class="app-content"><div class="container-fluid workspace" id="screen"></div></div></main>
</div>
<div class="modal" id="dialog" tabindex="-1" aria-labelledby="dialog-title" aria-hidden="true">
  <div class="modal-dialog modal-dialog-centered modal-dialog-scrollable">
    <div class="modal-content">
      <div class="modal-header"><h2 class="modal-title fs-5" id="dialog-title"></h2><button class="btn-close" data-bs-dismiss="modal" aria-label="Cerrar"></button></div>
      <div class="modal-body" id="dialog-body"></div>
    </div>
  </div>
</div>
<div id="notice" class="toast-container position-fixed bottom-0 end-0 p-3" role="status" aria-live="polite"></div>
</body>
</html>
