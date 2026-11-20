let date = initialDay;
let venue = '';
let courtQuery = '';
function dateControls() {
  return `<div class="date-control" role="group" aria-label="Navegación por fecha">${button('previous', icon('chevron-left') + '<span class="visually-hidden">Día anterior</span>','btn btn-light')}
    <input type="date" value="${date}" id="date" class="form-control" aria-label="Fecha de la agenda">
    ${button('next', icon('chevron-right') + '<span class="visually-hidden">Día siguiente</span>', 'btn btn-light')}</div>
    ${button('today', 'Hoy', 'btn btn-light border')}`;
}
function timeline(rows, visibleCourts, day = date, tournamentId = null) {
  if (!visibleCourts.length) return '<p class="empty">No hay instalaciones que coincidan con la búsqueda.</p>';
  const windows = visibleCourts.flatMap(index => {
    const site = siteRecords.find(site => site.key === courts[index][1]);
    const hours = siteHours(site, weekdayIndex(day));
    return hours ? [hours] : [];
  });
  const bounds = [...windows, ...rows.map(row => [row.start, row.end])];
  const first = Math.floor(Math.min(480, ...bounds.map(([start]) => minutes(start))) / 60);
  const last = Math.ceil(Math.max(1320, ...bounds.map(([, end]) => minutes(end))) / 60);
  const durationGrid = (last - first) * 60;
  const marker = `data-now="${day}" data-first="${first * 60}" data-duration="${durationGrid}"`;
  const hours = Array.from({ length: last - first }, (_, i) => `<span>${String(i + first).padStart(2, '0')}:00</span>`).join('');
  const tracks = visibleCourts.map(court => {
    const [name, site, sport] = courts[court];
    const lanes = [];
    const events = rows.filter(row => row.court === court).map(row => {
      let lane = lanes.findIndex(end => end <= row.start);
      if (lane === -1) lane = lanes.length;
      lanes[lane] = row.end;
      const duration = minutes(row.end) - minutes(row.start);
      const left = (minutes(row.start) - first * 60) * 100 / durationGrid;
      const width = duration * 100 / durationGrid;
      const conflict = conflicts(row).length > 0;
      const tournament = isTournament(row);
      const title = tournament && tournamentId === row.tournamentId ? row.activity : row.client;
      const activeBlock = isActiveTournamentBlock(row);
      const eventClass = activeBlock ? 'tournament-block' : row.status;
      const modality = row.modality || (tournament ? tournaments[row.tournamentId].sport : sport);
      const summary = `${row.start}–${row.end} · ${title} · ${modality} · ${activeBlock ? 'Bloque de torneo' : statuses[row.status]}${conflict ? ' · Conflicto de horario' : ''}`;
      return `<button class="event ${eventClass}${duration <= 60 ? ' compact-event' : ''}${conflict ? ' conflict-event' : ''}" data-id="${row.id}"
        style="left:${left}%;width:calc(${width}% - 2px);top:${5 + lane * 45}px" title="${escapeHtml(summary)}" aria-label="${escapeHtml(summary)}">
        <span class="event-time">${icon(conflict ? 'exclamation-triangle-fill' : activeBlock ? 'trophy-fill' : statusIcons[row.status])} ${row.start}${duration > 60 ? `–${row.end}` : ''}</span>
        <strong>${escapeHtml(title)}</strong><span class="event-sport">${escapeHtml(tournament && tournamentId === null ? row.activity : modality)}</span></button>`;
    });
    return `<div class="agenda-row"><div class="court"><span>${escapeHtml(name)}</span><small>${escapeHtml(siteName(site))}</small></div><div class="track" style="min-height:${Math.max(1, lanes.length) * 45 + 10}px">${events.join('')}<span class="now-marker" ${marker} hidden></span></div></div>`;
  }).join('');
  return `<div class="agenda-scroll" tabindex="0" aria-label="Agenda por instalación"><div class="agenda-grid" style="--grid-hours:${last - first}"><div class="agenda-row"><div class="court">Instalación</div><div class="hours">${hours}<span class="now-marker now-heading" ${marker} hidden><b>Ahora</b></span></div></div>${tracks}</div></div>`;
}
function occupation(rows, visibleCourts) {
  const openByCourt = new Map(visibleCourts.map(court => {
    const site = siteRecords.find(entry => entry.key === courts[court][1]);
    const window = courtAvailable(court) && siteHours(site, weekdayIndex(date));
    return [court, window ? window.map(minutes) : null];
  }));
  const capacity = [...openByCourt.values()].reduce((total, window) => total + (window ? window[1] - window[0] : 0), 0);
  const occupied = new Set();
  for (const row of rows) {
    const window = openByCourt.get(row.court);
    if (!window) continue;
    for (let time = Math.max(window[0], minutes(row.start)); time < Math.min(window[1], minutes(row.end)); time++) {
      occupied.add(row.court * 1440 + time);
    }
  }
  return capacity ? Math.round(occupied.size / capacity * 100) : 0;
}
function updateClocks() {
  const [today, time] = localClock();
  document.querySelectorAll('[data-now]').forEach(marker => {
    const elapsed = minutes(time) - Number(marker.dataset.first);
    const duration = Number(marker.dataset.duration);
    marker.hidden = marker.dataset.now !== today || elapsed < 0 || elapsed >= duration;
    marker.style.left = `${elapsed * 100 / duration}%`;
    marker.title = `Ahora · ${time}`;
  });
  document.querySelectorAll('[data-expires]').forEach(item => {
    const remaining = Math.max(0, Math.ceil((Number(item.dataset.expires) - Date.now()) / 60000));
    item.textContent = remaining ? `Vence en ${remaining} min` : 'Expiró';
    item.classList.toggle('text-danger', remaining <= 10);
  });
}
function agenda(dayRows, visibleCourts) {
  const bookings = dayRows.filter(row => row.status !== 'maintenance' && row.status !== 'cancelled');
  const pending = bookings.filter(row => row.status === 'pending').sort((a, b) => deadlines.get(a.id) - deadlines.get(b.id));
  const completed = bookings.filter(row => row.status === 'completed');
  const list = pending.map(row => {
    const conflict = conflicts(row).length > 0;
    return `<div class="queue-item"><div class="d-flex flex-wrap justify-content-between gap-1"><strong>${escapeHtml(row.client)}</strong><span class="expiry small fw-semibold" data-expires="${deadlines.get(row.id)}"></span></div>
      <div class="small text-secondary mb-2">${row.start} · ${escapeHtml(courts[row.court][0])}</div>
      <div class="d-flex flex-wrap gap-2">${conflict ? button(`resolve-${row.id}`, `${icon('exclamation-triangle')} Resolver cruce`, 'btn-outline-danger btn-sm') : button(`confirm-${row.id}`, 'Confirmar', 'btn-accent btn-sm')}${button(`ask-cancel-${row.id}`, 'Cancelar', 'btn-outline-secondary btn-sm')}</div></div>`;
  }).join('');
  const venueOptions = selectOption('', 'Todos los recintos', !venue) +
    siteRecords.map(site => selectOption(site.key, site.name, venue === site.key)).join('');
  return `${heading('Agenda y operación', '', button('new', `${icon('plus-lg')} Nueva reserva`, 'btn-accent'))}
    <div class="row g-2 mb-3">
      ${metric('calendar2-check', 'Reservas del día', bookings.filter(row => !isTournament(row)).length)}
      ${metric('hourglass-split', 'Por confirmar', pending.length)}
      ${metric('pie-chart', 'Ocupación del día', `${occupation(bookings, visibleCourts)}%`)}
      ${metric('check2-all', 'Reservas completadas', completed.length)}
    </div>
    <div class="row g-3 mb-3">
      <div class="col-12 col-xl-9">${card('Agenda de instalaciones', `
        <div class="card-body border-bottom agenda-tools"><div class="toolbar">${dateControls()}<select id="venue" class="form-select" aria-label="Filtrar por recinto">${venueOptions}</select>
        <input type="search" id="court-query" class="form-control court-search" aria-label="Buscar instalación" placeholder="Buscar instalación" value="${escapeHtml(courtQuery)}"></div>
        <div class="d-flex flex-wrap justify-content-between gap-2 mt-2"><strong class="small agenda-date">${dateLabel.format(new Date(date + 'T12:00:00'))}</strong><div class="legend">${Object.keys(statuses).map(badge).join('')}${tournamentBadge()}</div></div></div>
        ${timeline(dayRows, visibleCourts)}${visibleCourts.length && !dayRows.length ? '<p class="empty">No hay reservas ni mantenciones para esta selección.</p>' : ''}`)}</div>
      <div class="col-12 col-xl-3">${card('Reservas por confirmar', `<div class="card-body py-1">${list || '<p class="empty px-0">Todo al día para esta selección.</p>'}</div>`)}</div>
    </div>
    <div class="row"><div class="col-12">${card('Próximos torneos', `<div class="card-body">${tournamentCards(false)}</div>`, '<a class="btn btn-sm btn-light border ms-auto" href="#torneos">Ir a torneos <i class="bi bi-arrow-right" aria-hidden="true"></i></a>')}</div></div>`;
}
