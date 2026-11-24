'use strict';

let globalSearchQuery = '';
let busquedaGlobal = null;
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

function searchResults(query = globalSearchQuery) {
  const term = normalizeName(query);
  if (term.length < 2) return '<p class="small text-secondary mt-3 mb-0">Escribe al menos dos caracteres.</p>';
  const reservas = reservasPanel().filter(row => managementSearch(query,
    [row.cliente, label(row), row.cancha, row.modalidad])).sort((a, b) => b.fecha.localeCompare(a.fecha));
  return searchResultGroup('Reservas', reservas, row => searchResult('search-booking-' + row.id,
    `${label(row)} · ${row.cliente}`, `${row.fecha} · ${row.start}–${row.end} · ${row.cancha}`,
    reservationStateLabel(row))) || '<p class="small text-secondary mt-3 mb-0">No encontramos reservas para esa búsqueda.</p>';
}

async function renderSearchResults() {
  clearTimeout(busquedaGlobal);
  const consulta = globalSearchQuery;
  const contenedor = $('search-results');
  if (!contenedor) return;
  if (normalizeName(consulta).length < 2) {
    contenedor.innerHTML = searchResults(consulta);
    return;
  }
  contenedor.innerHTML = '<p class="small text-secondary mt-3 mb-0" role="status">Buscando…</p>';
  busquedaGlobal = setTimeout(async () => {
    let clientes = { items: [] };
    try { clientes = await clientesApi.buscar(consulta); } catch { /* La busqueda de reservas sigue. */ }
    if (globalSearchQuery !== consulta) return;
    const nodo = $('search-results');
    if (!nodo) return;
    const grupos = searchResultGroup('Clientes', clientes.items, cliente =>
      searchResult('search-client-' + cliente.id, cliente.nombre, cliente.rut + (cliente.correo ? ' · ' + cliente.correo : ''))) +
      searchResults(consulta);
    nodo.innerHTML = grupos;
  }, 250);
}

function openSearch(query = '') {
  globalSearchQuery = query;
  showDialog('Buscar reserva o cliente', `<label for="search-query" class="form-label">Nombre, RUT o ID de reserva</label>
    <input class="form-control" id="search-query" type="search" autocomplete="off" value="${escapeHtml(query)}"
      placeholder="Ej. Camila Rojas, 12.345.678-5 o R-10457">
    <div id="search-results" aria-live="polite">${searchResults(query)}</div>`);
  $('search-query').focus();
  if (query) renderSearchResults();
}

function openGlobalSearchResult(kind, id) {
  if (kind === 'booking') {
    if (!reservaPorId(id)) return;
    reservationDetails(id);
    $('dialog-body').insertAdjacentHTML('afterbegin', button('search-back', '← Volver a la búsqueda', 'btn-link btn-sm px-0 mb-2'));
    $('dialog-body').querySelector('[data-action="search-back"]').focus();
    return;
  }
  dialog.hide();
  showDialog('Reservas del cliente', reservationTable(
    reservasPanel().filter(row => row.clienteId === id).sort((a, b) => a.fecha.localeCompare(b.fecha)),
    'Sin reservas en el rango cargado.'));
}
