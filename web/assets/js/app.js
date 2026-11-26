'use strict';

// Navegación, montaje y delegación de eventos del panel.
const pages = {
  agenda: ['Agenda', 'calendar3'], reservas: ['Reservas', 'journal-check'],
  clientes: ['Clientes', 'people'], pagos: ['Pagos', 'credit-card'],
  torneos: ['Torneos', 'trophy'], reportes: ['Reportes', 'bar-chart'],
  instalaciones: ['Recintos', 'geo-alt'], tarifas: ['Tarifas', 'tags']
};

function panelRoute() {
  const hash = location.hash.slice(1);
  const nested = /^instalaciones\/canchas\/(\d+)(?:\/tarifas\/(\d+))?$/.exec(hash);
  if (nested) {
    const site = recintoPorId(nested[1]);
    const court = nested[2] === undefined ? null : Number(nested[2]);
    if (site && court !== null && canchaPorId(court)?.recinto === site.id) {
      return { page: 'tarifas', site, court };
    }
    if (site) return { page: 'instalaciones', site };
  }
  return { page: nested ? 'instalaciones' : Object.hasOwn(pages, hash) ? hash : 'agenda' };
}
const activePage = () => panelRoute().page;
const courtRoute = site => '#instalaciones/canchas/' + site.id;
let lastPanelHash;

function syncPanelRoute(route) {
  if (lastPanelHash === location.hash) return;
  lastPanelHash = location.hash;
  const { page, site, court } = route;
  const facilities = managementState.instalaciones;
  if (page === 'instalaciones') {
    Object.assign(facilities, {
      filters: site ? { kind: 'courts', site: site.id } : {},
      selected: site ? null : facilities.lastSite ?? null,
      page: 1
    });
    if (site) facilities.lastSite = site.id;
  }
  if (page === 'tarifas') {
    Object.assign(managementState.tarifas, {
      filters: site ? { court: String(court) } : {}, selected: null, page: 1
    });
  }
}

function renderBreadcrumb({ page, site, court }) {
  const crumbs = [['Administración', '#agenda']];
  if (site) {
    crumbs.push(['Recintos', '#instalaciones'], ['Canchas de ' + site.nombre, courtRoute(site)]);
    if (page === 'tarifas') crumbs.push(['Tarifas · ' + canchaPorId(court).nombre, '']);
  } else {
    crumbs.push([pages[page][0], '']);
  }
  $('current-section').innerHTML = crumbs.map(([label, href], index) =>
    index === crumbs.length - 1
      ? '<li class="breadcrumb-item active" aria-current="page">' + escapeHtml(label) + '</li>'
      : '<li class="breadcrumb-item"><a href="' + href + '">' + escapeHtml(label) + '</a></li>'
  ).join('');
}

function pantallaCargando(mensaje = 'Consultando Oracle…') {
  return `<div class="d-flex align-items-center gap-2 py-5 text-secondary" role="status">
    <span class="spinner-border spinner-border-sm" aria-hidden="true"></span><span>${escapeHtml(mensaje)}</span></div>`;
}

function pantallaError(error) {
  return `<div class="alert alert-danger d-flex flex-wrap align-items-center justify-content-between gap-2" role="alert">
    <span><strong>No se pudo cargar la pantalla.</strong> ${escapeHtml(error?.message || 'Revisa la conexión con Oracle.')}</span>
    ${button('retry', 'Reintentar', 'btn btn-light border btn-sm')}</div>`;
}

let renderSeq = 0;

async function render() {
  const seq = ++renderSeq;
  $('screen').querySelectorAll('[data-bs-toggle="dropdown"]').forEach(toggle =>
    bootstrap.Dropdown.getInstance(toggle)?.dispose());
  const route = panelRoute();
  const { page } = route;
  syncPanelRoute(route);
  renderBreadcrumb(route);
  $('menu').innerHTML = Object.entries(pages).map(([key, [name, symbol]]) =>
    `<li class="nav-item"><a href="#${key}" class="nav-link${page === key ? ' active' : ''}" ${page === key ? 'aria-current="page"' : ''}>${icon(symbol)}<p>${name}</p></a></li>`).join('');

  const pantallasConDatos = ['agenda', 'reservas', 'pagos', 'torneos', 'reportes'];
  if (pantallasConDatos.includes(page) && !$('screen').firstElementChild) $('screen').innerHTML = pantallaCargando();

  try {
    if (page === 'agenda' || page === 'reservas') {
      await asegurarAgenda(date);
      if (seq !== renderSeq) return;
      $('screen').innerHTML = page === 'agenda' ? agenda() : reservationsView();
      updateClocks();
    } else if (page === 'pagos') {
      if (!pagosCargados) await cargarPagos();
      if (seq !== renderSeq) return;
      $('screen').innerHTML = paymentsView();
    } else if (page === 'torneos') {
      await cargarPantallaTorneos();
      if (seq !== renderSeq) return;
      $('screen').innerHTML = tournamentView();
    } else if (page === 'reportes') {
      if (!reportesCargados) await cargarReportes();
      if (seq !== renderSeq) return;
      $('screen').innerHTML = reportesView();
    } else if (managementPages.includes(page)) {
      if (page === 'clientes') await cargarClientes(seq);
      if (page === 'tarifas') await cargarTarifas();
      if (seq !== renderSeq) return;
      $('screen').innerHTML = managementView(page);
    }
  } catch (error) {
    if (seq !== renderSeq) return;
    $('screen').innerHTML = pantallaError(error);
  }
  $('screen').querySelectorAll('[data-bs-toggle="dropdown"]').forEach(toggle =>
    bootstrap.Dropdown.getOrCreateInstance(toggle, {
      popperConfig: options => ({ ...options, strategy: 'fixed' })
    }));
}

async function iniciarPanel() {
  $('screen').innerHTML = pantallaCargando('Cargando catálogo y agenda…');
  try {
    await cargarCatalogo();
    await Promise.all([asegurarAgenda(date), cargarTorneos()]);
  } catch (error) {
    $('screen').innerHTML = pantallaError(error);
    return;
  }
  await render();
}

/* ------------------------------------------------------------------ */
/* Eventos                                                            */
/* ------------------------------------------------------------------ */

document.addEventListener('input', event => {
  if (event.target.id === 'reservation-query') {
    reservationQuery = event.target.value;
    reservationPage = 1;
    const caret = event.target.selectionStart;
    render();
    $('reservation-query')?.focus();
    $('reservation-query')?.setSelectionRange(caret, caret);
  }
  if (event.target.id === 'reservation-client-query') updateReservationClientResults();
  if (event.target.id === 'search-query') {
    globalSearchQuery = event.target.value;
    renderSearchResults();
  }
  if (event.target.id === 'court-query') {
    courtQuery = event.target.value;
    const caret = event.target.selectionStart;
    render();
    $('court-query').focus();
    $('court-query').setSelectionRange(caret, caret);
  }
});

document.addEventListener('change', event => {
  const { id, value } = event.target;
  if (id === 'reservation-status') { statusFilter = value; reservationPage = 1; return render(); }
  if (id === 'reservation-court') { reservationCourtFilter = value; reservationPage = 1; return render(); }
  if (id === 'reservation-origin') { reservationOriginFilter = value; reservationPage = 1; return render(); }
  if (id === 'reservation-page-size') { reservationPageSize = Number(value); reservationPage = 1; return render(); }
  if (id === 'date' && value) { date = value; return render(); }
  if (id === 'venue') { venue = value; return render(); }
  if (id === 'status-filter') { statusFilter = value; return render(); }
  if (id === 'pagos-desde' || id === 'pagos-hasta') {
    rangoPagos[id === 'pagos-desde' ? 'desde' : 'hasta'] = value;
    return;
  }
  if (id === 'reportes-desde' || id === 'reportes-hasta') {
    rangoReportes[id === 'reportes-desde' ? 'desde' : 'hasta'] = value;
    return;
  }
});

document.addEventListener('submit', event => {
  const form = event.target;
  const manejadores = {
    'reservation-form': submitNewReservation,
    'edit-reservation-form': saveReservationEdit,
    'reservation-payment-form': saveReservationPayment,
    'tournament-config-form': guardarTorneo,
    'team-registration-form': guardarInscripcion,
    'add-player-form': guardarJugador,
    'tournament-schedule-form': guardarProgramacion,
    'tournament-maximum-form': guardarMaximo
  };
  const manejador = manejadores[form.id];
  if (!manejador) return;
  event.preventDefault();
  manejador(form);
});

document.addEventListener('click', async event => {
  if (event.target.closest('[data-bs-toggle="dropdown"]')) return;
  const control = event.target.closest('[data-id], [data-action], [data-tournament], [data-client], [data-reservation]');
  if (!control) return;

  if (control.dataset.reservation !== undefined) {
    selectedReservationId = Number(control.dataset.reservation);
    if (activePage() === 'reservas') return render();
    return reservationDetails(selectedReservationId);
  }
  if (control.dataset.id) return reservationDetails(Number(control.dataset.id));
  if (control.dataset.tournament !== undefined) {
    selectedTournament = Number(control.dataset.tournament);
    dialog.hide();
    return render();
  }
  if (control.dataset.client !== undefined) {
    const clienteId = Number(control.dataset.client);
    return showDialog('Reservas del cliente', reservationTable(
      reservasPanel().filter(row => row.clienteId === clienteId).sort((a, b) => a.fecha.localeCompare(b.fecha)), 'Sin reservas en el rango cargado.'));
  }

  const action = control.dataset.action || '';
  if (!action) return;

  if (action.startsWith('manage-')) return handleManagementAction(action);
  if (action === 'retry') return iniciarPanel();

  if (action === 'new') return newReservation();
  if (action === 'search') return openSearch();
  if (action === 'search-back') return openSearch(globalSearchQuery);
  const searchMatch = /^search-(client|booking)-(\d+)$/.exec(action);
  if (searchMatch) return openGlobalSearchResult(searchMatch[1], Number(searchMatch[2]));

  if (action.startsWith('reservation-menu-')) return reservationDetails(Number(action.slice('reservation-menu-'.length)));
  if (action.startsWith('select-reservation-client-')) {
    const cliente = clientesEncontrados.find(entry => entry.id === Number(action.slice('select-reservation-client-'.length)));
    if (cliente) selectReservationClient(cliente);
    return;
  }
  if (action === 'open-reservation-client-create') return toggleReservationClientCreate(true);
  if (action === 'close-reservation-client-create') return toggleReservationClientCreate(false);
  if (action === 'save-reservation-client') return saveReservationClient();
  if (action === 'reservation-today') { reservationDateScope = 'today'; reservationPage = 1; return render(); }
  if (action === 'reservation-all') { reservationDateScope = 'all'; reservationPage = 1; return render(); }
  if (action === 'reservation-previous') { reservationPage = Math.max(1, reservationPage - 1); return render(); }
  if (action === 'reservation-next') { reservationPage++; return render(); }
  if (action === 'clear-reservation-filters') {
    reservationQuery = ''; statusFilter = ''; reservationCourtFilter = ''; reservationOriginFilter = '';
    reservationDateScope = 'today'; reservationPage = 1;
    return render();
  }
  const reservationAction = /^(edit|payment)-reservation-(\d+)$/.exec(action);
  if (reservationAction) return (reservationAction[1] === 'edit' ? editReservation : openReservationPayment)(Number(reservationAction[2]));

  const step = /^(confirm|ask-cancel|cancel)-(\d+)$/.exec(action);
  if (step) {
    const row = reservaPorId(step[2]);
    if (!row) return;
    if (step[1] === 'ask-cancel') {
      return showDialog(`Cancelar ${label(row)}`, `<p>Se liberará el horario de ${escapeHtml(row.cliente)}.</p><div class="d-flex gap-2"><button type="button" class="btn btn-light border" data-bs-dismiss="modal">Volver</button>${button(`cancel-${row.id}`, 'Sí, cancelar', 'btn-danger')}</div>`);
    }
    try {
      await (step[1] === 'confirm' ? reservasApi.confirmar(row.id) : reservasApi.cancelar(row.id));
      dialog.hide();
      await recargarAgenda(row.fecha);
      feedback(step[1] === 'confirm' ? 'Reserva confirmada.' : 'Reserva cancelada.');
      render();
    } catch (error) {
      feedback(error.message);
    }
    return;
  }

  if (action === 'today') { date = localClock()[0]; return render(); }
  if (action === 'previous' || action === 'next') {
    const siguiente = new Date(`${date}T12:00:00Z`);
    siguiente.setUTCDate(siguiente.getUTCDate() + (action === 'next' ? 1 : -1));
    date = siguiente.toISOString().slice(0, 10);
    return render();
  }

  if (action === 'pagos-reload') {
    pagosCargados = false;
    return render();
  }
  if (action.startsWith('void-payment-')) return requestVoidPayment(Number(action.slice('void-payment-'.length)));  if (action.startsWith('confirm-void-payment-')) return voidPayment(Number(action.slice('confirm-void-payment-'.length)));
  if (action === 'reportes-reload') {
    reportesCargados = false;
    return render();
  }

  if (action === 'new-tournament') return openTournamentConfig();
  if (action === 'register-team') return openTeamRegistration();
  if (action === 'schedule-tournament') return openTournamentSchedule();
  if (action === 'adjust-maximum') return openAdjustMaximum();
  if (action === 'tournament-agenda') {
    const torneo = torneoActual();
    if (torneo) { date = torneo.inicio; location.hash = 'agenda'; }
    return;
  }
  if (action.startsWith('view-team-')) {
    const inscripcion = inscripcionesTorneo.find(entry => entry.id === Number(action.slice('view-team-'.length)));
    if (inscripcion) return openTournamentTeams(inscripcion);
    return;
  }
  if (action.startsWith('add-player-')) {
    const inscripcion = inscripcionesTorneo.find(entry => entry.id === Number(action.slice('add-player-'.length)));
    if (inscripcion) return openAddPlayer(inscripcion);
    return;
  }
  if (action.startsWith('withdraw-team-')) {
    const inscripcion = inscripcionesTorneo.find(entry => entry.id === Number(action.slice('withdraw-team-'.length)));
    if (inscripcion) return confirmarRetiro(inscripcion);
    return;
  }
  if (action.startsWith('confirm-withdraw-')) {
    const inscripcion = inscripcionesTorneo.find(entry => entry.id === Number(action.slice('confirm-withdraw-'.length)));
    if (inscripcion) return retirarEquipo(inscripcion);
    return;
  }
  if (action.startsWith('tournament-agenda-')) {
    const row = reservaPorId(Number(action.slice('tournament-agenda-'.length)));
    if (row) { date = row.fecha; location.hash = 'agenda'; }
    return;
  }
  if (action.startsWith('select-captain-')) {
    const cliente = capitanesEncontrados.find(entry => entry.id === Number(action.slice('select-captain-'.length)));
    if (cliente) {
      capitanSeleccionado = cliente;
      $('captain-id').value = cliente.id;
      $('captain-query').value = `${cliente.nombre} · ${cliente.rut}`;
      $('captain-results').hidden = true;
      $('captain-status').textContent = 'Capitán seleccionado.';
    }
    return;
  }

  render();
  document.querySelector(`[data-action="${action}"]`)?.focus();
});

window.addEventListener('hashchange', () => {
  dialog.hide();
  render();
});

$('dialog').addEventListener('shown.bs.modal', () => $('dialog-body').querySelector('input')?.focus());

iniciarPanel();
window.setInterval(() => {
  if (!document.hidden && ['agenda', 'reservas'].includes(activePage())) void render();
}, 60000);
