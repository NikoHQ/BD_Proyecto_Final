<?php if (in_array($view, ['acceso', 'registro'], true)): ?>
  <?php $register = $view === 'registro'; ?>
  <?php if ($showSelection): ?><p class="notice"><?= icon('info-circle') ?> Tu selección se conserva mientras ingresas. Comprobaremos el horario al regresar.</p><?php endif; ?>
  <?php if ($tournamentAccess): ?><p class="notice narrow mb-3"><?= icon('trophy') ?> Ingresa a tu cuenta para continuar con torneos.</p><?php endif; ?>
  <div class="<?= $showSelection ? 'split access-split' : 'narrow' ?>">
    <section class="surface">
      <h1><?= $register ? 'Crea tu cuenta' : 'Inicia sesión' ?><?= $showSelection || $tournamentAccess ? ' para continuar' : '' ?></h1>
      <p><?= $register ? 'Usa datos ficticios para probar el registro.' : 'Accede con una cuenta de cliente de demostración.' ?></p>
      <form method="post" class="account-form"><?= csrf() ?><input type="hidden" name="action" value="<?= $register ? 'register' : 'login' ?>">
        <?php if ($register): ?>
          <label for="nombre">Nombre completo</label><input id="nombre" name="name" class="form-control" maxlength="100" value="<?= e(input('name')) ?>" autocomplete="off" required>
          <label for="rut">RUT de prueba</label><input id="rut" name="rut" class="form-control" maxlength="16" placeholder="12.345.678-5" value="<?= e(input('rut')) ?>" autocomplete="off" required>
        <?php endif; ?>
        <label for="usuario">Usuario</label><input id="usuario" name="username" class="form-control" maxlength="30" autocomplete="username" value="<?= e($loginInput) ?>" required>
        <label for="clave">Contraseña</label><input type="password" id="clave" name="password" class="form-control" maxlength="72" minlength="8" autocomplete="<?= $register ? 'new-password' : 'current-password' ?>" required>
        <button class="btn btn-success w-100 mt-2"><?= $register ? 'Crear cuenta' : 'Iniciar sesión' ?><?= $showSelection || $tournamentAccess ? ' y continuar' : '' ?></button>
      </form>
      <?php if (!$register): ?>
        <p class="demo-access mt-3 mb-2">Usuario <code>demo</code> o <code>nuevo</code> · clave <code>SGCDdemo2026</code></p>
      <?php endif; ?>
      <div class="actions mt-3">
        <a class="btn btn-outline-success" href="<?= e(url($register ? 'acceso' : 'registro', $tournamentAccessQuery)) ?>"><?= $register ? 'Ya tengo una cuenta' : 'Crear cuenta' ?></a>
        <?php if ($tournamentAccess): ?>
          <a href="<?= e(isset($tournamentAccessQuery['torneo']) ? url('torneo', ['torneo' => $tournamentAccessQuery['torneo']]) : url('torneos')) ?>">Volver a torneos</a>
        <?php endif; ?>
        <?php if ($showSelection): ?><a href="<?= e(url('horarios')) ?>">Volver a los horarios</a><?php endif; ?>
      </div>
    </section>
    <?php if ($showSelection): ?><aside class="side"><?php summary($selection, 'Tu selección'); ?></aside><?php endif; ?>
  </div>
<?php elseif ($view === 'cuenta'): ?>
  <section class="surface narrow"><h1>Mi cuenta</h1><p class="fs-5"><?= e($profile['name']) ?></p>
    <div class="actions"><a class="btn btn-success" href="<?= e(url('reservas')) ?>">Mis reservas</a>
      <a class="btn btn-outline-success" href="<?= e(url('mis-inscripciones')) ?>">Mis inscripciones</a>
      <form method="post"><?= csrf() ?><input type="hidden" name="action" value="logout"><button class="btn btn-outline-success">Cerrar sesión</button></form></div>
  </section>
<?php endif; ?>
