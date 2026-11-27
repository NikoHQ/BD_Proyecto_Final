<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
authStart();
$account = requireStaff();
$view = $_GET['vista'] ?? 'perfil';
if (!in_array($view, ['perfil', 'seguridad', 'usuarios'], true)) $view = 'perfil';
if ($view === 'usuarios' && $account['ROL'] !== 'ADMINISTRADOR') {
    http_response_code(403);
    exit('Esta sección requiere el rol Administrador.');
}

function currentPasswordMatches(array $account): void
{
    if (!password_verify(post('current'), $account['CLAVE'])) throw new DomainException('La contraseña actual es incorrecta.');
}

function accountName(): string
{
    $name = trim(post('name'));
    if (!$name || strlen($name) > 100) throw new DomainException('Ingresa un nombre de hasta 100 bytes.');
    return $name;
}

function saveAccountProfile(array $account): void
{
    authQuery('BEGIN SGCD_ACTUALIZAR_ADMINISTRADOR(:id, :name, :estado); END;',
        ['name' => accountName(), 'id' => $account['PERSONAL'], 'estado' => $account['ESTADO_PERSONAL']]);
    if (!oci_commit(authDb())) throw new RuntimeException('No se pudo guardar el perfil.');
}

function listarAdministradores(): array
{
    $conexion = authDb();
    $sentencia = oci_parse($conexion, 'BEGIN SGCD_LISTAR_ADMINISTRADORES(:cursor); END;');
    if (!$sentencia) throw new RuntimeException('No se pudo preparar el listado de administradores.');
    $cursor = oci_new_cursor($conexion);
    oci_bind_by_name($sentencia, ':cursor', $cursor, -1, SQLT_RSET);
    if (!@oci_execute($sentencia, OCI_NO_AUTO_COMMIT) || !@oci_execute($cursor, OCI_NO_AUTO_COMMIT)) {
        oci_rollback($conexion);
        oci_free_statement($cursor);
        oci_free_statement($sentencia);
        throw new RuntimeException('No se pudo cargar el listado de administradores.');
    }
    $filas = [];
    oci_fetch_all($cursor, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    oci_free_statement($cursor);
    oci_free_statement($sentencia);
    return array_map(static fn(array $fila): array => [
        'ID' => (int) $fila['ID_USUARIO'],
        'PERSONAL' => (int) $fila['ID_ADMINISTRADOR'],
        'USUARIO' => $fila['LOGIN'],
        'ROL' => 'ADMINISTRADOR',
        'ESTADO' => $fila['ESTADO_ADMINISTRADOR'] === 'ACTIVO' ? 'ACTIVA' : 'INACTIVA',
        'NOMBRE' => $fila['NOMBRE_ADMINISTRADOR'],
    ], $filas);
}

function saveStaff(array $account, string $action): void
{
    // Serializa cambios de usuarios para que dos administradores activos no puedan desactivarse entre sí.
    authQuery('LOCK TABLE SGCD_USUARIOS IN SHARE ROW EXCLUSIVE MODE');
    $actor = accountBy('id', (int) $account['ID']);
    if (!accountActive($actor) || $actor['ROL'] !== 'ADMINISTRADOR' ||
        !hash_equals($_SESSION['version'], hash('sha256', $actor['CLAVE']))) {
        throw new DomainException('Esta operación requiere una sesión de administrador activa.');
    }
    rateLimit('staff-confirm', $actor['USUARIO']);
    currentPasswordMatches($actor);
    if ($action === 'create-staff') {
        $name = accountName();
        $login = checkedLogin();
        $hash = newPasswordHash();
        authQuery('DECLARE
                      user_id  NUMBER;
                      staff_id NUMBER;
                   BEGIN
                      SGCD_PKG_AUTH.crear_usuario(:login, :hash, :role, user_id);
                      SGCD_CREAR_ADMINISTRADOR(user_id, :name, :estado, staff_id);
                   END;',
            ['name' => $name, 'login' => $login, 'hash' => $hash,
             'role' => 'ADMINISTRADOR', 'estado' => 'ACTIVO']);
    } else {
        $target = null;
        foreach (listarAdministradores() as $administrador) {
            if ($administrador['ID'] === (int) post('id')) $target = $administrador;
        }
        if (!$target || $target['ID'] === $actor['ID']) throw new DomainException('No puedes editar ni eliminar tu propia cuenta desde esta sección.');
        if ($action === 'delete-staff') {
            authQuery('BEGIN SGCD_BORRAR_ADMINISTRADOR(:id); END;', ['id' => $target['PERSONAL']]);
            authQuery('BEGIN SGCD_PKG_AUTH.cambiar_estado(:id, :estado); END;',
                ['id' => $target['ID'], 'estado' => 'INACTIVO']);
            if (!oci_commit(authDb())) throw new RuntimeException('No se pudo eliminar el administrador.');
            return;
        }
        $status = post('status');
        if (!in_array($status, ['ACTIVA', 'INACTIVA'], true)) throw new DomainException('Selecciona un estado válido.');
        $name = accountName();
        $estado = $status === 'ACTIVA' ? 'ACTIVO' : 'INACTIVO';
        authQuery('BEGIN SGCD_ACTUALIZAR_ADMINISTRADOR(:id, :name, :estado); END;',
            ['id' => $target['PERSONAL'], 'name' => $name, 'estado' => $estado]);
        authQuery('BEGIN SGCD_PKG_AUTH.cambiar_estado(:id, :estado); END;',
            ['id' => $target['ID'], 'estado' => $estado]);
        if (post('password') !== '' || post('confirm') !== '') {
            $hash = newPasswordHash();
            authQuery('BEGIN SGCD_PKG_AUTH.cambiar_clave(:id, :hash); END;',
                ['id' => $target['ID'], 'hash' => $hash]);
        }
    }
    if (!oci_commit(authDb())) throw new RuntimeException('No se pudo guardar el usuario.');
}

$error = '';
$message = $_SESSION['account_message'] ?? '';
unset($_SESSION['account_message']);
$staff = [];
$target = null;
$deleteTarget = null;
if ($view === 'usuarios') {
    try {
        $staff = listarAdministradores();
        if (isset($_GET['editar']) && ctype_digit((string) $_GET['editar'])) {
            foreach ($staff as $row) if ($row['ID'] === (int) $_GET['editar'] && $row['ID'] !== $account['ID']) $target = $row;
        }
        if (isset($_GET['eliminar']) && ctype_digit((string) $_GET['eliminar'])) {
            foreach ($staff as $row) if ($row['ID'] === (int) $_GET['eliminar'] && $row['ID'] !== $account['ID']) $deleteTarget = $row;
        }
    } catch (Throwable $exception) {
        error_log('SGCD cuenta: ' . $exception->getMessage());
        $error = 'No se pudieron cargar los datos de los administradores.';
    }
}
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
    try {
        $action = post('action');
        if ($view === 'perfil' && $action === 'profile') {
            saveAccountProfile($account);
        } elseif ($view === 'seguridad' && $action === 'password') {
            rateLimit('settings-confirm', $account['USUARIO']);
            $locked = accountBy('id', (int) $account['ID'], true);
            if (!accountActive($locked) || !hash_equals($_SESSION['version'], hash('sha256', $locked['CLAVE']))) {
                throw new DomainException('Vuelve a iniciar sesión.');
            }
            $account = $locked;
            currentPasswordMatches($account);
            $hash = newPasswordHash();
            changeAccountPassword($account, $hash);
            startAccount(array_replace($account, ['CLAVE' => $hash]));
        } elseif ($view === 'usuarios' && in_array($action, ['create-staff', 'edit-staff', 'delete-staff'], true)) {
            saveStaff($account, $action);
        } else {
            throw new DomainException('La operación no está disponible.');
        }
        $_SESSION['account_message'] = $action === 'delete-staff'
            ? 'Administrador eliminado y acceso desactivado.' : 'Cambios guardados.';
        redirectTo('account.php?vista=' . $view);
    } catch (DomainException $exception) {
        rollbackAccountWork();
        $error = $exception->getMessage();
    } catch (Throwable $exception) {
        error_log('SGCD cuenta: ' . $exception->getMessage());
        rollbackAccountWork();
        $error = 'No se pudieron guardar los cambios. Intenta nuevamente.';
    }
}

function currentPasswordField(): string
{
    return '<label class="form-label w-100">Tu contraseña actual<input class="form-control" type="password" name="current" autocomplete="current-password" maxlength="72" required></label>';
}
function roleName(string $role): string
{
    return $role === 'ADMINISTRADOR' ? 'Administrador' : 'Cliente';
}
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Configuración de cuenta · SGCD</title>
  <?php require __DIR__ . '/../includes/styles.php'; ?>
</head>
<body>
<main class="container py-4 account-workspace">
  <header class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-3">
    <div><a href="./">← Volver al panel</a><h1 class="mt-2">Configuración de cuenta</h1></div>
    <form method="post" action="/dashboardadmin/logout.php"><?= csrfField() ?><button class="btn btn-outline-secondary">Cerrar sesión</button></form>
  </header>
  <nav class="nav nav-tabs mb-3" aria-label="Cuenta">
    <?php foreach (['perfil' => 'Mi perfil', 'seguridad' => 'Seguridad', 'usuarios' => 'Usuarios del personal'] as $key => $label): ?>
      <?php if ($key === 'usuarios' && $account['ROL'] !== 'ADMINISTRADOR') continue; ?>
      <a class="nav-link<?= $view === $key ? ' active' : '' ?>" href="/dashboardadmin/account.php?vista=<?= $key ?>"<?= $view === $key ? ' aria-current="page"' : '' ?>><?= $label ?></a>
    <?php endforeach; ?>
  </nav>
  <?php if ($error): ?><p class="alert alert-danger" role="alert"><?= esc($error) ?></p><?php endif; ?>
  <?php if ($message): ?><p class="alert alert-success" role="status"><?= esc($message) ?></p><?php endif; ?>
  <?php if ($view === 'perfil'): ?>
    <section class="card"><div class="card-body">
      <h2 class="h5">Datos de la cuenta</h2>
      <p><?= esc($account['USUARIO']) ?> · <?= roleName($account['ROL']) ?></p>
      <form method="post">
        <?= csrfField() ?><input type="hidden" name="action" value="profile">
        <label class="form-label w-100">Nombre<input class="form-control" name="name" value="<?= esc($account['NOMBRE']) ?>" maxlength="100" required></label>
        <button class="btn btn-accent">Guardar perfil</button>
      </form>
    </div></section>
  <?php elseif ($view === 'seguridad'): ?>
    <div class="row g-3">
      <section class="col-12 col-lg-6"><div class="card"><div class="card-body">
        <h2 class="h5">Cambiar contraseña</h2>
        <form method="post">
          <?= csrfField() ?><input type="hidden" name="action" value="password">
          <?= currentPasswordField(), passwordFields() ?>
          <button class="btn btn-accent">Cambiar contraseña</button>
        </form>
      </div></div></section>
      <section class="col-12 col-lg-6"><div class="card"><div class="card-body">
        <h2 class="h5">Preguntas de seguridad</h2>
        <p class="form-text mb-0">La configuración de preguntas para recuperar la contraseña está pendiente de integración.</p>
      </div></div></section>
    </div>
  <?php else: ?>
    <section class="card"><div class="card-body">
      <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mb-2"><h2 class="h5 mb-0">Usuarios del personal</h2>
        <a class="btn btn-accent btn-sm" href="?vista=usuarios&amp;nuevo=1#formulario">Nuevo usuario</a>
      </div>
      <div class="table-responsive"><table class="table align-middle mb-0">
        <thead><tr><th>Nombre</th><th>Usuario</th><th>Rol</th><th>Estado</th><th>Acciones</th></tr></thead>
        <tbody>
          <?php foreach ($staff as $row): ?>
            <tr><td><?= esc($row['NOMBRE']) ?></td><td><?= esc($row['USUARIO']) ?></td><td><?= roleName($row['ROL']) ?></td>
              <td><span class="status <?= $row['ESTADO'] === 'ACTIVA' ? 'completed' : 'cancelled' ?>"><?= esc($row['ESTADO']) ?></span></td>
              <td><?php if ($row['ID'] !== $account['ID']): ?>
                <a href="?vista=usuarios&amp;editar=<?= (int) $row['ID'] ?>#formulario">Editar</a>
                · <a href="?vista=usuarios&amp;eliminar=<?= (int) $row['ID'] ?>#formulario-eliminar">Eliminar</a>
              <?php else: ?><span class="text-secondary">Tu cuenta</span><?php endif; ?></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table></div>
    </div></section>
    <?php if ($target || isset($_GET['nuevo'])): ?>
      <section class="card mt-3" id="formulario"><div class="card-body">
        <h2 class="h5"><?= $target ? 'Editar ' . esc($target['USUARIO']) : 'Nuevo usuario' ?></h2>
        <form method="post">
          <?= csrfField() ?><input type="hidden" name="action" value="<?= $target ? 'edit-staff' : 'create-staff' ?>">
          <label class="form-label w-100">Nombre<input class="form-control" name="name" value="<?= esc($target['NOMBRE'] ?? '') ?>" maxlength="100" required></label>
          <?php if ($target): ?>
            <input type="hidden" name="id" value="<?= (int) $target['ID'] ?>">
            <label class="form-label w-100">Estado<select class="form-select" name="status">
              <?php foreach (['ACTIVA' => 'Activa', 'INACTIVA' => 'Inactiva'] as $key => $label): ?>
                <option value="<?= $key ?>"<?= $key === $target['ESTADO'] ? ' selected' : '' ?>><?= $label ?></option>
              <?php endforeach; ?>
            </select></label>
          <?php else: ?>
            <label class="form-label w-100">Usuario<input class="form-control" name="login" maxlength="50" autocomplete="off" required></label>
          <?php endif; ?>
          <?php if ($target): ?>
            <p class="form-text">Para restablecer la contraseña del usuario, rellena ambos campos.</p>
            <?= str_replace(' required', '', passwordFields()) ?>
          <?php else: ?><?= passwordFields() ?><?php endif; ?>
          <?= currentPasswordField() ?>
          <button class="btn btn-accent">Guardar usuario</button> <a class="btn btn-light" href="?vista=usuarios">Cancelar</a>
        </form>
      </div></section>
    <?php endif; ?>
    <?php if ($deleteTarget): ?>
      <section class="card mt-3" id="formulario-eliminar"><div class="card-body">
        <h2 class="h5">Eliminar <?= esc($deleteTarget['NOMBRE']) ?></h2>
        <p>Se eliminará su ficha de administrador y se desactivará su acceso. Si tiene reservas asociadas, Oracle rechazará la eliminación.</p>
        <form method="post">
          <?= csrfField() ?><input type="hidden" name="action" value="delete-staff">
          <input type="hidden" name="id" value="<?= (int) $deleteTarget['ID'] ?>">
          <?= currentPasswordField() ?>
          <button class="btn btn-danger">Confirmar eliminación</button>
          <a class="btn btn-light" href="?vista=usuarios">Cancelar</a>
        </form>
      </div></section>
    <?php endif; ?>
  <?php endif; ?>
</main>
</body>
</html>
