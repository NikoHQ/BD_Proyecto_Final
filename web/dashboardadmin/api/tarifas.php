<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';

$accion = (string) ($_GET['accion'] ?? 'listar');
$metodo = $_SERVER['REQUEST_METHOD'] ?? 'GET';
if ($metodo !== ($accion === 'listar' ? 'GET' : 'POST')) {
    apiFail('Método no permitido.', 405);
}
apiSesion(['ADMINISTRADOR']);
if ($metodo === 'POST') {
    apiCsrf();
}

if ($accion === 'listar') {
    $r = apiLlamar('BEGIN SGCD_LISTAR_TARIFAS(:cancha, :modalidad, :estado, :cursor); END;', [
        'cancha' => isset($_GET['cancha']) ? apiEntero($_GET['cancha'], 'cancha') : null,
        'modalidad' => isset($_GET['modalidad']) ? apiEntero($_GET['modalidad'], 'modalidad') : null,
        'estado' => (string) ($_GET['estado'] ?? ''),
    ], false, 'cursor');
    apiOk(array_map(static fn(array $f): array => [
        'id' => (int) $f['ID_TARIFA'],
        'cancha' => (int) $f['ID_CANCHA'],
        'modalidad' => (int) $f['ID_MODALIDAD'],
        'dia' => (int) $f['DIA_SEMANA'],
        'inicio' => trim($f['HORA_DESDE']),
        'fin' => trim($f['HORA_HASTA']),
        'desde' => substr($f['VIGENTE_DESDE'], 0, 10),
        'hasta' => $f['VIGENTE_HASTA'] === null ? null : substr($f['VIGENTE_HASTA'], 0, 10),
        'valor' => (float) $f['VALOR_HORA'],
        'estado' => $f['ESTADO_TARIFA'],
    ], $r['filas']));
}

$entrada = apiEntrada();
$id = $accion === 'crear' ? 0 : apiEntero($entrada['id'] ?? null, 'id');
if ($accion === 'estado') {
    apiLlamar('BEGIN SGCD_CAMBIAR_ESTADO_TARIFA(:id, :estado); END;', [
        'id' => $id, 'estado' => (string) ($entrada['estado'] ?? ''),
    ], true);
    apiOk(['id' => $id]);
}
if ($accion === 'borrar') {
    apiLlamar('BEGIN SGCD_BORRAR_TARIFA(:id); END;', ['id' => $id], true);
    apiOk(['id' => $id]);
}
if (!in_array($accion, ['crear', 'editar', 'dividir'], true)) {
    apiFail('Acción no válida.', 400);
}
if ($accion === 'dividir') {
    $r = apiLlamar('BEGIN SGCD_DIVIDIR_TARIFA(:id, :hora, :valor, :nueva); END;', [
        'id' => $id,
        'hora' => apiHora((string) ($entrada['hora'] ?? '')),
        'valor' => apiEntero($entrada['valor'] ?? null, 'valor'),
        'nueva' => 0,
    ], true);
    apiOk(['id' => (int) $r['out']['nueva']], 201);
}

$binds = [
    'id' => $id,
    'dia' => apiEntero($entrada['dia'] ?? null, 'dia'),
    'inicio' => apiHora((string) ($entrada['inicio'] ?? '')),
    'fin' => apiHora((string) ($entrada['fin'] ?? '')),
    'desde' => apiFechaCorta($entrada['desde'] ?? '', 'desde') . ' 00:00:00',
    'hasta' => empty($entrada['hasta']) ? null : apiFechaCorta($entrada['hasta'], 'hasta') . ' 00:00:00',
    'valor' => apiEntero($entrada['valor'] ?? null, 'valor'),
];
if ($accion === 'editar') {
    apiLlamar('BEGIN SGCD_ACTUALIZAR_TARIFA(:id, :dia, :inicio, :fin, :desde, :hasta, :valor); END;', $binds, true);
    apiOk(['id' => $id]);
}

$binds['cancha'] = apiEntero($entrada['cancha'] ?? null, 'cancha');
$binds['modalidad'] = apiEntero($entrada['modalidad'] ?? null, 'modalidad');
$r = apiLlamar('BEGIN SGCD_CREAR_TARIFA(:cancha, :modalidad, :dia, :inicio, :fin, :desde, :hasta, :valor, :id); END;',
    $binds, true);
apiOk(['id' => (int) $r['out']['id']], 201);
