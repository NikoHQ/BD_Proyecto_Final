<?php if ($view === 'revisar'): ?>
  <div class="page-heading"><div><h1>Revisa tu reserva</h1><p>Comprueba los datos antes de enviar tu solicitud.</p></div><a class="btn btn-outline-success" href="<?= e(url('horarios')) ?>">Cambiar selección</a></div>
  <div class="split">
    <?php summary($selection); ?>
    <section class="surface side">
      <h2>Enviar a recepción</h2><p>Tu reserva quedará pendiente hasta que recepción la confirme.</p>
      <?php if ($awaitingFirst): ?>
        <p class="notice"><?= e(FIRST_RESERVATION_MESSAGE) ?></p>
        <a class="btn btn-success w-100" href="<?= e(url('reservas')) ?>">Ver mis reservas</a>
      <?php else: ?>
        <form method="post" data-once><?= csrf() ?><input type="hidden" name="action" value="send"><input type="hidden" name="key" value="<?= e($_SESSION['key']) ?>">
          <button class="btn btn-success w-100"><?= icon('send') ?> Enviar reserva</button>
        </form>
        <form method="post" class="mt-2"><?= csrf() ?><input type="hidden" name="action" value="recheck">
          <button class="btn btn-outline-success w-100">Consultar disponibilidad</button>
        </form>
      <?php endif; ?>
    </section>
  </div>
<?php elseif (in_array($view, ['comprobante','detalle'], true)): ?>
  <div class="page-heading"><div><h1><?= $view === 'comprobante' ? 'Solicitud enviada' : 'Detalle de reserva' ?></h1>
      <p class="mb-0">Código <strong><?= e($booking['code']) ?></strong> <?= badge($booking['status']) ?></p></div>
      <?php if ($view === 'detalle'): ?><a class="btn btn-outline-success" href="<?= e(url('reservas')) ?>">Volver a mis reservas</a><?php endif; ?></div>
  <div class="split">
    <?php summary($booking, 'Datos de la reserva'); ?>
    <section class="surface side">
      <?php if ($view === 'comprobante'): ?>
        <h2>Guarda el código de reserva</h2>
        <p>Recepción debe confirmar tu solicitud. Puedes revisar su estado en Mis reservas.</p>
        <div class="actions"><button class="btn btn-outline-success" type="button" data-copy="<?= e($booking['code']) ?>">Copiar código</button>
          <a class="btn btn-success" href="<?= e(url('reservas')) ?>">Ver mis reservas</a></div>
        <p class="copy-status mb-0" role="status"></p>
      <?php elseif ($portal->canCancel($booking)): ?>
        <h2>¿Necesitas cancelar?</h2><p>Cancelar liberará el horario para otros clientes.</p>
        <details><summary class="btn btn-outline-danger">Cancelar reserva</summary>
          <p class="mt-3">Confirma que quieres cancelar la reserva <?= e($booking['code']) ?>.</p>
          <form method="post"><?= csrf() ?><input type="hidden" name="action" value="cancel"><input type="hidden" name="code" value="<?= e($booking['code']) ?>">
          <button class="btn btn-danger">Confirmar cancelación</button></form>
        </details>
      <?php else: ?>
        <h2>Estado de la reserva</h2><?= badge($booking['status']) ?>
      <?php endif; ?>
    </section>
  </div>
<?php elseif ($view === 'reservas'): ?>
  <div class="page-heading"><div><h1>Mis reservas</h1><p>Consulta tus próximas reservas y tu historial.</p></div><?php if (!$awaitingFirst): ?><a class="btn btn-success" href="<?= e(url()) ?>">Nueva reserva</a><?php endif; ?></div>
  <?php if ($awaitingFirst): ?><p class="notice"><?= e(FIRST_RESERVATION_MESSAGE) ?></p><?php endif; ?>
  <?php $history = $portal->history($user); ?>
  <?php $upcoming = array_filter($history, $portal->canCancel(...)); ?>
  <?php foreach (['Próximas reservas' => $upcoming, 'Historial' => array_reverse(array_diff_key($history, $upcoming))] as $label => $bookings): ?>
    <section class="surface mb-3"><h2><?= e($label) ?></h2>
      <?php if (!$bookings): ?><p class="mb-0">Todavía no hay reservas en esta sección.</p><?php endif; ?>
      <?php foreach ($bookings as $item): ?>
        <div class="history-row"><div><strong><?= e($item['courtName']) ?> · <?= e(DemoPortal::MODES[$item['mode']]['label']) ?></strong>
          <p class="mb-0"><?= e(dateLabel($item['date'])) ?> · <?= e($item['start'] . '–' . $item['end']) ?> · <?= e($item['code']) ?></p></div>
          <?= badge($item['status']) ?><a href="<?= e(url('detalle', ['codigo' => $item['code']])) ?>">Ver detalle <span class="visually-hidden"><?= e($item['code']) ?></span></a>
        </div>
      <?php endforeach; ?>
    </section>
  <?php endforeach; ?>
<?php endif; ?>
