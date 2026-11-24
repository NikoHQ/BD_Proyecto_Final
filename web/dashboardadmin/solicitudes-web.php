<?php
declare(strict_types=1);
require_once __DIR__ . '/../includes/auth.php';

authStart();
$cuenta = requireStaff();
$puedeConfirmar = $cuenta['ROL'] === 'ADMINISTRADOR';
$aviso = null;

/** Solicitudes web pendientes del rango visible. */
function solicitudesWeb(): array
{
    $conexion = authDb();
    $desde = date('Y-m-d', strtotime('-30 days')) . ' 00:00:00';
    $hasta = date('Y-m-d', strtotime('+90 days')) . ' 00:00:00';
    $sentencia = oci_parse($conexion,
        'BEGIN SGCD_PKG_RESERVAS.agenda(:desde, :hasta, NULL, NULL, :cursor); END;');
    $cursor = oci_new_cursor($conexion);
    oci_bind_by_name($sentencia, ':desde', $desde);
    oci_bind_by_name($sentencia, ':hasta', $hasta);
    oci_bind_by_name($sentencia, ':cursor', $cursor, -1, SQLT_RSET);
    if (!@oci_execute($sentencia) || !@oci_execute($cursor)) {
        throw new RuntimeException('No se pudo leer la agenda.');
    }
    $filas = [];
    oci_fetch_all($cursor, $filas, 0, -1, OCI_FETCHSTATEMENT_BY_ROW);
    oci_free_statement($cursor);
    oci_free_statement($sentencia);
    return array_values(array_filter($filas, static fn(array $f): bool =>
        $f['ORIGEN_RESERVA'] === 'WEB' && $f['ESTADO_RESERVA'] === 'PENDIENTE'));
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    checkCsrf();
    $id = filter_var(post('reserva'), FILTER_VALIDATE_INT) ?: 0;
    $accion = post('accion');
    if ($id <= 0 || !in_array($accion, ['confirmar', 'cancelar'], true)) {
        http_response_code(400);
        exit('Solicitud no válida.');
    }
    if ($accion === 'confirmar' && !$puedeConfirmar) {
        http_response_code(403);
        exit('Sólo un administrador puede confirmar la reserva.');
    }
    try {
        $procedimiento = $accion === 'confirmar' ? 'confirmar_reserva' : 'cancelar_reserva';
        $sentencia = oci_parse(authDb(), "BEGIN SGCD_PKG_RESERVAS.$procedimiento(:id); END;");
        $idReserva = $id;
        oci_bind_by_name($sentencia, ':id', $idReserva);
        if (!@oci_execute($sentencia)) {
            throw new RuntimeException(oci_error($sentencia)['message'] ?? 'No se pudo actualizar la reserva.');
        }
        oci_commit(authDb());
    } catch (Throwable $error) {
        rollbackAccountWork();
        $texto = $error->getMessage();
        $aviso = str_contains($texto, 'ORA-20046')
            ? 'El estado actual de la reserva no permite esa operación.'
            : 'No se pudo actualizar la reserva.';
    }
    if ($aviso === null) {
        $aviso = $accion === 'confirmar' ? 'Reserva confirmada.' : 'Solicitud cancelada.';
    }
    $_SESSION['solicitudes_aviso'] = $aviso;
    redirectTo('/dashboardadmin/solicitudes-web.php');
}

$aviso = $_SESSION['solicitudes_aviso'] ?? null;
unset($_SESSION['solicitudes_aviso']);

try {
    $pendientes = solicitudesWeb();
    $errorBase = '';
} catch (Throwable $error) {
    error_log('SGCD solicitudes web: ' . $error->getMessage());
    $pendientes = [];
    $errorBase = 'No se pudo consultar la agenda en Oracle.';
}
?>
<!doctype html>
<html lang="es">
<head>
  <meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Solicitudes web · SGCD</title>
  <?php require __DIR__ . '/../includes/styles.php'; ?>
</head>
<body>
<main class="container py-4">
  <a href="/dashboardadmin/#reservas">← Volver a Reservas</a>
  <h1 class="mt-2">Solicitudes web</h1>
  <p>Reservas creadas por clientes desde el portal. Quedan pendientes hasta que el personal las confirme.</p>
  <?php if ($aviso): ?><p class="alert alert-info" role="status"><?= esc($aviso) ?></p><?php endif; ?>
  <?php if ($errorBase): ?><p class="alert alert-danger" role="alert"><?= esc($errorBase) ?></p><?php endif; ?>
  <section class="card">
    <?php if (!$pendientes): ?><p class="card-body mb-0">No hay solicitudes web pendientes.</p>
    <?php else: ?><div class="table-responsive">
      <table class="table align-middle mb-0">
        <thead><tr><th>Reserva</th><th>Cliente</th><th>Cancha</th><th>Horario</th><th>Importe</th><th>Acciones</th></tr></thead>
        <tbody>
          <?php foreach ($pendientes as $fila): ?>
            <tr>
              <th scope="row">#R-<?= (int) $fila['ID_RESERVA'] ?></th>
              <td><?= esc($fila['NOMBRE_CLIENTE'] ?? '—') ?></td>
              <td><?= esc($fila['NOMBRE_CANCHA']) ?> · <?= esc($fila['NOMBRE_MODALIDAD']) ?></td>
              <td><?= esc(substr((string) $fila['INICIO_RESERVA'], 0, 16)) ?>–<?= esc(substr((string) $fila['TERMINO_RESERVA'], 11, 5)) ?></td>
              <td><?= esc('$' . number_format((float) $fila['IMPORTE_ACORDADO'], 0, ',', '.')) ?></td>
              <td><form class="d-flex flex-wrap gap-2" method="post" action="/dashboardadmin/solicitudes-web.php">
                <?= csrfField() ?><input type="hidden" name="reserva" value="<?= (int) $fila['ID_RESERVA'] ?>">
                <?php if ($puedeConfirmar): ?><button class="btn btn-accent btn-sm" name="accion" value="confirmar">Confirmar reserva</button><?php endif; ?>
                <button class="btn btn-outline-danger btn-sm" name="accion" value="cancelar">Cancelar solicitud</button>
              </form></td>
            </tr>
          <?php endforeach; ?>
        </tbody>
      </table>
    </div><?php endif; ?>
  </section>
</main>
</body>
</html>
