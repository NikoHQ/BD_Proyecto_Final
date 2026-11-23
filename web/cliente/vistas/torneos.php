<?php
if (!isset($tournamentPage)) {
    http_response_code(404);
    return;
}
extract($tournamentPage, EXTR_SKIP);

function tournamentStateBadge(array $tournament): string
{
    [$label, $style] = match ($tournament['state']) {
        'EN_CURSO' => ['En curso', 'pendiente'],
        'FINALIZADO' => ['Finalizado', 'completada'],
        'CANCELADO' => ['Cancelado', 'cancelada'],
        default => ['Próximamente', 'completada'],
    };
    return '<span class="status ' . $style . '">' . $label . '</span>';
}

function tournamentRegistrationBadge(array $tournament): string
{
    [$label, $style] = match ($tournament['registration']) {
        'OPEN' => ['Inscripciones abiertas', 'confirmada'],
        'FULL' => ['Cupos completos', 'pendiente'],
        'UNSCHEDULED' => ['Programación pendiente', 'pendiente'],
        default => ['Inscripciones cerradas', 'completada'],
    };
    return '<span class="status ' . $style . '">' . $label . '</span>';
}

function tournamentDateRange(array $days): string
{
    $first = dateLabel($days[0]);
    return count($days) === 1 ? $first : $first . ' al ' . dateLabel($days[array_key_last($days)]);
}

function tournamentCapacity(array $tournament): string
{
    return $tournament['teams'] . ' de ' . $tournament['capacity'] . ' equipos inscritos';
}

function tournamentRoster(array $players): void
{
    ?>
    <ol class="list-group list-group-numbered tournament-roster">
    <?php foreach ($players as $i => $player): ?>
      <li class="list-group-item d-flex align-items-start gap-2">
        <div class="flex-grow-1"><strong><?= e($player['name']) ?></strong> <span class="d-block small text-secondary"><?= e($player['rut']) ?></span></div>
        <?php if ($i === 0): ?><span class="status confirmada">Capitán</span><?php endif; ?>
      </li>
    <?php endforeach; ?>
    </ol>
    <?php
}

function tournamentPlayerFields(int $position, array $player, string $nameError = '', string $rutError = ''): void
{
    ?>
    <fieldset class="player-fields mb-3 p-3 rounded-3" data-tournament-player>
      <legend class="float-none fw-semibold fs-6 mb-2" data-player-legend>Compañero <?= $position ?></legend>
      <div class="row g-2">
        <label class="col-md-7">
          <span class="form-label d-block">Nombre completo</span>
          <input class="form-control <?= $nameError ? 'is-invalid' : '' ?>" name="player_name[]" value="<?= e($player['name']) ?>" maxlength="100" autocomplete="off" <?= $nameError ? 'aria-invalid="true" aria-describedby="player-name-error-' . $position . '"' : '' ?> required>
          <?php if ($nameError): ?><span class="invalid-feedback" id="player-name-error-<?= $position ?>"><?= e($nameError) ?></span><?php endif; ?>
        </label>
        <label class="col-md">
          <span class="form-label d-block">RUT</span>
          <input class="form-control <?= $rutError ? 'is-invalid' : '' ?>" name="player_rut[]" value="<?= e($player['rut']) ?>" maxlength="16" placeholder="12.345.678-5" autocomplete="off" <?= $rutError ? 'aria-invalid="true" aria-describedby="player-rut-error-' . $position . '"' : '' ?> required>
          <?php if ($rutError): ?><span class="invalid-feedback" id="player-rut-error-<?= $position ?>"><?= e($rutError) ?></span><?php endif; ?>
        </label>
      </div>
      <button type="button" class="btn btn-link text-danger p-0 mt-2" data-tournament-remove>Quitar compañero</button>
    </fieldset>
    <?php
}

function tournamentFacts(array $tournament): void
{
    ?>
    <dl class="summary-data">
      <div><?= icon('geo-alt') ?><div><dt>Recinto</dt><dd><?= e($tournament['siteName']) ?></dd></div></div>
      <div><?= icon('bullseye') ?><div><dt>Modalidad</dt><dd><?= e($tournament['sport']) ?></dd></div></div>
      <div><?= icon('calendar3') ?><div><dt>Fechas</dt><dd><?= e(tournamentDateRange($tournament['days'])) ?></dd></div></div>
      <div><?= icon('people') ?><div><dt>Plantilla</dt><dd><?= $tournament['teamSize'] === 1 ? 'Individual' : 'Hasta ' . e($tournament['teamSize']) . ' jugadores por equipo, incluido el capitán' ?></dd></div></div>
    </dl>
    <?php
}
?>

<?php if ($view === 'torneos'): ?>
  <?php
    $sportFilter = tournamentQuery('modalidad');
    $siteFilter = tournamentQuery('recinto');
    $openOnly = tournamentQuery('abiertos') === '1';
    $sports = array_values(array_unique(array_column($catalog, 'sport')));
    sort($sports, SORT_NATURAL | SORT_FLAG_CASE);
    $sites = array_column($catalog, 'siteName', 'site');
    asort($sites, SORT_NATURAL | SORT_FLAG_CASE);
    $visible = array_filter($catalog, static fn(array $item): bool =>
        ($sportFilter === '' || $item['sport'] === $sportFilter) &&
        ($siteFilter === '' || (string) $item['site'] === $siteFilter) &&
        (!$openOnly || $item['registration'] === 'OPEN'));
  ?>
  <div class="page-heading">
    <div><h1>Torneos</h1><p>Consulta las fechas, los cupos y la plantilla requerida.</p></div>
    <a class="btn btn-outline-success" href="<?= e(url('mis-inscripciones')) ?>"><?= icon('ticket-perforated') ?> Mis inscripciones</a>
  </div>
  <?php if ($catalog): ?>
    <form method="get" action="/" class="surface mb-3">
      <input type="hidden" name="vista" value="torneos">
      <div class="row g-3 align-items-end">
        <div class="col-md"><label class="form-label" for="tour-sport">Modalidad</label>
          <select class="form-select" id="tour-sport" name="modalidad"><option value="">Todas las modalidades</option>
          <?php foreach ($sports as $sport): ?><option value="<?= e($sport) ?>" <?= $sport === $sportFilter ? 'selected' : '' ?>><?= e($sport) ?></option><?php endforeach; ?>
          </select>
        </div>
        <div class="col-md"><label class="form-label" for="tour-site">Recinto</label>
          <select class="form-select" id="tour-site" name="recinto"><option value="">Todos los recintos</option>
          <?php foreach ($sites as $siteKey => $site): ?><option value="<?= e($siteKey) ?>" <?= (string) $siteKey === $siteFilter ? 'selected' : '' ?>><?= e($site) ?></option><?php endforeach; ?>
          </select>
        </div>
        <div class="col-md-auto"><div class="form-check py-2">
          <input class="form-check-input" type="checkbox" id="tour-open" name="abiertos" value="1" <?= $openOnly ? 'checked' : '' ?>>
          <label class="form-check-label" for="tour-open">Sólo inscripciones abiertas</label>
        </div></div>
        <div class="col-md-auto"><button class="btn btn-success"><?= icon('funnel') ?> Filtrar</button>
          <?php if ($sportFilter || $siteFilter || $openOnly): ?><a class="btn btn-link" href="<?= e(url('torneos')) ?>">Limpiar</a><?php endif; ?>
        </div>
      </div>
    </form>
  <?php endif; ?>
  <?php if ($visible): ?>
    <div class="tournament-grid">
      <?php foreach ($visible as $item): ?>
        <article class="surface tournament-tile">
          <div class="d-flex flex-wrap gap-2 align-items-center"><span class="slot-icon"><?= icon('trophy') ?></span><?= tournamentStateBadge($item) ?></div>
          <h2 class="mb-1"><?= e($item['name']) ?></h2>
          <p class="mb-0"><?= e($item['sport'] . ' · ' . $item['siteName']) ?><br><?= e(tournamentDateRange($item['days'])) ?></p>
          <strong><?= e(tournamentCapacity($item)) ?></strong>
          <small><?= $item['teamSize'] === 1 ? 'Inscripción individual' : 'Hasta ' . e($item['teamSize']) . ' jugadores por equipo' ?></small>
          <div><?= tournamentRegistrationBadge($item) ?></div>
          <a class="btn btn-outline-success mt-auto align-self-start" href="<?= e(url('torneo', ['torneo' => $item['id']])) ?>">Ver torneo <?= icon('arrow-right') ?></a>
        </article>
      <?php endforeach; ?>
    </div>
  <?php else: ?>
    <section class="surface empty"><span class="sport-symbol"><?= icon('trophy') ?></span>
      <h2><?= !empty($unavailable) ? 'No pudimos cargar los torneos' : ($catalog ? 'No encontramos torneos con estos filtros' : 'Aún no hay torneos programados') ?></h2>
      <?php if (!empty($unavailable)): ?><a href="<?= e(url('torneos')) ?>">Volver a intentar</a>
      <?php elseif ($catalog): ?><a href="<?= e(url('torneos')) ?>">Ver todos los torneos</a><?php endif; ?>
    </section>
  <?php endif; ?>

<?php elseif ($view === 'torneo'): ?>
  <div class="page-heading">
    <div><a class="d-inline-block mb-2" href="<?= e(url('torneos')) ?>">← Volver a torneos</a><h1><?= e($tournament['name']) ?></h1>
      <div class="d-flex flex-wrap gap-2"><?= tournamentStateBadge($tournament) ?> <?= tournamentRegistrationBadge($tournament) ?></div>
    </div>
  </div>
  <div class="split">
    <section class="surface">
      <h2>Horario del torneo</h2>
      <?php if (!$tournament['blocks']): ?><p class="mb-0">El recinto aún está preparando la programación.</p><?php endif; ?>
      <?php foreach ($tournament['blocks'] as $block): ?>
        <div class="history-row">
          <div><strong><?= e($block['activity'] ?: $block['courtName']) ?></strong><p class="mb-0"><?= e(dateLabel($block['date'])) ?> · <?= e($block['courtName']) ?></p></div>
          <strong><?= e($block['start'] . '–' . $block['end']) ?></strong>
        </div>
      <?php endforeach; ?>
    </section>
    <aside class="surface">
      <h2>Inscripción</h2>
      <?php tournamentFacts($tournament); ?>
      <div class="mt-3">
        <p class="mb-1"><strong><?= e(tournamentCapacity($tournament)) ?></strong></p>
        <?php if ($tournament['registration'] === 'OPEN'): ?><p><?= e($tournament['remaining']) ?> <?= $tournament['remaining'] === 1 ? 'cupo disponible' : 'cupos disponibles' ?></p><?php endif; ?>
        <?php if ($tournament['deadline'] && in_array($tournament['registration'], ['OPEN', 'FULL'], true)): ?>
          <p>Cierre de inscripciones el <?= e(dateLabel(substr($tournament['deadline'], 0, 10))) ?> a las <?= e(substr($tournament['deadline'], 11, 5)) ?>.</p>
        <?php endif; ?>
        <?php if ($activeTeam): ?>
          <a class="btn btn-success w-100" href="<?= e(url('torneo-inscripcion', ['torneo' => $tournament['id'], 'equipo' => $activeTeam['id']])) ?>">Ver mi inscripción</a>
        <?php elseif ($tournament['registration'] === 'OPEN'): ?>
          <a class="btn btn-success w-100" href="<?= e(url('torneo-equipo', ['torneo' => $tournament['id']])) ?>"><?= $tournament['teamSize'] === 1 ? 'Inscribirme' : 'Inscribir equipo' ?></a>
        <?php else: ?>
          <p class="mb-0"><?= e(match ($tournament['registration']) {
              'FULL' => 'Ya se ocuparon todos los cupos de este torneo.',
              'UNSCHEDULED' => 'Las inscripciones abrirán cuando se programe una cancha.',
              default => 'Este torneo ya no recibe inscripciones.',
          }) ?></p>
        <?php endif; ?>
      </div>
    </aside>
  </div>

<?php elseif ($view === 'torneo-equipo' || $view === 'torneo-revisar'): ?>
  <?php
    $reviewing = $view === 'torneo-revisar';
    $solo = $draft['size'] === 1;
  ?>
  <div class="page-heading"><div>
    <a class="d-inline-block mb-2" href="<?= e($team ? url('torneo-inscripcion', $route) : url('torneo', ['torneo' => $tournament['id']])) ?>">← <?= $team ? 'Volver a mi inscripción' : 'Volver al torneo' ?></a>
    <h1><?= $reviewing ? 'Revisa tu inscripción' : ($team ? 'Editar equipo' : ($solo ? 'Inscripción individual' : 'Completa tu equipo')) ?></h1>
    <p><?= e($tournament['name']) ?></p>
  </div></div>
  <div class="split">
    <section class="surface">
      <?php if ($formError !== ''): ?><p class="alert alert-danger" role="alert"><?= e($formError) ?></p><?php endif; ?>
      <?php if ($reviewing): ?>
        <h2><?= e($draft['review']['name']) ?></h2>
        <?php tournamentRoster($draft['review']['players']); ?>
        <form method="post" action="<?= e(url('torneo-revisar', $route)) ?>" class="actions mt-3" data-once>
          <?= csrf() ?><input type="hidden" name="action" value="tournament-confirm">
          <input type="hidden" name="draft_key" value="<?= e($draft['reviewKey']) ?>">
          <button class="btn btn-success"><?= $team ? 'Guardar cambios' : 'Confirmar inscripción' ?></button>
          <a class="btn btn-outline-success" href="<?= e(url('torneo-equipo', $route)) ?>">Volver a editar</a>
        </form>
      <?php else: ?>
        <div class="mode-strip mb-3"><?= icon('person-badge') ?><div><strong><?= e($profile['name']) ?></strong><small class="d-block"><?= e($profile['rut']) ?> · Capitán</small></div></div>
        <form method="post" action="<?= e(url('torneo-equipo', $route)) ?>" data-tournament-roster data-roster-maximum="<?= $draft['size'] ?>">
          <?= csrf() ?><input type="hidden" name="action" value="tournament-review">
          <input type="hidden" name="draft_key" value="<?= e($draft['key']) ?>">
          <?php if (!$solo): ?>
            <div class="mb-4"><label for="team_name" class="form-label">Nombre del equipo</label>
              <input id="team_name" name="team_name" class="form-control <?= isset($fieldErrors['team_name']) ? 'is-invalid' : '' ?>" type="text" maxlength="100" value="<?= e($draft['name']) ?>" <?= isset($fieldErrors['team_name']) ? 'aria-invalid="true" aria-describedby="team-name-error"' : '' ?> required>
              <?php if (isset($fieldErrors['team_name'])): ?><div class="invalid-feedback" id="team-name-error"><?= e($fieldErrors['team_name']) ?></div><?php endif; ?>
            </div>
          <?php endif; ?>
          <?php if (!$solo || $draft['players']): ?>
            <h2>Compañeros</h2>
            <?php if (!$solo): ?><p>Puedes inscribirte solo o agregar compañeros con su nombre y RUT.</p><?php endif; ?>
            <?php $entered = 1; ?>
            <div data-tournament-players>
              <?php foreach ($draft['players'] as $i => $player): ?>
                <?php
                  if ($player['name'] !== '' && $player['rut'] !== '') $entered++;
                  tournamentPlayerFields($i + 1, $player, $fieldErrors['name'][$i] ?? '', $fieldErrors['rut'][$i] ?? '');
                ?>
              <?php endforeach; ?>
            </div>
            <template data-tournament-player-template><?php tournamentPlayerFields(1, ['name' => '', 'rut' => '']); ?></template>
            <p class="small" aria-live="polite"><span data-tournament-count><?= $entered ?></span> de <?= $draft['size'] ?> jugadores como máximo</p>
            <button type="button" class="btn btn-outline-success mb-3" data-tournament-add <?= $solo ? 'hidden' : '' ?>
              <?= count($draft['players']) + 1 >= $draft['size'] ? 'disabled' : '' ?>><?= icon('person-plus') ?> Agregar compañero</button>
          <?php else: ?><p>Esta modalidad es individual. Tu cuenta ocupa el único lugar de la plantilla.</p><?php endif; ?>
          <button type="submit" class="btn btn-success"><?= $team ? 'Revisar cambios' : 'Revisar inscripción' ?> <?= icon('arrow-right') ?></button>
        </form>
      <?php endif; ?>
    </section>
    <aside class="surface"><h2>Datos del torneo</h2><?php tournamentFacts($tournament); ?></aside>
  </div>

<?php elseif ($view === 'mis-inscripciones'): ?>
  <div class="page-heading"><div><h1>Mis inscripciones</h1><p>Consulta tus equipos y su historial en los torneos.</p></div>
    <a class="btn btn-success" href="<?= e(url('torneos')) ?>">Explorar torneos</a>
  </div>
  <?php if ($entries): ?>
    <section class="surface">
      <?php foreach ($entries as $entry): ?>
        <?php $event = tournamentById($catalog, (string) $entry['tournamentId']); if (!$event) continue; ?>
        <article class="history-row">
          <div><strong><?= e($entry['name']) ?></strong><p class="mb-0"><?= e($event['name']) ?> · <?= e(tournamentDateRange($event['days'])) ?></p></div>
          <?= tournamentStateBadge($event) ?>
          <span class="status <?= $entry['withdrawn'] ? 'cancelada' : 'confirmada' ?>"><?= $entry['withdrawn'] ? 'Retirado' : 'Inscrito' ?></span>
          <a href="<?= e(url('torneo-inscripcion', ['torneo' => $event['id'], 'equipo' => $entry['id']])) ?>">Ver inscripción<span class="visually-hidden"> de <?= e($entry['name']) ?></span></a>
        </article>
      <?php endforeach; ?>
    </section>
  <?php else: ?>
    <section class="surface empty"><span class="sport-symbol"><?= icon('trophy') ?></span><h2>Aún no tienes inscripciones</h2><p class="mb-0">Los torneos en los que participes aparecerán aquí.</p></section>
  <?php endif; ?>

<?php else: ?>
  <?php $receipt = $view === 'torneo-inscrito'; ?>
  <div class="page-heading"><div>
    <h1><?= $receipt ? 'Inscripción guardada' : 'Detalle de inscripción' ?></h1>
    <p>Código <strong><?= e($team['id']) ?></strong> · <span class="status <?= $team['withdrawn'] ? 'cancelada' : 'confirmada' ?>"><?= $team['withdrawn'] ? 'Retirado' : 'Inscrito' ?></span></p>
  </div><a class="btn btn-outline-success" href="<?= e(url('mis-inscripciones')) ?>">Mis inscripciones</a></div>
  <div class="split">
    <section class="surface">
      <h2><?= e($team['name']) ?></h2>
      <?php tournamentRoster($team['players']); ?>
      <?php if (!$team['withdrawn'] && tournamentCanEdit($tournament)): ?>
        <div class="actions align-items-start mt-3">
          <a class="btn btn-outline-success" href="<?= e(url('torneo-equipo', $route)) ?>">Editar equipo</a>
          <details class="withdraw-team">
            <summary class="btn btn-outline-danger">Retirar equipo</summary>
            <p class="mt-2 mb-2">Se liberará el cupo de este equipo. El retiro quedará en tu historial.</p>
            <form method="post" action="<?= e(url('torneo-inscripcion', $route)) ?>"><?= csrf() ?><input type="hidden" name="action" value="tournament-withdraw"><button class="btn btn-danger">Confirmar retiro</button></form>
          </details>
        </div>
      <?php endif; ?>
    </section>
    <aside class="surface"><h2><?= e($tournament['name']) ?></h2><?= tournamentStateBadge($tournament) ?><?php tournamentFacts($tournament); ?></aside>
  </div>
<?php endif; ?>
