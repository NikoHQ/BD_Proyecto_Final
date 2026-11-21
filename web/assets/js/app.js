// Navegación, montaje y delegación de eventos del panel.
const pages = {
  agenda: ['Agenda', 'calendar3'], reservas: ['Reservas', 'journal-check'],
  clientes: ['Clientes', 'people'], pagos: ['Pagos', 'credit-card'],
  torneos: ['Torneos', 'trophy'], instalaciones: ['Recintos', 'geo-alt'], tarifas: ['Tarifas', 'tags']
};
function panelRoute() {
  const hash = location.hash.slice(1);
  const nested = /^instalaciones\/canchas\/(\d+)(?:\/tarifas\/(\d+))?$/.exec(hash);
  if (nested) {
    const site = siteRecords.find(entry => entry.id === Number(nested[1]));
    const court = nested[2] === undefined ? null : Number(nested[2]);
    if (site && court !== null && courts[court]?.[1] === site.key && !courtMeta[court]?.deleted) {
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
      filters: site ? { kind: 'courts', site: site.key } : {},
      selected: site ? null : facilities.lastSite ?? null,
      page: 1
    });
    if (site) facilities.lastSite = site.id;
  }
  if (page === 'tarifas') {
    Object.assign(managementState.tarifas, {
      filters: site ? { court: String(court) } : {},
      selected: null,
      page: 1
    });
  }
}

function renderBreadcrumb({ page, site, court }) {
  const crumbs = [['Administración', '#agenda']];
  if (site) {
    crumbs.push(['Recintos', '#instalaciones'], ['Canchas de ' + site.name, courtRoute(site)]);
    if (page === 'tarifas') crumbs.push(['Tarifas · ' + courts[court][0], '']);
  } else {
    crumbs.push([pages[page][0], '']);
  }
  $('current-section').innerHTML = crumbs.map(([label, href], index) =>
    index === crumbs.length - 1
      ? '<li class="breadcrumb-item active" aria-current="page">' + escapeHtml(label) + '</li>'
      : '<li class="breadcrumb-item"><a href="' + href + '">' + escapeHtml(label) + '</a></li>'
  ).join('');
}
function render() {
  $('screen').querySelectorAll('[data-bs-toggle="dropdown"]').forEach(toggle =>
    bootstrap.Dropdown.getInstance(toggle)?.dispose());
  const route = panelRoute();
  const { page } = route;
  syncPanelRoute(route);
  renderBreadcrumb(route);
  $('menu').innerHTML = Object.entries(pages).map(([key, [name, symbol]]) =>
    `<li class="nav-item"><a href="#${key}" class="nav-link${page === key ? ' active' : ''}" ${page === key ? 'aria-current="page"' : ''}>${icon(symbol)}<p>${name}</p></a></li>`).join('');
  if (page === 'agenda') {
    const query = courtQuery.trim().toLowerCase();
    const visible = courts.flatMap(([name, site], index) =>
      !courtMeta[index]?.deleted && (!venue || site === venue) && `${name} ${siteName(site)}`.toLowerCase().includes(query) ? [index] : []);
    const scroll = document.querySelector('.agenda-scroll')?.scrollLeft || 0;
    $('screen').innerHTML = agenda(allBookings().filter(row => row.date === date && visible.includes(row.court)).sort(byTime), visible);
    const agendaScroll = document.querySelector('.agenda-scroll');
    if (agendaScroll) agendaScroll.scrollLeft = scroll;
    updateClocks();
  } else if (page === 'reservas') {
    $('screen').innerHTML = reservationsView();
    updateClocks();
  } else if (managementPages.includes(page)) {
    $('screen').innerHTML = managementView(page);
  } else if (page === 'torneos') {
    $('screen').innerHTML = tournamentView();
    updateClocks();
  }
  $('screen').querySelectorAll('[data-bs-toggle="dropdown"]').forEach(toggle =>
    bootstrap.Dropdown.getOrCreateInstance(toggle, {
      popperConfig: options => ({ ...options, strategy: 'fixed' })
    }));
}
document.addEventListener('input', event => {
  if (event.target.id === 'reservation-query') {
    reservationQuery = event.target.value;
    reservationPage = 1;
    const caret = event.target.selectionStart;
    render();
    $('reservation-query')?.focus();
    $('reservation-query')?.setSelectionRange(caret, caret);
  }
  if (event.target.id === 'captain-query') updateCaptainResults();
  if (event.target.id === 'reservation-client-query') updateReservationClientResults();
  if (event.target.id === 'search-query') {
    globalSearchQuery = event.target.value;
    $('search-results').innerHTML = searchResults(globalSearchQuery);
  }
  if (event.target.id === 'court-query') {
    courtQuery = event.target.value;
    const caret = event.target.selectionStart;
    render();
    $('court-query').focus();
    $('court-query').setSelectionRange(caret, caret);
  }
});
document.addEventListener('keydown', event => {
  if (event.target.id !== 'captain-query' || !['ArrowDown', 'Enter'].includes(event.key)) return;
  event.preventDefault();
  const results = $('captain-results');
  if (results.hidden) return;
  const first = results.querySelector('button');
  if (!first) return;
  if (event.key === 'Enter' && results.children.length === 1) first.click();
  else first.focus();
});
document.addEventListener('change', event => {
  const { id, value } = event.target;
  if (id === 'tournament-site') {
    $('tournament-sport').innerHTML = venueSports(value).map(sport => selectOption(sport, sport)).join('');
    return;
  }
  if (id === 'reservation-status') { statusFilter = value; reservationPage = 1; }
  else if (id === 'reservation-court') { reservationCourtFilter = value; reservationPage = 1; }
  else if (id === 'reservation-origin') { reservationOriginFilter = value; reservationPage = 1; }
  else if (id === 'reservation-page-size') { reservationPageSize = Number(value); reservationPage = 1; }
  if (id === 'date' && value) date = value;
  else if (id === 'venue') venue = value;
  else if (id === 'status-filter') statusFilter = value;
  else if (!['reservation-status', 'reservation-court', 'reservation-origin', 'reservation-page-size'].includes(id)) return;
  render();
  $(id)?.focus();
});
document.addEventListener('submit', event => {
  if (event.target.id === 'edit-reservation-form') {
    event.preventDefault();
    return saveReservationEdit(event.target);
  }
  if (event.target.id === 'reservation-payment-form') {
    event.preventDefault();
    return saveReservationPayment(event.target);
  }
  if (event.target.id === 'tournament-config-form') {
    event.preventDefault();
    return saveTournamentConfig(event.target);
  }
  if (event.target.id === 'tournament-schedule-form') {
    event.preventDefault();
    return saveTournamentBlock(event.target);
  }
  if (event.target.id === 'team-registration-form') {
    event.preventDefault();
    return submitTeamRegistration(event.target);
  }
  if (event.target.id !== 'reservation-form') return;
  event.preventDefault();
  submitNewReservation(event.target);
});
document.addEventListener('click', event => {
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
    selectedTournamentDay = control.dataset.day || tournaments[selectedTournament].days[0];
    dialog.hide();
    if (activePage() !== 'torneos') location.hash = 'torneos';
    else {
      render();
      document.querySelector('.tournament-picker .is-selected')?.focus();
    }
    return;
  }
  if (control.dataset.client !== undefined) {
    const client = demoClients.find(entry => entry.id === Number(control.dataset.client));
    if (!client) return;
    return showDialog(client.name, reservationTable(normalRows().filter(row => row.clientId === client.id || (!row.clientId && row.client === client.name)).sort(byTime)));
  }
  const action = control.dataset.action;
  if (action.startsWith('manage-')) return handleManagementAction(action);
  if (action === 'new') return newReservation();
  if (action.startsWith('reservation-menu-')) return reservationDetails(Number(action.slice('reservation-menu-'.length)));
  if (action.startsWith('select-reservation-client-')) {
    const client = demoClients.find(entry => entry.id === Number(action.slice('select-reservation-client-'.length)));
    if (client) selectReservationClient(client);
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
    reservationQuery = ''; statusFilter = ''; reservationCourtFilter = ''; reservationOriginFilter = ''; reservationDateScope = 'today'; reservationPage = 1;
    return render();
  }
  const reservationAction = /^(edit|payment)-reservation-(\d+)$/.exec(action);
  if (reservationAction) return (reservationAction[1] === 'edit' ? editReservation : openReservationPayment)(Number(reservationAction[2]));
  if (action === 'search') return openSearch();
  if (action === 'search-back') return openSearch(globalSearchQuery);
  const searchMatch = /^search-(client|booking)-(\d+)$/.exec(action);
  if (searchMatch) return openGlobalSearchResult(searchMatch[1], Number(searchMatch[2]));
  if (action === 'register-team') return openTeamRegistration();
  if (action === 'new-tournament') return openTournamentConfig();
  if (action === 'edit-tournament') return openTournamentConfig(true);
  if (action === 'schedule-tournament') return openTournamentSchedule();
  if (action === 'manage-tournament') return openTournamentManagement();
  if (action === 'view-tournament-teams') return openTournamentTeams();
  const editTeam = /^edit-team-(\d+)$/.exec(action);
  if (editTeam) return openTeamRegistration(Number(editTeam[1]));
  if (action.startsWith('select-captain-')) {
    const client = demoClients.find(entry => entry.id === Number(action.slice('select-captain-'.length)));
    if (client) selectCaptain(client);
    return;
  }
  if (action === 'open-captain-create') return toggleCaptainCreate(true);
  if (action === 'close-captain-create') return toggleCaptainCreate(false);
  if (action === 'save-captain') return saveCaptain();
  const withdraw = /^(withdraw-team|confirm-team-withdrawal)-(\d+)$/.exec(action);
  if (withdraw) return (withdraw[1] === 'withdraw-team' ? requestTeamWithdrawal : confirmTeamWithdrawal)(Number(withdraw[2]));
  const transition = /^(ask|confirm)-(start|finish|cancel)-tournament$/.exec(action);
  if (transition) return tournamentTransition(transition[2], transition[1] === 'confirm');
  const release = /^(ask|confirm)-release-tournament-block-(\d+)$/.exec(action);
  if (release) return releaseTournamentBlock(Number(release[2]), release[1] === 'confirm');
  if (action.startsWith('tournament-day-')) selectedTournamentDay = action.slice('tournament-day-'.length);
  if (action === 'tournament-agenda') {
    date = selectedTournamentDay;
    venue = tournaments[selectedTournament].site;
    courtQuery = '';
    location.hash = 'agenda';
    return;
  }
  if (action === 'today') date = localClock()[0];
  if (action === 'previous' || action === 'next') {
    const nextDate = new Date(`${date}T12:00:00Z`);
    nextDate.setUTCDate(nextDate.getUTCDate() + (action === 'next' ? 1 : -1));
    date = nextDate.toISOString().slice(0, 10);
  }
  if (action.startsWith('court-')) {
    venue = courts[Number(action.slice(6))][1];
    courtQuery = courts[Number(action.slice(6))][0];
    location.hash = 'agenda';
  }
  const step = /^(confirm|ask-cancel|cancel|resolve)-(\d+)$/.exec(action);
  if (step) {
    const row = reservations.find(r => r.id === Number(step[2]));
    if (!row) return;
    if (step[1] === 'resolve' || (step[1] === 'confirm' && conflicts(row).length)) return reservationDetails(row.id);
    if (step[1] === 'ask-cancel') return showDialog(`Cancelar ${label(row)}`, `<p>Se liberará el horario de ${escapeHtml(row.client)}.</p><div class="d-flex gap-2">${details(row, 'Volver')}${button(`cancel-${row.id}`, 'Sí, cancelar', 'btn-danger')}</div>`);
    row.status = step[1] === 'confirm' ? 'confirmed' : 'cancelled';
    return save(row.status === 'confirmed' ? 'Reserva confirmada.' : 'Reserva cancelada.');
  }
  const deletion = /^(ask-delete|delete)-reservation-(\d+)$/.exec(action);
  if (deletion) {
    const row = reservations.find(entry => entry.id === Number(deletion[2]));
    if (!row) return;
    if (row.payments?.length) return showDialog('Reserva con historial de pagos',
      '<p>La reserva tiene movimientos asociados. Conserva su historial y usa Cancelar reserva si el estado lo permite.</p>');
    if (deletion[1] === 'ask-delete') {
      return showDialog(`Borrar ${label(row)}`, `<p>Esta acción eliminará la reserva de la maqueta. En el sistema real se debe cancelar y conservar trazabilidad.</p><div class="d-flex flex-wrap justify-content-end gap-2"><button class="btn btn-light border" data-bs-dismiss="modal">Volver</button>${button(`delete-reservation-${row.id}`, 'Borrar de la maqueta', 'btn-danger')}</div>`);
    }
    reservations = reservations.filter(entry => entry.id !== row.id);
    selectedReservationId = reservations[0]?.id || null;
    return save('Reserva eliminada de la maqueta.');
  }
  render();
  [...document.querySelectorAll('[data-action]')].find(el => el.dataset.action === action)?.focus();
});
window.addEventListener('hashchange', () => {
  dialog.hide();
  render();
});
$('dialog').addEventListener('shown.bs.modal', () => $('dialog-body').querySelector('input')?.focus());
$('dialog').addEventListener('hidden.bs.modal', () => {
  if (!$('team-registration-form')) return;
  $('dialog-body').replaceChildren();
  const trigger = document.querySelector('[data-action="register-team"]');
  (trigger || document.querySelector('.tournament-picker .is-selected'))?.focus();
});
initDemoStore();
render();
window.setInterval(updateClocks, 15000);
