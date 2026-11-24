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
    20040 => [400, 'Faltan datos o vienen mal escritos.'],
    20041 => [409, 'La cancha no admite esa modalidad o no esta disponible.'],
    20042 => [400, 'Ese horario esta fuera del horario del recinto.'],
    20043 => [409, 'Ese horario ya esta reservado.'],
    20044 => [400, 'La fecha u hora esta fuera del rango permitido.'],
    20045 => [409, 'El cliente o el administrador no estan habilitados.'],
    20046 => [409, 'El estado actual no permite esa operacion.'],
    20047 => [404, 'La reserva no existe.'],
    20050 => [400, 'El medio de pago o los datos no son validos.'],
    20051 => [404, 'La reserva no existe.'],
    20052 => [409, 'Solo se cobra por adelantado una reserva confirmada.'],
    20053 => [409, 'La reserva ya tiene un pago vigente.'],
    20054 => [409, 'La reserva no tiene un pago que cobrar o anular.'],
    20055 => [409, 'El pago ya esta anulado.'],
    20056 => [409, 'No hay diferencia por cobrar.'],
    20057 => [403, 'Tu usuario no esta habilitado para cobrar.'],
    20060 => [400, 'Los datos del torneo no son validos.'],
    20061 => [404, 'El torneo no existe.'],
    20062 => [409, 'El estado del torneo no permite esa operacion.'],
    20063 => [409, 'No quedan cupos en el torneo.'],
    20064 => [409, 'La plantilla supera el maximo del torneo.'],
    20065 => [409, 'Ese jugador ya esta en el equipo.'],
    20066 => [409, 'Ese jugador ya juega en otro equipo del torneo.'],
    20067 => [409, 'El capitan no existe o esta inactivo.'],
    20068 => [404, 'La inscripcion no existe o no esta vigente.'],
    20069 => [409, 'Ya hay un equipo con ese nombre en el torneo.'],
    20070 => [400, 'El rango de programacion debe cubrir bloques completos.'],
    20080 => [400, 'El reporte necesita un rango de fechas valido.'],
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

/** Fecha Y-m-d del navegador; se devuelve lista para bind DATE. */
function apiFecha(string $valor, string $campo = 'fecha'): string
{
    return apiFechaCorta($valor, $campo) . ' 00:00:00';
}

/** Valida Y-m-d y devuelve solo el dia, para consultas de rango. */
function apiFechaCorta(mixed $valor, string $campo = 'fecha'): string
{
    $texto = is_scalar($valor) ? trim((string) $valor) : '';
    $fecha = DateTimeImmutable::createFromFormat('!Y-m-d', $texto);
    if (!$fecha || $fecha->format('Y-m-d') !== $texto) {
        apiFail('El campo ' . $campo . ' no es una fecha valida.', 400);
    }
    return $texto;
}

/** Hora HH:MM del navegador. */
function apiHora(string $valor): string
{
    if (!preg_match('/^([01]\d|2[0-3]):[0-5]\d$/', $valor)) {
        apiFail('La hora debe venir en formato HH:MM.', 400);
    }
    return $valor;
}

/** "12.345.678-5", "12345678-5" o "123456785" -> [12345678, "5"]. */
function apiRutPartes(string $crudo): array
{
    $compacto = strtoupper((string) preg_replace('/[.\s-]/', '', trim($crudo)));
    if (!preg_match('/^([1-9]\d{0,7})([0-9K])$/', $compacto, $partes)) {
        apiFail('Escribe el RUT completo, con su digito verificador.', 400);
    }
    return [(int) $partes[1], $partes[2]];
}

function apiEntero(mixed $valor, string $campo): int
{
    if (!is_numeric($valor) || (string) (int) $valor !== (string) $valor) {
        apiFail('El campo ' . $campo . ' no es valido.', 400);
    }
    return (int) $valor;
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
    // Los triggers de auditoria atribuyen el cambio a CLIENT_IDENTIFIER y ese
    // valor termina en ID_ADMINISTRADOR. Solo se declara para personal: un
    // cliente no tiene fila en esa tabla.
    if ($cuenta['ROL'] === 'ADMINISTRADOR' && !empty($cuenta['PERSONAL'])) {
        apiLlamar('BEGIN DBMS_SESSION.SET_IDENTIFIER(:id); END;',
            ['id' => (int) $cuenta['PERSONAL']]);
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
