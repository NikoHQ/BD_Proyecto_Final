<?php if ($view === 'ayuda'): ?>
  <section class="surface narrow"><h1>Ayuda</h1>
    <h2>¿Cuándo queda confirmada mi reserva?</h2><p>Cuando recepción confirma la solicitud. Conserva tu código para consultarla.</p>
    <h2>¿Cómo veo mis reservas?</h2><p>Inicia sesión y abre Mis reservas para consultar tus solicitudes y su estado.</p>
    <details class="mt-4"><summary>Controles de la demo</summary>
      <form method="post" class="mt-3"><?= csrf() ?><input type="hidden" name="action" value="scenario">
        <label for="caso" class="form-label">Simular en el próximo envío</label>
        <select name="scenario" id="caso" class="form-select mb-2">
          <?php foreach (['' => 'Flujo normal','SLOT_TAKEN' => 'Horario ocupado','PRICE_CHANGED' => 'Cambio de tarifa','SESSION_EXPIRED' => 'Sesión vencida','UNAVAILABLE' => 'Error temporal'] as $key => $label): ?>
            <option value="<?= e($key) ?>" <?= $portal->scenario === $key ? 'selected' : '' ?>><?= e($label) ?></option>
          <?php endforeach; ?>
        </select><button class="btn btn-outline-success">Preparar escenario</button>
      </form>
      <form method="post" class="mt-3"><?= csrf() ?><input type="hidden" name="action" value="reset"><button class="btn btn-outline-danger">Reiniciar esta demo</button></form>
    </details>
  </section>
<?php endif; ?>
