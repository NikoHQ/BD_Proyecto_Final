<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';
authStart();
$account = requireAccount();
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

function staffRole(): string
{
    $role = post('role');
    if (!in_array($role, ['ADMINISTRADOR', 'OPERADOR'], true)) throw new DomainException('Selecciona un rol válido.');
    return $role;
}

function saveAccountProfile(array $account): void
{
    authQuery('UPDATE SGCD_ADMINISTRADORES SET NOMBRE_ADMINISTRADOR = :name WHERE ID_ADMINISTRADOR = :id',
        ['name' => accountName(), 'id' => $account['PERSONAL']]);
    if (!oci_commit(authDb())) throw new RuntimeException('No se pudo guardar el perfil.');
}

function saveStaff(array $account, string $action): void
{
    // Serializa cambios de roles para que dos administradores activos no puedan desactivarse entre sí.
    authQuery('LOCK TABLE SGCD_CREDENCIALES IN SHARE ROW EXCLUSIVE MODE');
    $actor = accountBy('id', (int) $account['ID']);
    if (!accountActive($actor) || $actor['ROL'] !== 'ADMINISTRADOR' ||
        !hash_equals($_SESSION['version'], hash('sha256', $actor['CLAVE']))) {
        throw new DomainException('Esta operación requiere una sesión de administrador activa.');
    }
    rateLimit('staff-confirm', $actor['USUARIO']);
    currentPasswordMatches($actor);
    $name = accountName();
    $role = staffRole();
    if ($action === 'create-staff') {
        $login = checkedLogin();
        $hash = newPasswordHash();
        authQuery('DECLARE
                      staff_id NUMBER;
                      credential_id NUMBER;
                   BEGIN
                      INSERT INTO SGCD_ADMINISTRADORES (NOMBRE_ADMINISTRADOR)
                        VALUES (:name) RETURNING ID_ADMINISTRADOR INTO staff_id;
                      SGCD_PKG_AUTH.crear_credencial(:login, :hash, :role, NULL, staff_id, credential_id);
                   END;', ['name' => $name, 'login' => $login, 'hash' => $hash, 'role' => $role]);
    } else {
        $target = accountBy('id', (int) post('id'), true);
        if (!$target || $target['ID'] === $actor['ID']) throw new DomainException('Edita tus datos desde Mi perfil.');
        $status = post('status');
        if (!in_array($status, ['ACTIVA', 'BLOQUEADA', 'INACTIVA'], true)) throw new DomainException('Selecciona un estado válido.');
        authQuery('UPDATE SGCD_ADMINISTRADORES SET NOMBRE_ADMINISTRADOR = :name WHERE ID_ADMINISTRADOR = :id',
            ['name' => $name, 'id' => $target['PERSONAL']]);
        authQuery('UPDATE SGCD_CREDENCIALES SET ROL_CREDENCIAL = :role, ESTADO_CREDENCIAL = :status WHERE ID_CREDENCIAL = :id',
            ['role' => $role, 'status' => $status, 'id' => $target['ID']]);
        if (post('password') !== '' || post('confirm') !== '') {
            $hash = newPasswordHash();
            authQuery('UPDATE SGCD_CREDENCIALES SET CLAVE_HASH_CREDENCIAL = :hash WHERE ID_CREDENCIAL = :id',
                ['hash' => $hash, 'id' => $target['ID']]);
        }
    }
    if (!oci_commit(authDb())) throw new RuntimeException('No se pudo guardar el usuario.');
}

$error = '';
$message = $_SESSION['account_message'] ?? '';
unset($_SESSION['account_message']);
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
        } elseif ($view === 'usuarios' && in_array($action, ['create-staff', 'edit-staff'], true)) {
            saveStaff($account, $action);
        } else {
            throw new DomainException('La operación no está disponible.');
        }
        $_SESSION['account_message'] = 'Cambios guardados.';
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

$staff = [];
$target = null;
try {
    if ($view === 'usuarios') {
        $stmt = authQuery("SELECT c.ID_CREDENCIAL AS ID, c.LOGIN_CREDENCIAL AS USUARIO, c.ROL_CREDENCIAL AS ROL,
                                  c.ESTADO_CREDENCIAL AS ESTADO, a.NOMBRE_ADMINISTRADOR AS NOMBRE
                           FROM SGCD_CREDENCIALES c JOIN SGCD_ADMINISTRADORES a
                             ON a.ID_ADMINISTRADOR = c.ID_ADMINISTRADOR
                           WHERE c.ROL_CREDENCIAL IN ('ADMINISTRADOR', 'OPERADOR') ORDER BY a.NOMBRE_ADMINISTRADOR");
        oci_fetch_all($stmt, $staff, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
        if (isset($_GET['editar']) && ctype_digit((string) $_GET['editar'])) {
            $candidate = accountBy('id', (int) $_GET['editar']);
            if ($candidate && $candidate['ID'] !== $account['ID']) $target = $candidate;
        }
    }
} catch (Throwable $exception) {
    error_log('SGCD cuenta: ' . $exception->getMessage());
    $error = 'No se pudieron cargar los datos de la cuenta.';
}

function currentPasswordField(): string
{
    return '<label class="form-label w-100">Tu contraseña actual<input class="form-control" type="password" name="current" autocomplete="current-password" maxlength="72" required></label>';
}
function roleName(string $role): string
{
    return $role === 'ADMINISTRADOR' ? 'Administrador' : 'Operador';
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
              <td><?php if ($row['ID'] !== $account['ID']): ?><a href="?vista=usuarios&amp;editar=<?= (int) $row['ID'] ?>#formulario">Editar</a><?php else: ?><span class="text-secondary">Tu cuenta</span><?php endif; ?></td>
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
              <?php foreach (['ACTIVA' => 'Activa', 'BLOQUEADA' => 'Bloqueada', 'INACTIVA' => 'Inactiva'] as $key => $label): ?>
                <option value="<?= $key ?>"<?= $key === $target['ESTADO'] ? ' selected' : '' ?>><?= $label ?></option>
              <?php endforeach; ?>
            </select></label>
          <?php else: ?>
            <label class="form-label w-100">Usuario<input class="form-control" name="login" maxlength="50" autocomplete="off" required></label>
          <?php endif; ?>
          <label class="form-label w-100">Rol<select class="form-select" name="role">
            <option value="OPERADOR">Operador</option>
            <option value="ADMINISTRADOR"<?= ($target['ROL'] ?? '') === 'ADMINISTRADOR' ? ' selected' : '' ?>>Administrador</option>
          </select></label>
          <?php if ($target): ?>
            <p class="form-text">Para restablecer la contraseña del usuario, rellena ambos campos.</p>
            <?= str_replace(' required', '', passwordFields()) ?>
          <?php else: ?><?= passwordFields() ?><?php endif; ?>
          <?= currentPasswordField() ?>
          <button class="btn btn-accent">Guardar usuario</button> <a class="btn btn-light" href="?vista=usuarios">Cancelar</a>
        </form>
      </div></section>
    <?php endif; ?>
  <?php endif; ?>
</main>
</body>
</html>
