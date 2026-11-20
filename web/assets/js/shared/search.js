let globalSearchQuery = '';
const globalSearchLimit = 6;
function searchResultGroup(title, matches, renderResult) {
  if (!matches.length) return '';
  const remaining = matches.length - globalSearchLimit;
  return `<section class="mt-3"><h3 class="fs-6">${title} <span class="text-secondary">(${matches.length})</span></h3>
    <div class="list-group">${matches.slice(0, globalSearchLimit).map(renderResult).join('')}</div>
    ${remaining > 0 ? `<p class="small text-secondary mt-2 mb-0">Hay ${remaining} coincidencias más. Afina la búsqueda para verlas.</p>` : ''}
    </section>`;
}
function searchResult(action, title, detail, end = '') {
  return button(action, `<span class="d-flex justify-content-between align-items-center gap-2">
    <span><strong class="d-block">${escapeHtml(title)}</strong><small class="text-secondary">${escapeHtml(detail)}</small></span>
    ${end || icon('chevron-right')}</span>`, 'list-group-item list-group-item-action text-start');
}
function searchResults(query) {
  const term = normalizeName(query);
  if (term.length < 2) return '<p class="small text-secondary mt-3 mb-0">Escribe al menos dos caracteres.</p>';
  const rut = compactRut(query);
  const clients = demoClients.filter(client => managementSearch(query, [client.name, client.email, client.phone], client.rut))
    .sort((a, b) => Number(compactRut(b.rut) === rut) - Number(compactRut(a.rut) === rut) ||
      a.name.localeCompare(b.name, 'es'));
  const bookings = allBookings().filter(row => row.status !== 'maintenance' && managementSearch(query,
    [row.client, label(row), row.id, courts[row.court][0], siteName(courts[row.court][1])], clientForReservation(row)?.rut))
    .sort((a, b) => Number(term === String(b.id) || term === normalizeName(label(b))) -
      Number(term === String(a.id) || term === normalizeName(label(a))) || byTime(b, a));
  return searchResultGroup('Clientes', clients, client =>
    searchResult('search-client-' + client.id, client.name, client.rut + (client.email ? ' · ' + client.email : ''))) +
    searchResultGroup('Reservas', bookings, row => searchResult('search-booking-' + row.id,
      label(row) + ' · ' + row.client, dayLabel(row.date) + ' · ' + row.start + '–' + row.end + ' · ' + courts[row.court][0],
      reservationStateLabel(row))) ||
    '<p class="small text-secondary mt-3 mb-0">No encontramos clientes ni reservas para esa búsqueda.</p>';
}
function openSearch(query = '') {
  globalSearchQuery = query;
  showDialog('Buscar reserva o cliente', `<label for="search-query" class="form-label">Nombre, RUT, correo o ID de reserva</label>
    <input class="form-control" id="search-query" type="search" autocomplete="off" value="${escapeHtml(query)}"
      placeholder="Ej. Camila Rojas, 12.345.678-5 o R-10457">
    <div id="search-results" aria-live="polite">${searchResults(query)}</div>`);
  $('search-query').focus();
}
function openGlobalSearchResult(kind, id) {
  if (kind === 'booking') {
    if (!allBookings().some(row => row.id === id)) return;
    reservationDetails(id);
    $('dialog-body').insertAdjacentHTML('afterbegin', button('search-back', '← Volver a la búsqueda', 'btn-link btn-sm px-0 mb-2'));
    $('dialog-body').querySelector('[data-action="search-back"]').focus();
    return;
  }
  const client = demoClients.find(entry => entry.id === id);
  if (!client) return;
  Object.assign(managementState.clientes, { filters: { query: client.rut }, selected: id, page: 1 });
  dialog.hide();
  if (activePage() === 'clientes') render();
  else location.hash = 'clientes';
}
