const managementPages = ['clientes', 'pagos', 'instalaciones', 'tarifas'];
const managementState = Object.fromEntries(managementPages.map(page => [page, {
  filters: {}, size: 10, page: 1, selected: null
}]));
const activeStates = { ACTIVO: 'Activo', INACTIVO: 'Inactivo' };
function managementSelect(key, label, values, selected, includeAll = true) {
  return '<select class="form-select form-select-sm" data-management-filter="' + key +
    '" aria-label="' + label + '">' +
    (includeAll ? selectOption('', label) : '') +
    values.map(([value, name]) => selectOption(value, name, value === selected)).join('') + '</select>';
}

function managementSearch(query, values, rut = '') {
  const text = normalizeName(query || '');
  const normalizedRut = compactRut(query || '');
  return !text || values.some(value => normalizeName(String(value ?? '')).includes(text)) ||
    Boolean(rut && normalizedRut && compactRut(rut).includes(normalizedRut));
}

function managementMenu(label, actions) {
  return '<div class="dropdown"><button type="button" class="btn btn-outline-secondary btn-sm" ' +
    'data-bs-toggle="dropdown" aria-expanded="false" aria-label="Acciones de ' + escapeHtml(label) + '">' +
    icon('three-dots-vertical') + '</button><ul class="dropdown-menu dropdown-menu-end">' +
    actions.map(([action, name, danger]) =>
      '<li>' + button(action, escapeHtml(name), 'dropdown-item' + (danger ? ' text-danger' : '')) + '</li>'
    ).join('') + '</ul></div>';
}

function managementDetails(title, fields, actions = '') {
  return card(title, '<div class="card-body reservation-detail"><dl class="detail-list mt-0">' +
    fields.map(([label, value]) => '<dt>' + escapeHtml(label) + '</dt><dd>' +
      escapeHtml(value || '—') + '</dd>').join('') + '</dl>' +
    (actions ? '<div class="d-grid gap-2 mt-3">' + actions + '</div>' : '') + '</div>');
}

function managementView(page) {
  const state = managementState[page];
  const f = state.filters;
  const definition = managementDefinition(page, f);
  const count = definition.rows.length;
  const pagesCount = Math.max(1, Math.ceil(count / state.size));
  state.page = Math.min(state.page, pagesCount);
  const offset = (state.page - 1) * state.size;
  const visible = definition.rows.slice(offset, offset + state.size);
  const selected = visible.find(row => row.id === state.selected);
  state.selected = selected?.id ?? null;
  const rows = visible.map(row => {
    const cells = definition.cells(row).map(value => {
      const tone = { Activo:'completed', Disponible:'completed', Registrado:'confirmed', Activa:'completed',
        Inactivo:'cancelled', Inactiva:'cancelled', Anulado:'maintenance', 'Mantención':'pending' }[value];
      return tone ? '<span class="status ' + tone + '">' + escapeHtml(value) + '</span>' : escapeHtml(value);
    });
    return ['<strong>' + escapeHtml(definition.name(row)) + '</strong>', ...cells,
      managementMenu(definition.name(row), definition.actions(row))];
  });
  const pagination = '<div class="reservation-pagination"><span>' +
    (count ? 'Mostrando ' + (offset + 1) + '–' + (offset + visible.length) + ' de ' + count : '0 resultados') +
    '</span><div class="toolbar">' +
    managementSelect('size', 'Filas por página', [5, 10, 20, 50].map(size => [String(size), String(size)]), String(state.size), false) +
    '<button class="btn btn-sm btn-light border" data-action="manage-previous" aria-label="Página anterior"' +
    (state.page === 1 ? ' disabled' : '') + '>' + icon('chevron-left') + '</button><span>' + state.page + ' / ' + pagesCount +
    '</span><button class="btn btn-sm btn-light border" data-action="manage-next" aria-label="Página siguiente"' +
    (state.page === pagesCount ? ' disabled' : '') + '>' + icon('chevron-right') + '</button></div></div>';
  const filters = '<div class="card-body border-bottom toolbar"><input type="search" id="management-query" ' +
    'class="form-control" aria-label="Buscar ' + definition.title.toLowerCase() + '" value="' +
    escapeHtml(f.query || '') + '" placeholder="' + definition.placeholder + '">' + definition.filters +
    button('manage-clear', 'Limpiar filtros', 'btn-link btn-sm') + '</div>';
  const list = table([...definition.headers, 'Acciones'], rows, 'Sin resultados para mostrar.', index => {
    const id = visible[index].id;
    const selected = id === state.selected;
    return 'data-action="manage-select-' + id + '" tabindex="0" aria-label="' +
      escapeHtml(definition.name(visible[index])) + (selected ? ', seleccionado' : '') +
      '" class="selectable-row' + (selected ? ' is-selected' : '') + '"';
  }).replace(
    '<table class="table', '<table class="management-table table');
  return heading(definition.title, definition.description || '', definition.toolbar) +
    '<div class="row g-3 align-items-start reservation-layout"><div class="col-12 col-xl-8 col-xxl-9">' +
    card('Listado', filters + list + pagination) + '</div><div class="col-12 col-xl-4 col-xxl-3">' +
    (selected ? definition.details(selected) : card('Detalle', '<p class="empty">' +
      (count ? 'Selecciona una fila para ver sus datos.' : 'Sin registros para mostrar.') + '</p>')) +
    '</div></div>';
}
function managementDefinition(page, filters) {
  if (page === 'tarifas') return tariffsDefinition(filters);
  if (page === 'clientes') return clientsDefinition(filters, managementAction);
  if (page === 'pagos') return paymentsDefinition(filters, managementAction);
  return facilitiesDefinition(filters, managementAction);
}
const managementAction = (kind, id, label, danger) => ['manage-' + kind + '-' + id, label, danger];
function editManaged(page, item) {
  if (page === 'clientes') return editClient(item);
  if (page === 'pagos') return editPayment(item);
  return editSite(item);
}

function saveManaged(form) {
  const { page, record } = form.dataset;
  const id = Number(record);
  const formData = new FormData(form);
  const data = Object.fromEntries([...formData].map(([key, value]) => [key, value.trim()]));
  let valid = true;
  const error = message => {
    valid = false;
    $('management-error').textContent = message;
  };
  if (page === 'tariff') return saveTariff(id, data, error);
  if (page === 'tariff-split') return saveTariffSplit(id, data, error);
  if (page === 'clientes') saveClient(id, data, error);
  else if (page === 'pagos') savePayment(id, data, error);
  else if (page === 'court') saveCourt(id, data, formData, error);
  else if (page === 'hours') saveSiteHours(id, data, error);
  else saveSite(id, data, error);
  if (!valid) return;
  saveManagement();
  save('Cambios guardados en la maqueta.');
}

function hasManagedDependencies(page, item, isCourt) {
  if (page === 'clientes') return clientBookings(item).length > 0 ||
    tournaments.some(tournament => tournament.roster.some(team => team.captainId === item.id ||
      team.players.some(player => player.rut === item.rut)));
  if (isCourt) return allBookings().some(row => row.court === item.id) || demoTariffs.some(rate => rate.court === item.id);
  return courts.some((court, index) => court[1] === item.key && !courtMeta[index]?.deleted) ||
    tournaments.some(tournament => tournament.site === item.key);
}

function handleManagementAction(action) {
  const page = activePage();
  const state = managementState[page];
  if (!state) return;
  if (action === 'manage-oracle' && page === 'instalaciones') return showOracleCatalog();
  if (page === 'tarifas' && /^(manage-new-tariff|manage-rate-)/.test(action)) return tariffAction(action);
  if (action === 'manage-new-court' && page === 'instalaciones') return editCourt();
  if (action === 'manage-new-site' && page === 'instalaciones') return editManaged(page);
  if (action === 'manage-sites' && page === 'instalaciones') {
    location.hash = 'instalaciones';
    return;
  }
  if (action === 'manage-new' && page === 'clientes') return editManaged(page);
  if (action === 'manage-clear') {
    const scopedCourt = page === 'tarifas' ? panelRoute().court : undefined;
    state.filters = {
      kind: state.filters.kind, site: state.filters.site,
      ...(scopedCourt !== undefined && { court: String(scopedCourt) })
    };
    state.page = 1;
    return render();
  }
  if (action === 'manage-previous' || action === 'manage-next') {
    state.page = Math.max(1, state.page + (action === 'manage-next' ? 1 : -1));
    return render();
  }
  const match = /^manage-(select|history|edit|toggle|ask-delete|delete|courts|rates|hours)-(\d+)$/.exec(action);
  if (!match) return;
  const [, kind, rawId] = match;
  const id = Number(rawId);
  const definition = managementDefinition(page, { kind: state.filters.kind });
  const item = definition.rows.find(row => row.id === id);
  if (!item) return;
  state.selected = id;
  const isCourt = page === 'instalaciones' && state.filters.kind === 'courts';
  if (kind === 'select') {
    render();
    document.querySelector('.selectable-row.is-selected')?.focus({ preventScroll: true });
    return;
  }
  if (kind === 'courts') {
    location.hash = courtRoute(item);
    return;
  }
  if (kind === 'hours') return editSiteHours(item);
  if (kind === 'rates') {
    const site = siteRecords.find(entry => entry.key === item.key);
    if (site) location.hash = courtRoute(site) + '/tarifas/' + id;
    return;
  }
  if (kind === 'edit') return editManaged(page, item);
  if (kind === 'history') {
    if (page === 'clientes') return showDialog(item.name, reservationTable(clientBookings(item).sort(byTime)));
    if (page === 'pagos') return reservationDetails(item.row.id);
    venue = item.key;
    courtQuery = isCourt ? item.name : '';
    location.hash = 'agenda';
    return;
  }
  if (kind === 'toggle') {
    if (isCourt) (courtMeta[id] ||= {}).status = item.status === 'DISPONIBLE' ? 'INACTIVA' : 'DISPONIBLE';
    else {
      const entry = page === 'clientes' ? item : siteRecords.find(site => site.id === id);
      entry.status = (entry.status || 'ACTIVO') === 'ACTIVO' ? 'INACTIVO' : 'ACTIVO';
    }
    saveManagement();
    return save('Estado actualizado.');
  }
  const payment = page === 'pagos';
  if (payment && (!canManagePayments() || item.payment.voided)) return;
  if (!payment && hasManagedDependencies(page, item, isCourt)) {
    return showDialog('Registro vinculado', '<p>El registro tiene elementos asociados. Puedes desactivarlo y conservar su historial.</p>');
  }
  if (kind === 'ask-delete') {
    const verb = payment ? 'Anular' : 'Eliminar';
    const prompt = '<p>' + verb + ' <strong>' + escapeHtml(definition.name(item)) + '</strong> en la maqueta.</p>';
    if (payment) return showDialog('Anular pago', prompt +
      '<form id="management-void" data-record="' + id + '">' +
      field('reason', 'Motivo', '', 'required maxlength="200"') + modalActions('Confirmar anulación') + '</form>');
    return showDialog('Eliminar registro', prompt + button('manage-delete-' + id, 'Confirmar eliminación', 'btn-danger'));
  }
  if (payment) return;
  if (isCourt) (courtMeta[id] ||= {}).deleted = true;
  else {
    const records = page === 'clientes' ? demoClients : siteRecords;
    records.splice(records.findIndex(row => row.id === id), 1);
  }
  saveManagement();
  save('Registro eliminado de la maqueta.');
}
document.addEventListener('submit', event => {
  const form = event.target;
  if (form.id === 'management-edit') {
    event.preventDefault();
    return saveManaged(form);
  }
  if (form.id !== 'management-void') return;
  event.preventDefault();
  const item = paymentRows().find(row => row.id === Number(form.dataset.record));
  const reason = new FormData(form).get('reason').trim();
  if (!item || !canManagePayments() || item.payment.voided || !reason) return;
  Object.assign(item.payment, { id: item.id, voided: true, voidReason: reason });
  save('Pago anulado. El saldo se actualizó.');
});

document.addEventListener('keydown', event => {
  if (event.target.matches('.selectable-row') && ['Enter', ' '].includes(event.key)) {
    event.preventDefault();
    event.target.click();
  }
});

document.addEventListener('change', event => {
  const key = event.target.dataset.managementFilter;
  const state = managementState[activePage()];
  if (!key || !state) return;
  const value = event.target.value;
  if (key === 'size') state.size = Number(value);
  else if (key === 'kind') state.filters = { kind: value };
  else state.filters[key] = value;
  state.page = 1;
  render();
  document.querySelector('[data-management-filter="' + key + '"]')?.focus();
});

document.addEventListener('input', event => {
  if (event.target.id !== 'management-query') return;
  const state = managementState[activePage()];
  state.filters.query = event.target.value;
  state.page = 1;
  render();
  $('management-query').focus();
});
