<?php
declare(strict_types=1);

require_once __DIR__ . '/../../includes/api.php';

$accion = (string) ($_GET['accion'] ?? '');
$accionesLectura = ['modalidades', 'horarios', 'bloques', 'cancha-modalidades'];
$esLectura = in_array($accion, $accionesLectura, true);
if (($_SERVER['REQUEST_METHOD'] ?? 'GET') !== ($esLectura ? 'GET' : 'POST')) {
    apiFail('Método no permitido.', 405);
}
apiSesion(['ADMINISTRADOR']);
if (!$esLectura) {
    apiCsrf();
}

function mantenedorFilas(string $llamada, array $binds = []): array
{
    return apiLlamar($llamada, $binds, false, 'cursor')['filas'];
}

switch ($accion) {
    case 'modalidades':
        $deportes = mantenedorFilas('BEGIN SGCD_LISTAR_DEPORTES(:cursor); END;');
        $modalidades = mantenedorFilas('BEGIN SGCD_LISTAR_MODALIDADES(:cursor); END;');
        apiOk([
            'deportes' => array_map(static fn(array $f): array => [
                'id' => (int) $f['ID_DEPORTE'], 'nombre' => $f['NOMBRE_DEPORTE'], 'estado' => $f['ESTADO_DEPORTE'],
            ], $deportes),
            'modalidades' => array_map(static fn(array $f): array => [
                'id' => (int) $f['ID_MODALIDAD'], 'nombre' => $f['NOMBRE_MODALIDAD'],
                'deporte' => (int) $f['ID_DEPORTE'], 'minimo' => (int) $f['MIN_JUGADORES_POR_EQUIPO'],
                'maximo' => (int) $f['MAX_JUGADORES_POR_EQUIPO'],
                'estado' => $f['ESTADO_MODALIDAD'],
            ], $modalidades),
        ]);

    case 'horarios':
        $horarios = mantenedorFilas('BEGIN SGCD_LISTAR_HORARIOS(:id, :cursor); END;',
            ['id' => apiEntero($_GET['id'] ?? null, 'id')]);
        apiOk(array_map(static fn(array $f): array => [
            'id' => (int) $f['ID_HORARIO'], 'dia' => (int) $f['DIA_SEMANA'],
            'apertura' => trim($f['HORA_APERTURA']), 'cierre' => trim($f['HORA_CIERRE']),
        ], $horarios));

    case 'bloques':
        $bloques = mantenedorFilas('BEGIN SGCD_LISTAR_BLOQUES_HORARIOS(:id, :cursor); END;',
            ['id' => apiEntero($_GET['id'] ?? null, 'id')]);
        apiOk(array_map(static fn(array $f): array => [
            'id' => (int) $f['ID_BLOQUE_HORARIO'], 'inicio' => trim($f['HORA_INICIO']),
            'fin' => trim($f['HORA_TERMINO']),
        ], $bloques));

    case 'cancha-modalidades':
        $filas = mantenedorFilas('BEGIN SGCD_LISTAR_CANCHA_MODALIDAD(:id, :cursor); END;',
            ['id' => apiEntero($_GET['id'] ?? null, 'id')]);
        apiOk(array_map(static fn(array $f): int => (int) $f['ID_MODALIDAD'], $filas));
}

$entrada = apiEntrada();
$id = apiEntero($entrada['id'] ?? 0, 'id');
[$entidad, $operacion] = array_pad(explode('-', $accion, 2), 2, '');
$eliminar = [
    'recinto' => 'SGCD_BORRAR_RECINTO',
    'deporte' => 'SGCD_BORRAR_DEPORTE',
    'modalidad' => 'SGCD_BORRAR_MODALIDAD',
    'horario' => 'SGCD_BORRAR_HORARIO',
    'bloque' => 'SGCD_BORRAR_BLOQUE_HORARIO',
];
if ($operacion === 'borrar' && $entidad === 'cancha') {
    apiLlamar(
        "DECLARE v_id NUMBER;
         BEGIN
            SELECT ID_CANCHA INTO v_id FROM SGCD_CANCHAS WHERE ID_CANCHA = :id FOR UPDATE;
            FOR modalidad IN (SELECT ID_MODALIDAD FROM SGCD_CANCHAS_MODALIDADES WHERE ID_CANCHA = v_id) LOOP
                SGCD_BORRAR_CANCHA_MODALIDAD(v_id, modalidad.ID_MODALIDAD);
            END LOOP;
            SGCD_BORRAR_CANCHA(v_id);
         EXCEPTION
            WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20862, 'La cancha no existe');
            WHEN OTHERS THEN
                IF SQLCODE = -2292 THEN RAISE_APPLICATION_ERROR(-20864, 'La cancha esta en uso'); END IF;
                RAISE;
         END;",
        ['id' => $id],
        true
    );
    apiOk(['id' => $id]);
}
if ($operacion === 'borrar' && isset($eliminar[$entidad])) {
    apiLlamar('BEGIN ' . $eliminar[$entidad] . '(:id); END;', ['id' => $id], true);
    apiOk(['id' => $id]);
}
if ($operacion === 'estado') {
    $llamada = match ($entidad) {
        'recinto' => 'DECLARE r SGCD_RECINTOS%ROWTYPE; BEGIN
            SELECT * INTO r FROM SGCD_RECINTOS WHERE ID_RECINTO = :id FOR UPDATE;
            SGCD_ACTUALIZAR_RECINTO(:id, r.NOMBRE_RECINTO, r.DIRECCION_RECINTO, :estado);
            EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20872, \'El recinto no existe\'); END;',
        'cancha' => 'DECLARE r SGCD_CANCHAS%ROWTYPE; BEGIN
            SELECT * INTO r FROM SGCD_CANCHAS WHERE ID_CANCHA = :id FOR UPDATE;
            SGCD_ACTUALIZAR_CANCHA(:id, r.NOMBRE_CANCHA, r.TIPO_CANCHA, :estado);
            EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20862, \'La cancha no existe\'); END;',
        'modalidad' => 'DECLARE r SGCD_MODALIDADES%ROWTYPE; BEGIN
            SELECT * INTO r FROM SGCD_MODALIDADES WHERE ID_MODALIDAD = :id FOR UPDATE;
            SGCD_ACTUALIZAR_MODALIDAD(:id, r.ID_DEPORTE, r.MIN_JUGADORES_POR_EQUIPO, r.MAX_JUGADORES_POR_EQUIPO, r.NOMBRE_MODALIDAD, :estado);
            EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20832, \'La modalidad no existe\'); END;',
        'deporte' => 'DECLARE r SGCD_DEPORTES%ROWTYPE; BEGIN
            SELECT * INTO r FROM SGCD_DEPORTES WHERE ID_DEPORTE = :id FOR UPDATE;
            SGCD_ACTUALIZAR_DEPORTE(:id, r.NOMBRE_DEPORTE, :estado);
            EXCEPTION WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20832, \'El deporte no existe\'); END;',
        default => null,
    };
    if ($llamada === null) {
        apiFail('Acción no válida.', 400);
    }
    apiLlamar($llamada, ['id' => $id, 'estado' => (string) ($entrada['estado'] ?? '')], true);
    apiOk(['id' => $id]);
}
if ($operacion !== 'guardar') {
    apiFail('Acción no válida.', 400);
}

$nombre = trim((string) ($entrada['nombre'] ?? ''));
$estado = (string) ($entrada['estado'] ?? '');
$binds = ['id' => $id];
switch ($entidad) {
    case 'recinto':
        $binds += ['nombre' => $nombre, 'direccion' => trim((string) ($entrada['direccion'] ?? '')), 'estado' => $estado];
        $llamada = $id ? 'SGCD_ACTUALIZAR_RECINTO(:id, :nombre, :direccion, :estado)'
            : 'SGCD_CREAR_RECINTO(:nombre, :direccion, :estado, :id)';
        break;

    case 'deporte':
        $binds['nombre'] = $nombre;
        if ($id) {
            $binds['estado'] = $estado;
            $llamada = 'SGCD_ACTUALIZAR_DEPORTE(:id, :nombre, :estado)';
        } else {
            $llamada = 'SGCD_CREAR_DEPORTE(:nombre, :id)';
        }
        break;

    case 'modalidad':
        $maximo = apiEntero($entrada['maximo'] ?? null, 'maximo');
        $binds += ['nombre' => $nombre, 'deporte' => apiEntero($entrada['deporte'] ?? null, 'deporte'),
            'minimo' => isset($entrada['minimo']) && $entrada['minimo'] !== '' ? apiEntero($entrada['minimo'], 'minimo') : 1,
            'maximo' => $maximo];
        $llamada = 'SGCD_CREAR_MODALIDAD(:deporte, :minimo, :maximo, :nombre, :id)';
        if ($id) {
            $binds['estado'] = $estado;
            $llamada = 'SGCD_ACTUALIZAR_MODALIDAD(:id, :deporte, :minimo, :maximo, :nombre, :estado)';
        }
        break;

    case 'cancha':
        $modalidades = $entrada['modalidades'] ?? null;
        if (!is_array($modalidades) || !$modalidades) {
            apiFail('Selecciona al menos una modalidad.', 400);
        }
        $modalidades = array_unique(array_map(static fn($v) => apiEntero($v, 'modalidad'), $modalidades));
        $binds += ['nombre' => $nombre, 'tipo' => trim((string) ($entrada['tipo'] ?? '')), 'estado' => $estado];
        $llamada = 'SGCD_ACTUALIZAR_CANCHA(:id, :nombre, :tipo, :estado)';
        if (!$id) {
            $binds['recinto'] = apiEntero($entrada['recinto'] ?? null, 'recinto');
            $llamada = 'SGCD_CREAR_CANCHA(:recinto, :nombre, :tipo, :estado, :id)';
        }

        // La actualización bloquea la cancha antes de leer el conjunto a reemplazar.
        $r = apiLlamar('BEGIN ' . $llamada . '; END;', $binds);
        $id = (int) $r['out']['id'];
        $actuales = array_column(mantenedorFilas('BEGIN SGCD_LISTAR_CANCHA_MODALIDAD(:id, :cursor); END;',
            ['id' => $id]), 'ID_MODALIDAD');
        foreach (array_diff($modalidades, $actuales) as $modalidad) {
            apiLlamar('BEGIN SGCD_CREAR_CANCHA_MODALIDAD(:id, :modalidad); END;', compact('id', 'modalidad'));
        }
        foreach (array_diff($actuales, $modalidades) as $modalidad) {
            apiLlamar('BEGIN SGCD_BORRAR_CANCHA_MODALIDAD(:id, :modalidad); END;', compact('id', 'modalidad'));
        }
        if (!oci_commit(authDb())) {
            oci_rollback(authDb());
            apiFail('No se pudo confirmar la operación.', 500);
        }
        apiOk(['id' => $id]);

    case 'horario':
        $binds += ['apertura' => apiHora((string) ($entrada['apertura'] ?? '')),
            'cierre' => apiHora((string) ($entrada['cierre'] ?? ''))];
        $llamada = 'SGCD_ACTUALIZAR_HORARIO(:id, :apertura, :cierre)';
        if (!$id) {
            $binds['recinto'] = apiEntero($entrada['recinto'] ?? null, 'recinto');
            $binds['dia'] = apiEntero($entrada['dia'] ?? null, 'dia');
            $llamada = 'SGCD_CREAR_HORARIO(:recinto, :dia, :apertura, :cierre, :id)';
        }
        break;

    case 'bloque':
        $binds += ['inicio' => apiHora((string) ($entrada['inicio'] ?? '')),
            'fin' => apiHora((string) ($entrada['fin'] ?? ''))];
        $llamada = 'SGCD_ACTUALIZAR_BLOQUE_HORARIO(:id, :inicio, :fin)';
        if (!$id) {
            $binds['horario'] = apiEntero($entrada['horario'] ?? null, 'horario');
            $llamada = 'SGCD_CREAR_BLOQUE_HORARIO(:horario, :inicio, :fin, :id)';
        }
        break;

    default:
        apiFail('Acción no válida.', 400);
}

$r = apiLlamar('BEGIN ' . $llamada . '; END;', $binds, true);
apiOk(['id' => (int) $r['out']['id']], $id ? 200 : 201);
