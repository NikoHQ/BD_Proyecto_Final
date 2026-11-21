<?php
declare(strict_types=1);

require_once __DIR__ . '/auth.php';

authStart();

/**
 * Traduccion de los errores de la capa de servicios a HTTP. El codigo que
 * viaja al navegador es el de Oracle; el mensaje, el que entiende el operador.
 * Lo que no este aqui se registra y sale como 500 sin detalle interno.
 */
const API_ERRORES = [
    1     => [409, 'Ese valor ya existe: revisa el RUT o el correo.'],
    2290  => [400, 'Un dato no cumple el formato o el largo permitido.'],
    2292  => [409, 'El registro tiene dependencias y no se puede borrar.'],
    12899 => [400, 'Un texto supera el largo permitido.'],
    20001 => [400, 'El RUT no es valido: revisa el digito verificador.'],
    20002 => [404, 'El cliente no existe.'],
    20009 => [400, 'Ese cambio de estado no esta permitido.'],
    20017 => [409, 'Ese correo ya esta registrado en otra ficha.'],
    20024 => [400, 'El identificador no es valido.'],
    20025 => [400, 'El nombre es obligatorio.'],
    20026 => [409, 'El cliente tiene reservas o cuentas asociadas. Desactivalo en vez de borrarlo.'],
    20027 => [400, 'El filtro o la paginacion no son validos.'],
];

function apiJson(array $carga, int $estado = 200): never
{
    http_response_code($estado);
    header('Content-Type: application/json; charset=utf-8');
    header('Cache-Control: no-store');
    echo json_encode($carga, JSON_UNESCAPED_UNICODE | JSON_INVALID_UTF8_SUBSTITUTE);
    exit;
}

function apiOk(mixed $datos, int $estado = 200): never
{
    apiJson(['ok' => true, 'data' => $datos], $estado);
}

function apiFail(string $mensaje, int $estado, ?int $codigo = null): never
{
    apiJson(['ok' => false, 'error' => ['codigo' => $codigo, 'mensaje' => $mensaje]], $estado);
}

function apiErrorOracle(int $codigo, string $mensaje): never
{
    [$estado, $texto] = API_ERRORES[$codigo] ?? [500, 'No se pudo completar la operacion.'];
    if ($estado >= 500) {
        error_log('SGCD API ORA-' . $codigo . ': ' . $mensaje);
    }
    apiFail($texto, $estado, $codigo);
}

/** Cuerpo de la peticion: JSON o formulario, sin distinguir el cliente. */
function apiEntrada(): array
{
    $tipo = $_SERVER['CONTENT_TYPE'] ?? '';
    if (stripos($tipo, 'application/json') !== false) {
        $crudo = file_get_contents('php://input');
        $datos = json_decode($crudo === false ? '[]' : $crudo, true);
        return is_array($datos) ? $datos : [];
    }
    return $_POST;
}

/** Sesion vigente y perfil autorizado. */
function apiSesion(array $perfiles): array
{
    try {
        $cuenta = currentAccount();
    } catch (Throwable $error) {
        error_log('SGCD API sesion: ' . $error->getMessage());
        apiFail('La base no esta disponible. Intenta en un momento.', 503);
    }
    if (!$cuenta) {
        apiFail('La sesion vencio. Vuelve a iniciar sesion.', 401);
    }
    if (!in_array($cuenta['ROL'], $perfiles, true)) {
        apiFail('Tu perfil no permite esta operacion.', 403);
    }
    return $cuenta;
}

/** Toda mutacion exige el token de la sesion, igual que los formularios. */
function apiCsrf(): void
{
    $enviado = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? (string) ($_POST['csrf'] ?? '');
    if (!isset($_SESSION['csrf']) || !hash_equals($_SESSION['csrf'], $enviado)) {
        apiFail('La sesion del formulario vencio. Recarga la pagina.', 403);
    }
}

/**
 * Ejecuta un bloque PL/SQL con binds por nombre. Devuelve los binds (para leer
 * los OUT) y las filas del cursor cuando se pide uno. No confirma por defecto:
 * solo las mutaciones piden commit explicito.
 */
function apiLlamar(string $plsql, array $binds = [], bool $confirmar = false, ?string $cursor = null): array
{
    try {
        $conexion = authDb();
    } catch (Throwable $error) {
        apiFail('La base no esta disponible. Intenta en un momento.', 503);
    }
    $sentencia = oci_parse($conexion, $plsql);
    if (!$sentencia) {
        apiFail('No se pudo preparar la operacion.', 500);
    }
    $ref = null;
    if ($cursor !== null) {
        $ref = oci_new_cursor($conexion);
        oci_bind_by_name($sentencia, ':' . $cursor, $ref, -1, SQLT_RSET);
    }
    foreach ($binds as $nombre => &$valor) {
        // OCI8 dimensiona el buffer con el largo actual del valor. Sin esto, un
        // OUT NUMBER inicializado en 0 queda con 1 byte y Oracle responde
        // ORA-06502 "character string buffer too small".
        $largo = is_string($valor) ? max(64, strlen($valor)) : 64;
        oci_bind_by_name($sentencia, ':' . $nombre, $valor, $largo);
    }
    unset($valor);

    if (!@oci_execute($sentencia, OCI_NO_AUTO_COMMIT)) {
        $fallo = oci_error($sentencia);
        oci_free_statement($sentencia);
        apiErrorOracle((int) ($fallo['code'] ?? 0), (string) ($fallo['message'] ?? ''));
    }

    $filas = [];
    if ($ref !== null) {
        if (!@oci_execute($ref, OCI_NO_AUTO_COMMIT)) {
            $fallo = oci_error($ref);
            oci_free_statement($ref);
            oci_free_statement($sentencia);
            apiErrorOracle((int) ($fallo['code'] ?? 0), (string) ($fallo['message'] ?? ''));
        }
        oci_fetch_all($ref, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
        oci_free_statement($ref);
    }

    if ($confirmar && !oci_commit($conexion)) {
        oci_rollback($conexion);
        oci_free_statement($sentencia);
        apiFail('No se pudo confirmar la operacion.', 500);
    }
    oci_free_statement($sentencia);
    return ['out' => $binds, 'filas' => $filas];
}
