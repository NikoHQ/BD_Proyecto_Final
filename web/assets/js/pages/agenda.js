'use strict';

let date = initialDay;
let venue = '';
let courtQuery = '';

function dateControls() {
  return `<div class="date-control" role="group" aria-label="Navegación por fecha">${button('previous', icon('chevron-left') + '<span class="visually-hidden">Día anterior</span>', 'btn btn-light')}
    <input type="date" value="${date}" id="date" class="form-control" aria-label="Fecha de la agenda">
    ${button('next', icon('chevron-right') + '<span class="visually-hidden">Día siguiente</span>', 'btn btn-light')}</div>
    ${button('today', 'Hoy', 'btn btn-light border')}`;
}

function canchasVisibles() {
  const texto = normalizeName(courtQuery);
  return panel.canchas.filter(cancha =>
    cancha.estado !== 'INACTIVA' &&
    (!venue || String(cancha.recinto) === String(venue)) &&
    (!texto || normalizeName(`${cancha.nombre} ${nombreRecinto(cancha.recinto)}`).includes(texto))
  );
}

const reservasDelDia = day => reservasPanel().filter(row => row.fecha === day);

function ventanaDelDia(cancha, day) {
  return horarioDe(cancha.recinto, diaSemanaIso(day));
}

function timeline(rows, canchas) {
  if (!canchas.length) return '<p class="empty">No hay instalaciones que coincidan con la búsqueda.</p>';
  const windows = canchas.flatMap(cancha => {
    const horas = ventanaDelDia(cancha, date);
    return horas ? [horas] : [];
  });
  const bounds = [...windows, ...rows.map(row => [row.start, row.end])];
  const first = Math.floor(Math.min(480, ...bounds.map(([start]) => minutes(start))) / 60);
  const last = Math.ceil(Math.max(1320, ...bounds.map(([, end]) => minutes(end))) / 60);
  const durationGrid = (last - first) * 60;
  const marker = `data-now="${date}" data-first="${first * 60}" data-duration="${durationGrid}"`;
  const hours = Array.from({ length: last - first }, (_, i) => `<span>${String(i + first).padStart(2, '0')}:00</span>`).join('');
  const tracks = canchas.map(cancha => {
    const lanes = [];
    const eventos = rows.filter(row => row.canchaId === cancha.id ||
      (row.estado !== 'cancelled' && compartenEspacio(row.canchaId, cancha.id))).map(row => {
      let lane = lanes.findIndex(end => end <= row.start);
      if (lane === -1) lane = lanes.length;
      lanes[lane] = row.end;
      const duration = minutes(row.end) - minutes(row.start);
      const left = (minutes(row.start) - first * 60) * 100 / durationGrid;
      const width = duration * 100 / durationGrid;
      const torneo = Boolean(row.torneoId);
      const compartida = row.canchaId !== cancha.id;
      const title = compartida ? 'Ocupada por ' + canchaPorId(row.canchaId).nombre
        : torneo ? row.torneo : row.cliente;
      const eventClass = torneo ? 'tournament-block' : row.estado;
      const summary = `${row.start}–${row.end} · ${title} · ${row.modalidad} · ${statuses[row.estado]}`;
      return `<button class="event ${eventClass}${duration <= 60 ? ' compact-event' : ''}" data-id="${row.id}"
        style="left:${left}%;width:calc(${width}% - 2px);top:${5 + lane * 45}px" title="${escapeHtml(summary)}" aria-label="${escapeHtml(summary)}">
        <span class="event-time">${icon(torneo ? 'trophy-fill' : statusIcons[row.estado])} ${row.start}${duration > 60 ? `–${row.end}` : ''}</span>
        <strong>${escapeHtml(title)}</strong><span class="event-sport">${escapeHtml(row.modalidad)}</span></button>`;
    });
    return `<div class="agenda-row"><div class="court"><span>${escapeHtml(cancha.nombre)}</span><small>${escapeHtml(nombreRecinto(cancha.recinto))}</small></div><div class="track" style="min-height:${Math.max(1, lanes.length) * 45 + 10}px">${eventos.join('')}<span class="now-marker" ${marker} hidden></span></div></div>`;
  }).join('');
  return `<div class="agenda-scroll" tabindex="0" aria-label="Agenda por instalación"><div class="agenda-grid" style="--grid-hours:${last - first}"><div class="agenda-row"><div class="court">Instalación</div><div class="hours">${hours}<span class="now-marker now-heading" ${marker} hidden><b>Ahora</b></span></div></div>${tracks}</div></div>`;
}

function ocupacion(rows, canchas) {
  let capacidad = 0;
  let usados = 0;
  for (const cancha of canchas) {
    const ventana = ventanaDelDia(cancha, date);
    if (!ventana) continue;
    const [abre, cierra] = ventana.map(minutes);
    capacidad += cierra - abre;
    for (const row of rows.filter(entry => entry.canchaId === cancha.id)) {
      usados += Math.max(0, Math.min(cierra, minutes(row.end)) - Math.max(abre, minutes(row.start)));
    }
  }
  return capacidad ? Math.round(usados / capacidad * 100) : 0;
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
}

function proximosTorneos() {
  const torneos = panel.torneos.filter(torneo => torneo.estado === 'PLANIFICADO' || torneo.estado === 'EN_CURSO');
  if (!torneos.length) return '<p class="empty px-0 mb-0">No hay torneos planificados.</p>';
  return `<div class="row g-2">${torneos.slice(0, 4).map(torneo => `
    <div class="col-12 col-md-6"><div class="border rounded p-3 h-100">
      <div class="d-flex justify-content-between gap-2"><strong>${escapeHtml(torneo.nombre)}</strong><span class="status ${torneo.estado === 'EN_CURSO' ? 'confirmed' : 'pending'}">${torneo.estado === 'EN_CURSO' ? 'En curso' : 'Planificado'}</span></div>
      <div class="small text-secondary mt-1">${escapeHtml(torneo.modalidad.nombre)} · ${torneo.inicio} al ${torneo.termino}</div>
      <div class="small mt-2">${icon('people')} ${torneo.inscritos} de ${torneo.cupos} cupos</div>
    </div></div>`).join('')}</div>`;
}

function agenda() {
  const canchas = canchasVisibles();
  const rows = reservasDelDia(date).sort((a, b) => a.start.localeCompare(b.start));
  const normales = rows.filter(row => !row.torneoId && row.estado !== 'cancelled');
  const pendientes = rows.filter(row => row.estado === 'pending');
  const completadas = normales.filter(row => row.estado === 'completed');
  const lista = pendientes.map(row => `<div class="queue-item">
      <div class="d-flex flex-wrap justify-content-between gap-1"><strong>${escapeHtml(row.cliente)}</strong><span class="small fw-semibold">${escapeHtml(statuses.pending)}</span></div>
      <div class="small text-secondary mb-2">${row.start} · ${escapeHtml(row.cancha)}</div>
      <div class="d-flex flex-wrap gap-2">${document.body.dataset.accountRole === 'ADMINISTRADOR' ? button(`confirm-${row.id}`, 'Confirmar', 'btn-accent btn-sm') : ''}${button(`ask-cancel-${row.id}`, 'Cancelar', 'btn-outline-secondary btn-sm')}</div></div>`).join('');
  const venueOptions = selectOption('', 'Todas las sucursales', !venue) +
    panel.recintos.map(recinto => selectOption(recinto.id, recinto.nombre, String(venue) === String(recinto.id))).join('');
  return `${heading('Agenda y operación', '', button('new', `${icon('plus-lg')} Nueva reserva`, 'btn-accent'))}
    <div class="row g-2 mb-3">
      ${metric('calendar2-check', 'Reservas del día', normales.length)}
      ${metric('hourglass-split', 'Por confirmar', pendientes.length)}
      ${metric('pie-chart', 'Ocupación del día', `${ocupacion(normales, canchas)}%`)}
      ${metric('check2-all', 'Reservas completadas', completadas.length)}
    </div>
    <div class="row g-3 mb-3">
      <div class="col-12 col-xl-9">${card('Agenda de instalaciones', `
        <div class="card-body border-bottom agenda-tools"><div class="toolbar">${dateControls()}<select id="venue" class="form-select" aria-label="Filtrar por sucursal">${venueOptions}</select>
        <input type="search" id="court-query" class="form-control court-search" aria-label="Buscar instalación" placeholder="Buscar instalación" value="${escapeHtml(courtQuery)}"></div>
        <div class="d-flex flex-wrap justify-content-between gap-2 mt-2"><strong class="small agenda-date">${dateLabel.format(new Date(date + 'T12:00:00'))}</strong><div class="legend">${Object.keys(statuses).map(badge).join('')}${tournamentBadge()}</div></div></div>
        ${timeline(rows, canchas)}${canchas.length && !rows.length ? '<p class="empty">No hay reservas para esta selección.</p>' : ''}`)}</div>
      <div class="col-12 col-xl-3">${card('Reservas por confirmar', `<div class="card-body py-1">${lista || '<p class="empty px-0">Todo al día para esta selección.</p>'}</div>`)}</div>
    </div>
    <div class="row"><div class="col-12">${card('Próximos torneos', `<div class="card-body">${proximosTorneos()}</div>`, '<a class="btn btn-sm btn-light border ms-auto" href="#torneos">Ir a torneos <i class="bi bi-arrow-right" aria-hidden="true"></i></a>')}</div></div>`;
}
