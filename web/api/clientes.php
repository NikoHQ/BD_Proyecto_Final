<?php
declare(strict_types=1);

require_once __DIR__ . '/../includes/api.php';

/**
 * CRUD de la ficha del cliente. Toda la regla vive en SGCD_PKG_CLIENTES; aqui
 * solo se autoriza, se traduce el DTO y se decide el codigo HTTP.
 *
 *   GET  ?accion=listar&texto=&estado=&pagina=1&tamano=20
 *   GET  ?accion=ver&id=12
 *   POST ?accion=crear        nombre, rut, telefono, correo
 *   POST ?accion=actualizar   id, nombre, telefono, correo
 *   POST ?accion=estado       id, estado (ACTIVO | INACTIVO)
 *   POST ?accion=borrar       id                (solo ADMINISTRADOR)
 */

const PERFILES_FICHA = ['ADMINISTRADOR', 'OPERADOR'];

$accion = (string) ($_GET['accion'] ?? 'listar');
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
$entrada = apiEntrada();

if ($metodo !== 'GET' && $metodo !== 'POST') {
    apiFail('Metodo no permitido.', 405);
}
if ($metodo === 'POST') {
    apiCsrf();
}
apiSesion($accion === 'borrar' ? ['ADMINISTRADOR'] : PERFILES_FICHA);

/** "12.345.678-5", "12345678-5" o "123456785" -> [12345678, "5"]. */
function apiRut(array $entrada): array
{
    $crudo = (string) ($entrada['rut'] ?? '');
    if ($crudo === '' && isset($entrada['rut_numero'], $entrada['dv'])) {
        $crudo = (string) $entrada['rut_numero'] . '-' . (string) $entrada['dv'];
    }
    $compacto = strtoupper((string) preg_replace('/[.\s-]/', '', trim($crudo)));
    if (!preg_match('/^([1-9]\d{0,7})([0-9K])$/', $compacto, $partes)) {
        apiFail('Escribe el RUT completo, con su digito verificador.', 400);
    }
    return [(int) $partes[1], $partes[2]];
}

function apiId(array $entrada): int
{
    $valor = $entrada['id'] ?? null;
    if (!is_numeric($valor) || (string) (int) $valor !== (string) $valor) {
        apiFail('Falta el identificador del cliente.', 400);
    }
    return (int) $valor;
}

function apiTexto(array $entrada, string $campo): string
{
    $valor = $entrada[$campo] ?? '';
    return is_scalar($valor) ? trim((string) $valor) : '';
}

function apiFicha(array $fila): array
{
    return [
        'id' => (int) $fila['ID_CLIENTE'],
        'rut' => $fila['RUT_CLIENTE'] . '-' . $fila['DV_CLIENTE'],
        'nombre' => $fila['NOMBRE_CLIENTE'],
        'telefono' => ($fila['TELEFONO_CLIENTE'] ?? '') === '' ? null : $fila['TELEFONO_CLIENTE'],
        'correo' => ($fila['CORREO_CLIENTE'] ?? '') === '' ? null : $fila['CORREO_CLIENTE'],
        'estado' => $fila['ESTADO_CLIENTE'],
        'creado_en' => $fila['CREADO_EN_CLIENTE'],
    ];
}

/** Lee la ficha ya confirmada, para devolver el estado real y no el enviado. */
function apiDetalle(int $id): array
{
    $r = apiLlamar('BEGIN :cursor := SGCD_PKG_CLIENTES.ficha_detalle(:id); END;',
        ['id' => $id], false, 'cursor');
    if (!$r['filas']) {
        apiFail('El cliente no existe.', 404, 20002);
    }
    $fila = apiFicha($r['filas'][0]);
    $fila['reservas'] = (int) $r['filas'][0]['RESERVAS'];
    $fila['reservas_vigentes'] = (int) $r['filas'][0]['RESERVAS_VIGENTES'];
    $fila['importe_pagado'] = (float) $r['filas'][0]['IMPORTE_PAGADO'];
    $fila['cuenta_web'] = (int) $r['filas'][0]['CUENTA_WEB'] > 0;
    $fila['eventos_auditoria'] = (int) $r['filas'][0]['EVENTOS'];
    return $fila;
}

switch ($accion) {
    case 'listar':
        if ($metodo !== 'GET') {
            apiFail('Usa GET para listar.', 405);
        }
        $pagina = filter_var($_GET['pagina'] ?? 1, FILTER_VALIDATE_INT) ?: 1;
        $tamano = filter_var($_GET['tamano'] ?? 20, FILTER_VALIDATE_INT) ?: 20;
        $total = 0;
        $r = apiLlamar(
            'BEGIN SGCD_PKG_CLIENTES.listar_fichas(:texto, :estado, :desde, :tamano, :cursor, :total); END;',
            [
                'texto' => (string) ($_GET['texto'] ?? ''),
                'estado' => strtoupper((string) ($_GET['estado'] ?? '')),
                'desde' => $pagina,
                'tamano' => $tamano,
                'total' => $total,
            ],
            false,
            'cursor'
        );
        apiOk([
            'items' => array_map('apiFicha', $r['filas']),
            'total' => (int) $r['out']['total'],
            'pagina' => $pagina,
            'tamano' => $tamano,
            'paginas' => (int) ceil($r['out']['total'] / $tamano),
        ]);
        break;

    case 'ver':
        $id = apiId($_GET);
        apiOk(apiDetalle($id));
        break;

    case 'crear':
        if ($metodo !== 'POST') {
            apiFail('Usa POST para crear.', 405);
        }
        [$rut, $dv] = apiRut($entrada);
        $nombre = apiTexto($entrada, 'nombre');
        if ($nombre === '') {
            apiFail('El nombre es obligatorio.', 400, 20025);
        }
        $id = 0;
        $creada = 0;
        $llamada = apiLlamar(
            'DECLARE v_creada BOOLEAN; BEGIN '
            . 'SGCD_PKG_CLIENTES.crear_ficha(:rut, :dv, :nombre, :telefono, :correo, :id, v_creada); '
            . ':creada := CASE WHEN v_creada THEN 1 ELSE 0 END; END;',
            [
                'rut' => $rut,
                'dv' => $dv,
                'nombre' => $nombre,
                'telefono' => apiTexto($entrada, 'telefono'),
                'correo' => apiTexto($entrada, 'correo'),
                'id' => $id,
                'creada' => $creada,
            ],
            true
        );
        // Los OUT viven en la copia de los binds que devuelve apiLlamar.
        $id = (int) $llamada['out']['id'];
        $creada = (int) $llamada['out']['creada'];
        $ficha = apiDetalle($id);
        apiOk($ficha + ['creada' => $creada === 1], $creada === 1 ? 201 : 200);
        break;

    case 'actualizar':
        if ($metodo !== 'POST') {
            apiFail('Usa POST para actualizar.', 405);
        }
        $id = apiId($entrada);
        apiLlamar(
            'BEGIN SGCD_PKG_CLIENTES.actualizar_ficha(:id, :nombre, :telefono, :correo); END;',
            [
                'id' => $id,
                'nombre' => apiTexto($entrada, 'nombre'),
                'telefono' => apiTexto($entrada, 'telefono'),
                'correo' => apiTexto($entrada, 'correo'),
            ],
            true
        );
        apiOk(apiDetalle($id));
        break;

    case 'estado':
        if ($metodo !== 'POST') {
            apiFail('Usa POST para cambiar el estado.', 405);
        }
        $id = apiId($entrada);
        apiLlamar(
            'BEGIN SGCD_PKG_CLIENTES.cambiar_estado(:id, :estado); END;',
            ['id' => $id, 'estado' => strtoupper(apiTexto($entrada, 'estado'))],
            true
        );
        apiOk(apiDetalle($id));
        break;

    case 'borrar':
        if ($metodo !== 'POST') {
            apiFail('Usa POST para borrar.', 405);
        }
        $id = apiId($entrada);
        apiLlamar('BEGIN SGCD_PKG_CLIENTES.borrar_ficha(:id); END;', ['id' => $id], true);
        apiOk(['id' => $id, 'borrado' => true]);
        break;

    default:
        apiFail('Accion desconocida.', 400);
}
