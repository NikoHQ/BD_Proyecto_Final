<?php if ($view === 'inicio'): ?>
  <section class="hero">
    <div><span class="eyebrow"><?= icon('geo-alt') ?> Canchas deportivas</span><h1>Reserva tu cancha</h1><p>Elige qué quieres jugar y encuentra un horario disponible.</p></div>
    <img class="court-art" src="/cliente/centro-deportivo.svg" alt="" width="520" height="284">
  </section>
  <form method="post" class="split">
    <?= csrf() ?><input type="hidden" name="action" value="mode">
    <section><h2 class="mb-3">¿Qué quieres jugar?</h2><div class="sports">
      <?php foreach (DemoPortal::MODES as $key => $mode): ?>
        <label class="sport surface"><input type="radio" name="mode" value="<?= e($key) ?>" <?= $filter['mode'] === $key ? 'checked' : '' ?> required>
          <span class="sport-symbol"><?= icon($mode['icon']) ?></span><strong><?= e($mode['label']) ?></strong><small><?= e($mode['players']) ?></small>
        </label>
      <?php endforeach; ?>
    </div></section>
    <section class="surface side"><h2>Busca tu próximo partido</h2><p>Compara canchas, horarios y precios antes de iniciar sesión.</p>
      <button class="btn btn-success w-100"><?= icon('search') ?> Buscar disponibilidad</button></section>
  </form>
<?php elseif ($view === 'buscar'): ?>
  <div class="split">
    <section class="surface">
      <h1>Buscar disponibilidad</h1><p>Elige la fecha y la cantidad de bloques consecutivos.</p>
      <div class="mode-strip"><?= icon(DemoPortal::MODES[$filter['mode']]['icon']) ?> <strong><?= e(DemoPortal::MODES[$filter['mode']]['label']) ?></strong><a href="<?= e(url()) ?>">Cambiar modalidad</a></div>
      <p class="small mt-2"><?= icon('geo-alt') ?> Las Rastras</p>
      <form method="post"><?= csrf() ?><input type="hidden" name="action" value="search">
        <div class="row g-3 my-3">
          <div class="col-sm"><label for="fecha" class="form-label">Fecha</label><input id="fecha" name="date" type="date" min="<?= e($portal->today) ?>" value="<?= e($filter['date']) ?>" class="form-control" required></div>
          <div class="col-sm">
            <label for="bloques" class="form-label">Bloques consecutivos de una hora</label>
            <select id="bloques" name="blocks" class="form-select" required>
              <?php for ($count = 1; $count <= DemoPortal::MAX_BLOCKS; $count++): ?>
                <option value="<?= $count ?>" <?= $filter['blocks'] === $count ? 'selected' : '' ?>><?= $count === 1 ? '1 bloque · 1 hora' : e("$count bloques · $count horas") ?></option>
              <?php endfor; ?>
            </select>
          </div>
        </div>
        <button class="btn btn-success w-100"><?= icon('search') ?> Buscar horarios</button>
      </form>
    </section>
    <aside class="surface side"><h2>¿Cómo funciona?</h2><ol class="how"><li>Elige cancha y hora de inicio. La reserva cubre todos los bloques que seleccionaste.</li><li>Ingresa a tu cuenta y revisa el total.</li><li>Envía tu solicitud para que recepción la confirme.</li></ol>
      <?php if (in_array($filter['mode'], ['padel', 'tenis'], true)): ?>
        <p class="small mb-0">Canchas y tarifas de <?= $filter['mode'] === 'padel' ? 'pádel' : 'tenis' ?> de ejemplo, pendientes de confirmación.</p>
      <?php endif; ?>
    </aside>
  </div>
<?php elseif ($view === 'horarios'): ?>
  <?php
  $slots = $portal->availability($filter);
  $blockLabel = $filter['blocks'] === 1 ? '1 bloque de una hora' : $filter['blocks'] . ' bloques consecutivos';
  $selectedIndex = 0;
  foreach ($slots as $index => $item) {
      if ($selection && $item['court'] === $selection['court'] && $item['start'] === $selection['start']) {
          $selectedIndex = $index;
          break;
      }
  }
  $visibleSlots = 9;
  $activeSlot = $slots[$selectedIndex] ?? null;
  ?>
  <div class="page-heading"><div><h1><?= $slots ? 'Horarios disponibles' : 'No encontramos horarios disponibles' ?></h1>
    <p><?= e(DemoPortal::MODES[$filter['mode']]['label']) ?> · <?= e(dateLabel($filter['date'])) ?> · <?= e($blockLabel) ?></p></div>
    <a class="btn btn-outline-success" href="<?= e(url('buscar')) ?>"><?= icon('sliders') ?> Cambiar filtros</a>
  </div>
  <?php if ($slots): ?>
    <form method="post" class="split"><?= csrf() ?><input type="hidden" name="action" value="select">
      <section class="slot-list" aria-label="Horarios disponibles">
      <?php foreach ($slots as $i => $slot): ?>
        <?php if ($i === $visibleSlots): ?><details class="more-slots" <?= $selectedIndex >= $visibleSlots ? 'open' : '' ?>><summary>Ver <?= count($slots) - $visibleSlots ?> horarios más</summary><?php endif; ?>
        <label class="slot surface">
          <input type="radio" name="slot" value="<?= e($slot['court'] . '|' . $slot['start']) ?>"
              data-court="<?= e($slot['courtName'] . ' · ' . DemoPortal::SITES[$slot['site']]) ?>"
              data-time="<?= e($slot['start'] . '–' . $slot['end']) ?>" data-total="<?= e(money($slot['total'])) ?>"
              <?= $i === $selectedIndex ? 'checked' : '' ?> required>
          <span class="slot-icon"><?= icon('bullseye') ?></span><span><small>Cancha</small><strong><?= e($slot['courtName']) ?></strong></span>
          <span><small>Recinto</small><strong><?= e(DemoPortal::SITES[$slot['site']]) ?></strong></span>
          <span><small>Horario</small><strong><?= e($slot['start'] . '–' . $slot['end']) ?></strong></span>
          <span><small>Total</small><strong><?= e(money($slot['total'])) ?></strong></span>
        </label>
      <?php endforeach; ?>
      <?php if (count($slots) > $visibleSlots): ?></details><?php endif; ?>
      </section>
      <aside class="surface side summary"><h2>Resumen de reserva</h2>
        <p><?= e(DemoPortal::MODES[$filter['mode']]['label']) ?><br><?= e(dateLabel($filter['date'])) ?></p>
        <dl class="summary-data" aria-live="polite">
          <div><?= icon('geo-alt') ?><div><dt>Cancha y recinto</dt><dd id="selected-court"><?= e($activeSlot['courtName'] . ' · ' . DemoPortal::SITES[$activeSlot['site']]) ?></dd></div></div>
          <div><?= icon('clock') ?><div><dt>Horario</dt><dd id="selected-time"><?= e($activeSlot['start'] . '–' . $activeSlot['end']) ?></dd></div></div>
        </dl><div class="summary-total"><span>Total</span><strong id="selected-total"><?= e(money($activeSlot['total'])) ?></strong></div>
        <button class="btn btn-success w-100 mt-3">Continuar <?= icon('arrow-right') ?></button>
      </aside>
    </form>
  <?php else: ?>
    <section class="surface empty"><span class="sport-symbol"><?= icon('calendar-x') ?></span><h2>Prueba otra fecha o elige menos bloques</h2>
      <p>Recinto seleccionado · Las Rastras</p>
      <form method="post" class="actions"><?= csrf() ?><input type="hidden" name="action" value="nearby">
        <a class="btn btn-outline-success" href="<?= e(url('buscar')) ?>">Cambiar filtros</a>
        <button class="btn btn-success"><?= icon('calendar3') ?> Ver disponibilidad cercana</button>
      </form>
    </section>
  <?php endif; ?>
<?php endif; ?>
