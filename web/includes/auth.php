<?php
declare(strict_types=1);

const DUMMY_PASSWORD_HASH = '$2y$12$K9jB5X2EHPjF9LC1fTdJdOc3SMHziE1S4gN.9hYEEn3ffnBDhzLpG';

function authStart(): void
{
    ini_set('session.use_strict_mode', '1');
    session_name('sgcd_session');
    session_set_cookie_params([
        'path' => '/', 'httponly' => true, 'samesite' => 'Lax',
        'secure' => !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off',
    ]);
    session_start();
    header('Cache-Control: no-store');
}

function authDb(): mixed
{
    static $connection;
    if (!$connection) {
        $service = '//' . getenv('SGCD_DB_HOST') . ':' . getenv('SGCD_DB_PORT') . '/' . getenv('SGCD_DB_SERVICE');
        $connection = @oci_connect(getenv('SGCD_DB_USER'), getenv('SGCD_DB_PASSWORD'), $service, 'AL32UTF8');
        if (!$connection) throw new RuntimeException('Oracle no está disponible.');
        // Las fechas viajan como 'YYYY-MM-DD HH24:MI:SS' y se pueden bindear tal cual.
        $ajuste = oci_parse($connection, "ALTER SESSION SET NLS_DATE_FORMAT = 'YYYY-MM-DD HH24:MI:SS'");
        if ($ajuste) oci_execute($ajuste);
    }
    return $connection;
}

function authQuery(string $sql, array $params = []): mixed
{
    $statement = oci_parse(authDb(), $sql);
    if (!$statement) throw new RuntimeException('No se pudo preparar la consulta.');
    foreach ($params as $name => &$value) {
        oci_bind_by_name($statement, ':' . $name, $value);
    }
    unset($value);
    if (!@oci_execute($statement, OCI_NO_AUTO_COMMIT)) {
        $error = oci_error($statement);
        if (in_array($error['code'] ?? 0, [1, 20018], true)) throw new DomainException('El usuario ya existe.');
        throw new RuntimeException('No se pudo completar la operación en Oracle.');
    }
    return $statement;
}

function authRow(string $sql, array $params = []): ?array
{
    $stmt = authQuery($sql, $params);
    $row = oci_fetch_assoc($stmt);
    oci_free_statement($stmt);
    return $row ?: null;
}

/**
 * Cuenta del modelo de 19 tablas: SGCD_USUARIOS guarda el acceso y la ficha
 * cuelga por ID_USUARIO, ya sea administrador o cliente. El arreglo mantiene
 * las llaves que usan las pantallas (ID, USUARIO, CLAVE, ROL, PERSONAL...)
 * para no tocar cada pagina al cambiar el esquema.
 */
function accountBy(string $field, string|int $value, bool $lock = false): ?array
{
    $column = $field === 'login' ? 'u.LOGIN' : 'u.ID_USUARIO';
    return authRow("SELECT u.ID_USUARIO AS ID, u.LOGIN AS USUARIO,
                           u.CLAVE_HASH AS CLAVE, u.ROL AS ROL,
                           CASE u.ESTADO_USUARIO WHEN 'ACTIVO' THEN 'ACTIVA' ELSE 'INACTIVA' END AS ESTADO,
                           COALESCE(a.ID_ADMINISTRADOR, c.ID_CLIENTE) AS PERSONAL,
                           COALESCE(a.NOMBRE_ADMINISTRADOR, c.NOMBRE_CLIENTE, u.LOGIN) AS NOMBRE,
                           CASE WHEN a.ID_ADMINISTRADOR IS NOT NULL THEN a.ESTADO_ADMINISTRADOR
                                WHEN c.ID_CLIENTE IS NOT NULL THEN c.ESTADO_CLIENTE
                                ELSE 'ACTIVO' END AS ESTADO_PERSONAL
                    FROM SGCD_USUARIOS u
                    LEFT JOIN SGCD_ADMINISTRADORES a ON a.ID_USUARIO = u.ID_USUARIO
                    LEFT JOIN SGCD_CLIENTES c ON c.ID_USUARIO = u.ID_USUARIO
                    WHERE $column = :value" .
                    ($lock ? ' FOR UPDATE OF u.CLAVE_HASH' : ''), ['value' => $value]);
}

function accountActive(?array $account): bool
{
    return $account && $account['ESTADO'] === 'ACTIVA' && $account['ESTADO_PERSONAL'] === 'ACTIVO';
}

function startAccount(array $account): void
{
    // El token del formulario de acceso sobrevive al cambio de sesion: el
    // navegador lo necesita para la primera mutacion despues del login.
    $csrf = $_SESSION['csrf'] ?? null;
    session_regenerate_id(true);
    $_SESSION = [
        'account' => (int) $account['ID'],
        'version' => hash('sha256', $account['CLAVE']),
        'activity' => time(),
    ];
    if ($csrf !== null) $_SESSION['csrf'] = $csrf;
}

function currentAccount(): ?array
{
    if (!isset($_SESSION['account'], $_SESSION['version'], $_SESSION['activity'])) return null;
    if (time() - $_SESSION['activity'] <= 1800) {
        $account = accountBy('id', $_SESSION['account']);
        if (accountActive($account) && hash_equals($_SESSION['version'], hash('sha256', $account['CLAVE']))) {
            $_SESSION['activity'] = time();
            return $account;
        }
    }
    $_SESSION = [];
    session_regenerate_id(true);
    return null;
}

function requireAccount(): array
{
    try {
        $account = currentAccount();
    } catch (Throwable) {
        http_response_code(503);
        exit('El acceso no está disponible. Intenta nuevamente.');
    }
    if (!$account) redirectTo('/dashboardadmin/login.php');
    return $account;
}

/** El panel es del personal: un cliente vuelve al portal. */
function requireStaff(): array
{
    $account = requireAccount();
    if ($account['ROL'] !== 'ADMINISTRADOR') redirectTo('/cliente/');
    return $account;
}

function redirectTo(string $url): never
{
    header('Location: ' . $url, true, 303);
    exit;
}

function esc(?string $value): string
{
    return htmlspecialchars($value ?? '', ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

function csrfToken(): string
{
    $_SESSION['csrf'] ??= bin2hex(random_bytes(32));
    return $_SESSION['csrf'];
}

function csrfField(): string
{
    return '<input type="hidden" name="csrf" value="' . esc(csrfToken()) . '">';
}

function post(string $name): string
{
    return is_string($_POST[$name] ?? null) ? $_POST[$name] : '';
}

function checkCsrf(): void
{
    if (!isset($_SESSION['csrf']) || !hash_equals($_SESSION['csrf'], post('csrf'))) {
        http_response_code(403);
        exit('La sesión del formulario venció. Vuelve a cargar la página.');
    }
}

function rateLimit(string $flow, string $login): void
{
    $directory = sys_get_temp_dir() . '/sgcd-auth-limit';
    if (!is_dir($directory) && !@mkdir($directory, 0700) && !is_dir($directory)) {
        throw new RuntimeException('No se pudo limitar el acceso.');
    }
    $identity = $_SERVER['REMOTE_ADDR'] ?? '';
    foreach ([[$identity, 35, 'ip'], [$login, 7, 'login']] as [$key, $limit, $kind]) {
        $path = $directory . '/' . hash('sha256', $flow . ':' . $kind . ':' . $key);
        $file = fopen($path, 'c+');
        if (!$file) throw new RuntimeException('No se pudo limitar el acceso.');
        try {
            if (!flock($file, LOCK_EX)) throw new RuntimeException('No se pudo limitar el acceso.');
            $data = json_decode(stream_get_contents($file), true);
            $now = time();
            if (!is_array($data) || $data[0] <= $now) $data = [$now + 900, 0];
            if ($data[1] >= $limit) throw new DomainException('Demasiados intentos. Espera 15 minutos y vuelve a intentarlo.');
            $data[1]++;
            rewind($file);
            ftruncate($file, 0);
            fwrite($file, json_encode($data));
        } finally {
            fclose($file);
        }
    }
}

function checkedLogin(): string
{
    // Los logins del catalogo son minusculas y LOGIN es sensible a mayusculas.
    $login = trim(post('login'));
    if (!preg_match('/^[A-Za-z0-9._-]{3,50}$/D', $login)) throw new DomainException('Ingresa un nombre de usuario válido.');
    return $login;
}

function newPasswordHash(): string
{
    $password = post('password');
    if (preg_match_all('/./us', $password) < 12 || strlen($password) > 72 || str_contains($password, "\0")) {
        throw new DomainException('La nueva contraseña debe tener al menos 12 caracteres y como máximo 72 bytes.');
    }
    if ($password !== post('confirm')) throw new DomainException('Las contraseñas no coinciden.');
    return password_hash($password, PASSWORD_DEFAULT);
}

function changeAccountPassword(array $account, string $hash): void
{
    authQuery('UPDATE SGCD_USUARIOS SET CLAVE_HASH = :hash WHERE ID_USUARIO = :id',
        ['hash' => $hash, 'id' => $account['ID']]);
    if (!oci_commit(authDb())) throw new RuntimeException('No se pudo guardar la contraseña.');
}

function rollbackAccountWork(): void
{
    try { oci_rollback(authDb()); } catch (Throwable) { /* Connection unavailable. */ }
}

function passwordFields(): string
{
    return '<label class="form-label w-100">Nueva contraseña<input class="form-control" type="password" name="password" autocomplete="new-password" required minlength="12" maxlength="72"></label>' .
           '<label class="form-label w-100">Repetir contraseña<input class="form-control" type="password" name="confirm" autocomplete="new-password" required minlength="12" maxlength="72"></label>';
}
