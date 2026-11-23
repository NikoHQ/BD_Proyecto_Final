let statusFilter = '';
let reservationQuery = '';
let reservationCourtFilter = '';
let reservationOriginFilter = '';
let reservationDateScope = 'today';
let selectedReservationId = null;
let reservationPage = 1;
let reservationPageSize = 10;
function reservationTable(rows, empty) {
  return table(['Reserva', 'Cliente', 'Instalación', 'Horario', 'Estado', 'Importe', 'Origen', ''], rows.map(row => [
    label(row), escapeHtml(row.client), courts[row.court][0], `<span class="text-nowrap">${row.start}–${row.end}</span>`,
    isActiveTournamentBlock(row) ? tournamentBadge() : badge(row.status), isTournament(row) ? '—' : money.format(row.amount), row.origin, details(row)
  ]), empty);
}
function reservationStateLabel(row) {
  return isActiveTournamentBlock(row) ? tournamentBadge() : badge(row.status);
}
function reservationActionsMenu(row) {
  if (isTournament(row)) return `<div class="dropdown"><button class="btn btn-outline-secondary btn-sm" type="button" data-bs-toggle="dropdown" aria-label="Acciones de ${label(row)}">${icon('three-dots-vertical')}</button><ul class="dropdown-menu dropdown-menu-end"><li><button class="dropdown-item" data-action="reservation-menu-${row.id}">Ver detalle</button></li></ul></div>`;
  const editable = ['pending', 'confirmed'].includes(row.status);
  return `<div class="dropdown"><button class="btn btn-outline-secondary btn-sm" type="button" data-bs-toggle="dropdown" aria-label="Acciones de ${label(row)}">${icon('three-dots-vertical')}</button><ul class="dropdown-menu dropdown-menu-end">
    <li><button class="dropdown-item" data-action="reservation-menu-${row.id}">Ver detalle</button></li>
    ${canConfirmReservation(row) && !conflicts(row).length ? `<li><button class="dropdown-item" data-action="confirm-${row.id}">Confirmar</button></li>` : ''}
    ${editable ? `<li><button class="dropdown-item" data-action="edit-reservation-${row.id}">Editar</button></li>` : ''}
    ${canRegisterReservationPayment(row) ? `<li><button class="dropdown-item" data-action="payment-reservation-${row.id}">Registrar pago</button></li>` : ''}
    ${editable ? `<li><hr class="dropdown-divider"></li><li><button class="dropdown-item text-danger" data-action="ask-cancel-${row.id}">Cancelar reserva</button></li>` : ''}
    <li><button class="dropdown-item text-danger" data-action="ask-delete-reservation-${row.id}">Borrar de la maqueta</button></li>
  </ul></div>`;
}
function normalRows() {
  return reservations.filter(row => row.status !== 'maintenance');
}
const canConfirmReservation = row => row.status === 'pending' && document.body.dataset.accountRole === 'ADMINISTRADOR';
const clientForReservation = row => demoClients.find(client => client.id === row.clientId) ||
  demoClients.find(client => client.name === row.client);
function overlaps(a, b) {
  return a.id !== b.id && courtsShareSpace(a.court, b.court) && a.date === b.date &&
    a.status !== 'cancelled' && b.status !== 'cancelled' && a.start < b.end && a.end > b.start;
}
function conflicts(row) {
  return allBookings().filter(other => overlaps(row, other));
}
function reservationFilters(rows) {
  const term = normalizeName(reservationQuery);
  return rows.filter(row => {
    const [courtName] = courts[row.court];
    const client = clientForReservation(row);
    const matchText = !term || [label(row), row.client, client?.rut || '', courtName].some(value => normalizeName(String(value)).includes(term));
    const matchDate = reservationDateScope === 'all' || row.date === date;
    const matchStatus = !statusFilter || row.status === statusFilter;
    const matchCourt = reservationCourtFilter === '' || row.court === Number(reservationCourtFilter);
    const matchOrigin = !reservationOriginFilter || row.origin === reservationOriginFilter;
    return matchText && matchDate && matchStatus && matchCourt && matchOrigin;
  }).sort(byTime);
}
function reservationDetailPanel(row) {
  if (!row) return card('Detalle de reserva', '<div class="card-body"><p class="empty px-0">Selecciona una reserva para ver sus datos y acciones.</p></div>');
  const [name, site, sport] = courts[row.court];
  const client = clientForReservation(row);
  const payment = paymentSummary(row);
  const conflict = conflicts(row).length > 0;
  const editable = ['pending', 'confirmed'].includes(row.status) && !isTournament(row);
  const actions = canConfirmReservation(row) && !conflict ? button(`confirm-${row.id}`, 'Confirmar reserva', 'btn-accent w-100') : '';
  return card('Detalle de reserva', `<div class="card-body reservation-detail">
    <div class="d-flex justify-content-between gap-2 align-items-start"><strong class="fs-5">${label(row)}</strong>${reservationStateLabel(row)}</div>
    ${conflict ? `<div class="alert alert-danger py-2 mt-3 mb-0 small">${icon('exclamation-triangle-fill')} Hay un cruce de horario que requiere revisión.</div>` : ''}
    <dl class="detail-list">
      <dt>${icon('person')} Cliente</dt><dd>${escapeHtml(row.client)}${client ? `<small>${client.rut}</small>` : ''}</dd>
      <dt>${icon('geo-alt')} Cancha</dt><dd>${escapeHtml(name)} · ${escapeHtml(siteName(site))}</dd>
      <dt>${icon('calendar3')} Fecha</dt><dd>${dayLabel(row.date)}</dd>
      <dt>${icon('clock')} Horario</dt><dd>${row.start}–${row.end}</dd>
      <dt>${icon('dribbble')} Modalidad</dt><dd>${escapeHtml(row.modality || (isTournament(row) ? tournaments[row.tournamentId].sport : sport))}</dd>
      <dt>${icon('share')} Origen</dt><dd>${row.origin}</dd>
      <dt>${icon('cash-stack')} Total</dt><dd>${money.format(row.amount)}</dd>
      <dt>${icon('credit-card')} Pago</dt><dd><span class="status ${payment.className}">${payment.label}</span></dd>
    </dl>
    ${row.payment ? `<div class="payment-history"><strong>Pago registrado</strong><span>${money.format(row.payment.amount)} · ${escapeHtml(row.payment.method)}${row.payment.voided ? ' · Anulado' : ''}</span></div>` : ''}
    <div class="d-grid gap-2 mt-3">${actions}${editable ? button(`edit-reservation-${row.id}`, `${icon('pencil')} Editar reserva`, 'btn btn-light border') : ''}${canRegisterReservationPayment(row) ? button(`payment-reservation-${row.id}`, `${icon('credit-card')} Registrar pago`, 'btn btn-light border') : ''}${editable ? button(`ask-cancel-${row.id}`, 'Cancelar reserva', 'btn btn-outline-danger') : ''}</div>
  </div>`);
}
function reservationsView() {
  const allRows = [...normalRows(), ...tournamentBookings].filter(row => !isTournament(row) || row.status !== 'cancelled');
  const filtered = reservationFilters(allRows);
  const pageCount = Math.max(1, Math.ceil(filtered.length / reservationPageSize));
  reservationPage = Math.min(reservationPage, pageCount);
  const pageStart = (reservationPage - 1) * reservationPageSize;
  const visibleRows = filtered.slice(pageStart, pageStart + reservationPageSize);
  if (!selectedReservationId || !filtered.some(row => row.id === selectedReservationId)) selectedReservationId = visibleRows[0]?.id || null;
  const selected = allRows.find(row => row.id === selectedReservationId);
  const todayRows = normalRows().filter(row => row.date === date && row.status !== 'cancelled');
  const pendingRows = todayRows.filter(row => row.status === 'pending');
  const conflictCount = normalRows().filter(row => conflicts(row).length).length;
  const projected = todayRows.reduce((sum, row) => sum + row.amount, 0);
  const statusOptions = `<option value="">Todos los estados</option>${Object.entries(statuses).filter(([key]) => key !== 'maintenance').map(([key, value]) => `<option value="${key}" ${key === statusFilter ? 'selected' : ''}>${value}</option>`).join('')}`;
  const courtOptions = `<option value="">Todas las canchas</option>${courts.map(([name, site], index) => `<option value="${index}" ${reservationCourtFilter !== '' && Number(reservationCourtFilter) === index ? 'selected' : ''}>${escapeHtml(name)} · ${escapeHtml(siteName(site))}</option>`).join('')}`;
  const origins = ['', 'Web', 'Mostrador', 'Torneo'];
  const tableRows = visibleRows.map(row => {
    const payment = isTournament(row) ? { label: '—', className: 'cancelled' } : paymentSummary(row);
    return `<tr class="${row.id === selectedReservationId ? 'is-selected' : ''}" data-reservation="${row.id}">
      <td><button class="reservation-link" data-reservation="${row.id}">${label(row)}</button></td><td>${escapeHtml(row.client)}</td><td>${escapeHtml(courts[row.court][0])}</td><td>${row.start}–${row.end}</td>
      <td>${reservationStateLabel(row)}</td><td><span class="status ${payment.className}">${payment.label}</span></td><td>${row.origin}</td>
      <td>${reservationActionsMenu(row)}</td></tr>`;
  }).join('');
  const actions = `<a class="btn btn-outline-secondary" href="/dashboardadmin/solicitudes-web.php">Solicitudes web</a>
    ${button('new', `${icon('plus-lg')} Nueva reserva`, 'btn-accent')}`;
  return `${heading('Reservas', 'Gestiona reservas, confirmaciones y pagos.', actions)}
    <div class="row g-2 mb-3">${metric('calendar2-check', 'Reservas del día', todayRows.length)}${metric('hourglass-split', 'Por confirmar', pendingRows.length)}${metric('exclamation-triangle', 'Con conflicto', conflictCount)}${metric('cash-stack', 'Ingresos proyectados', money.format(projected))}</div>
    <div class="row g-3 reservation-layout"><div class="col-12 col-xxl-9">${card(`Reservas del ${dateLabel.format(new Date(`${date}T12:00:00`))}`, `<div class="card-body border-bottom reservation-tools">
      <div class="toolbar"><input id="reservation-query" type="search" class="form-control" value="${escapeHtml(reservationQuery)}" placeholder="Buscar por ID, cliente, RUT o cancha" aria-label="Buscar reservas"><div class="btn-group" role="group" aria-label="Periodo"><button class="btn btn-sm ${reservationDateScope === 'today' ? 'btn-accent' : 'btn-light border'}" data-action="reservation-today">Día</button><button class="btn btn-sm ${reservationDateScope === 'all' ? 'btn-accent' : 'btn-light border'}" data-action="reservation-all">Todas</button></div></div>
      <div class="toolbar mt-2"><select id="reservation-status" class="form-select" aria-label="Filtrar por estado">${statusOptions}</select><select id="reservation-court" class="form-select" aria-label="Filtrar por cancha">${courtOptions}</select><select id="reservation-origin" class="form-select" aria-label="Filtrar por origen">${origins.map(origin => `<option value="${origin}" ${origin === reservationOriginFilter ? 'selected' : ''}>${origin || 'Todos los orígenes'}</option>`).join('')}</select><button class="btn btn-link ms-auto" data-action="clear-reservation-filters">Limpiar filtros</button></div></div>
      ${filtered.length ? `<div class="table-responsive"><table class="table table-hover reservation-table mb-0"><thead><tr><th>ID</th><th>Cliente</th><th>Cancha</th><th>Horario</th><th>Estado</th><th>Pago</th><th>Origen</th><th></th></tr></thead><tbody>${tableRows}</tbody></table></div><div class="reservation-pagination"><span>Mostrando ${pageStart + 1}–${Math.min(pageStart + reservationPageSize, filtered.length)} de ${filtered.length}</span><div class="toolbar"><label>Filas <select id="reservation-page-size" class="form-select form-select-sm" aria-label="Filas por página">${[5, 10, 20, 50].map(size => `<option value="${size}" ${size === reservationPageSize ? 'selected' : ''}>${size}</option>`).join('')}</select></label><button class="btn btn-sm btn-light border" data-action="reservation-previous" ${reservationPage === 1 ? 'disabled' : ''}>${icon('chevron-left')}</button><span class="small">${reservationPage} / ${pageCount}</span><button class="btn btn-sm btn-light border" data-action="reservation-next" ${reservationPage === pageCount ? 'disabled' : ''}>${icon('chevron-right')}</button></div></div>` : '<p class="empty">No hay reservas para los filtros aplicados.</p>'}`) }</div><div class="col-12 col-xxl-3">${reservationDetailPanel(selected)}</div></div>`;
}
function updateReservationClientResults() {
  const query = $('reservation-client-query').value.trim();
  $('reservation-client-id').value = '';
  const exactRut = parseRut(query);
  const rutQuery = compactRut(query);
  const nameQuery = normalizeName(query);
  const matches = query ? demoClients.filter(client => exactRut
    ? client.rut === exactRut
    : normalizeName(client.name).includes(nameQuery) || (rutQuery && compactRut(client.rut).includes(rutQuery))) : [];
  const list = $('reservation-client-results');
  const status = $('reservation-client-status');
  const limit = 5;
  list.innerHTML = matches.slice(0, limit).map(client =>
    button(`select-reservation-client-${client.id}`, escapeHtml(`${client.name} · ${client.rut}`), 'list-group-item list-group-item-action text-start')
  ).join('');
  if (exactRut && !matches.length) {
    list.innerHTML = button('open-reservation-client-create', `Crear cliente con RUT ${escapeHtml(exactRut)}`, 'list-group-item list-group-item-action text-start');
  }
  list.hidden = !list.children.length;
  status.textContent = matches.length > limit ? 'Se muestran 5 coincidencias. Afina la búsqueda.' : '';
  if (query && !matches.length) status.textContent = exactRut ? 'El RUT no tiene ficha de cliente.' : 'Sin coincidencias. Para crear una ficha, ingresa el RUT completo con DV.';
}
function selectReservationClient(client) {
  if (!clientActive(client)) {
    $('reservation-client-status').textContent = 'La ficha está inactiva.';
    return;
  }
  $('reservation-client-id').value = client.id;
  $('reservation-client-query').value = `${client.name} · ${client.rut}`;
  $('reservation-client-status').textContent = 'Cliente seleccionado.';
  $('reservation-client-results').hidden = true;
  $('reservation-client-results').replaceChildren();
  $('reservation-client-query').focus();
}
function toggleReservationClientCreate(open) {
  const query = $('reservation-client-query');
  const fields = $('reservation-client-create-fields');
  fields.hidden = !open;
  fields.disabled = !open;
  query.readOnly = open;
  if (open) {
    fields.querySelector('[name="reservationClientRut"]').value = parseRut(query.value) || '';
    $('reservation-client-results').hidden = true;
    fields.querySelector('input').focus();
  } else {
    if (!$('reservation-client-id').value) updateReservationClientResults();
    query.focus();
  }
}
function saveReservationClient() {
  const fields = $('reservation-client-create-fields');
  if ([...fields.querySelectorAll('input')].some(field => !field.reportValidity())) return;
  const form = $('reservation-form') || $('edit-reservation-form');
  const name = form.elements.reservationClientName.value.trim();
  const rut = parseRut(form.elements.reservationClientRut.value);
  const email = form.elements.reservationClientEmail.value.trim().toLowerCase();
  const error = $('reservation-client-create-error');
  if (!name || !rut) { error.textContent = 'Ingresa el nombre y un RUT válido.'; return; }
  let client = demoClients.find(entry => entry.rut === rut);
  if (!client) {
    if (email && demoClients.some(entry => entry.email === email)) {
      error.textContent = 'Ese correo ya está asociado a otra ficha.';
      return;
    }
    client = { id: nextClientId++, name, rut, phone: form.elements.reservationClientPhone.value.trim(), email, type: 'Persona' };
    demoClients.push(client);
    saveManagement();
  }
  fields.querySelectorAll('input').forEach(input => { input.value = ''; });
  error.textContent = '';
  selectReservationClient(client);
  toggleReservationClientCreate(false);
}
function reservationDetails(id) {
  const row = allBookings().find(r => r.id === id);
  if (!row) return;
  const [name, site, sport] = courts[row.court];
  if (isTournament(row)) {
    showDialog('Bloque de torneo', `<div class="d-flex justify-content-between gap-2 mb-3"><strong>${escapeHtml(row.client)}</strong>${row.status === 'cancelled' ? badge('cancelled') : tournamentBadge()}</div>
      <dl class="row"><dt class="col-4">Actividad</dt><dd class="col-8">${escapeHtml(row.activity)}</dd><dt class="col-4">Cancha</dt><dd class="col-8">${escapeHtml(name)} · ${escapeHtml(siteName(site))}</dd><dt class="col-4">Horario</dt><dd class="col-8">${dayLabel(row.date)} · ${row.start}–${row.end}</dd></dl>
      <button class="btn btn-accent" data-tournament="${row.tournamentId}" data-day="${row.date}">Ver torneo</button>`);
    return;
  }
  const crossings = conflicts(row);
  const actions = ['pending', 'confirmed'].includes(row.status)
    ? `<div class="d-flex flex-wrap gap-2">${canConfirmReservation(row) && !crossings.length ? button(`confirm-${id}`, 'Confirmar reserva', 'btn-accent') : ''}${button(`ask-cancel-${id}`, 'Cancelar reserva', 'btn-outline-danger')}</div>`
    : '';
  const warning = crossings.length ? `<div class="alert alert-danger"><strong>${icon('exclamation-triangle-fill')} Conflicto en esta instalación</strong>
    <p class="small mb-2">Los horarios de estas reservas se cruzan en la misma cancha. Cancela una de las reservas para liberar el bloque.</p>
    ${crossings.map(other => `<div class="d-flex align-items-center justify-content-between gap-2 mb-1"><span>${escapeHtml(other.client)} · ${other.start}–${other.end}</span>${details(other, 'Ver')}</div>`).join('')}</div>` : '';
  showDialog(row.status === 'maintenance' ? 'Mantención' : `Reserva ${label(row)}`, `
    <div class="d-flex justify-content-between align-items-start gap-2 mb-3"><strong>${escapeHtml(row.client)}</strong>${badge(row.status)}</div>${warning}
    <dl class="row mb-3"><dt class="col-4">Instalación</dt><dd class="col-8">${escapeHtml(name)} · ${escapeHtml(siteName(site))}</dd><dt class="col-4">Modalidad</dt><dd class="col-8">${sport}</dd><dt class="col-4">Horario</dt><dd class="col-8">${row.date} · ${row.start}–${row.end}</dd>${row.status !== 'maintenance' ? `<dt class="col-4">Origen</dt><dd class="col-8">${row.origin}</dd><dt class="col-4">Importe</dt><dd class="col-8">${money.format(row.amount)}</dd>` : ''}</dl>${actions}`);
}
function reservationClientPicker(row = null) {
  const client = row ? clientForReservation(row) : null;
  const text = client ? `${client.name} · ${client.rut}` : '';
  return `<div class="col-12"><label class="form-label" for="reservation-client-query">Cliente</label>
    <input class="form-control" type="search" id="reservation-client-query" value="${escapeHtml(text)}" placeholder="Escribe el RUT o nombre del cliente" aria-describedby="reservation-client-help" autocomplete="off">
    <input type="hidden" id="reservation-client-id" name="clientId" value="${client?.id || ''}">
    <div id="reservation-client-results" class="list-group mt-1" role="group" aria-label="Coincidencias de clientes" hidden></div>
    <p id="reservation-client-status" class="small text-secondary mb-0" role="status"></p>
    <p id="reservation-client-help" class="form-text">Selecciona una ficha existente o crea una con un RUT válido.</p>
    <fieldset id="reservation-client-create-fields" class="border rounded p-3 mt-2" hidden disabled>
      <legend class="fs-6 fw-semibold">Nueva ficha de cliente</legend>
      <div class="row g-2">
        <label class="col-sm-7">Nombre completo<input class="form-control" name="reservationClientName" maxlength="100" required></label>
        <label class="col-sm-5">RUT con DV<input class="form-control" name="reservationClientRut" maxlength="12" required></label>
        <label class="col-sm-6">Teléfono (opcional)<input class="form-control" type="tel" name="reservationClientPhone" maxlength="20"></label>
        <label class="col-sm-6">Correo (opcional)<input class="form-control" type="email" name="reservationClientEmail" maxlength="150"></label>
      </div>
      <p id="reservation-client-create-error" class="text-danger small mb-0" role="alert"></p>
      <div class="d-flex flex-wrap gap-2 mt-2">
        ${button('save-reservation-client', 'Guardar y seleccionar', 'btn-accent btn-sm')}
        ${button('close-reservation-client-create', 'Cancelar alta')}
      </div>
    </fieldset>
  </div>`;
}
function bookingCourtOptions(current = null) {
  const preferred = current ?? courts.findIndex((court, i) => court[1] === venue && courtAvailable(i));
  return courts.map(([name, site], index) => {
    if (index !== current && !courtAvailable(index)) return '';
    return selectOption(index, name + ' · ' + siteName(site), index === preferred);
  }).join('');
}
function newReservation() {
  const preferred = courts.findIndex((court, i) => court[1] === venue && courtAvailable(i));
  const firstCourt = preferred === -1 ? courts.findIndex((_, i) => courtAvailable(i)) : preferred;
  showDialog('Nueva reserva', `<form id="reservation-form" class="row g-3">
    ${reservationClientPicker()}
    <div class="col-12"><label class="form-label" for="court">Instalación</label><select class="form-select" id="court" name="court" required>${bookingCourtOptions()}</select></div>
    <div class="col-12">${editSelect('modality', 'Modalidad', courtModes(firstCourt).map(mode => [mode, mode]))}</div>
    <div class="col-12"><label class="form-label" for="booking-day">Fecha</label><input type="date" id="booking-day" class="form-control" name="date" value="${date}" required></div>
    <div class="col-6">${clockField("start", "Inicio", "16:00")}</div>
    <div class="col-6">${clockField("end", "Término", "17:00", { end: true })}</div>
    ${reservationPricingFields()}
    <p class="small text-secondary mb-0">Origen: Mostrador · Estado inicial: Confirmada</p>
    <div id="form-error" class="text-danger small" role="alert"></div>
    <div class="d-flex justify-content-end"><button class="btn btn-accent" type="submit">Guardar reserva</button></div>
  </form>`);
  updateReservationQuote($('reservation-form'));
}
function editReservation(id) {
  const row = reservations.find(entry => entry.id === id);
  if (!row || !['pending', 'confirmed'].includes(row.status)) return;
  showDialog(`Editar ${label(row)}`, `<form id="edit-reservation-form" data-reservation-id="${id}" class="row g-3">
    ${reservationClientPicker(row)}
    <div class="col-12"><label class="form-label">Instalación<select class="form-select" name="court" required>${bookingCourtOptions(row.court)}</select></label></div>
    <div class="col-12">${editSelect('modality', 'Modalidad', courtModes(row.court).map(mode => [mode, mode]), row.modality || courtModes(row.court)[0])}</div>
    <div class="col-12"><label class="form-label">Fecha<input class="form-control" type="date" name="date" value="${row.date}" required></label></div>
    <div class="col-6">${clockField("start", "Inicio", row.start)}</div>
    <div class="col-6">${clockField("end", "Término", row.end, { end: true })}</div>
    ${reservationPricingFields()}<p id="edit-reservation-error" class="text-danger small mb-0" role="alert"></p>
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Guardar cambios</button></div></form>`);
  updateReservationQuote($('edit-reservation-form'));
}
function saveReservationEdit(form) {
  const row = reservations.find(entry => entry.id === Number(form.dataset.reservationId));
  if (!row || !['pending', 'confirmed'].includes(row.status)) return;
  const values = Object.fromEntries(new FormData(form));
  const court = Number(values.court);
  const error = $('edit-reservation-error');
  const client = demoClients.find(entry => entry.id === Number(values.clientId));
  if (!client || (!clientActive(client) && client.id !== row.clientId) ||
      (!courtAvailable(court) && court !== row.court) || minutes(values.end) <= minutes(values.start)) {
    error.textContent = 'Selecciona un cliente y un horario válido.';
    return;
  }
  const proposed = { ...row, court, date: values.date, start: values.start, end: values.end };
  const occupied = allBookings().filter(other => overlaps(other, proposed));
  if (occupied.length) {
    error.textContent = `La cancha está ocupada de ${occupied[0].start} a ${occupied[0].end}.`;
    return;
  }
  const quote = reservationQuote(values, row);
  if (quote.error) { error.textContent = quote.error; return; }
  if (quote.amount < paymentSummary(row).paid) {
    error.textContent = 'El nuevo total es menor que los pagos registrados.';
    return;
  }
  Object.assign(row, { client: client.name, court, date: values.date, start: values.start, end: values.end,
    clientId: client.id, modality: values.modality, ...quote });
  selectedReservationId = row.id;
  save(`Reserva ${label(row)} actualizada.`);
}
function reservationPricingFields() {
  return '<div class="col-12"><div class="border rounded p-3 pricing-box"><h3 class="h6">Precio de la reserva</h3>' +
    '<output class="fw-semibold" data-price-preview aria-live="polite"></output></div></div>';
}

function reservationQuote(values, row = null) {
  const court = Number(values.court);
  if (!values.date || !validClock(values.start) || !validClock(values.end, true) || values.start >= values.end ||
      !courtModes(court).includes(values.modality)) return { error: 'Selecciona instalación, modalidad, fecha y horario válidos.' };
  if (row && row.court === court && row.date === values.date && row.start === values.start &&
      row.end === values.end && (row.modality || courtModes(row.court)[0]) === values.modality) {
    return { amount: row.amount, tariffIds: row.tariffIds };
  }
  if (!bookingUsesHourlyBlocks(court, values.date, values.start, values.end)) {
    return { error: 'Elige bloques consecutivos de una hora dentro del horario del recinto.' };
  }
  return automaticQuote(court, values.modality, values.date, values.start, values.end) ||
    { error: 'No hay tarifa activa para todo el horario. Revisa Tarifas.' };
}

function updateReservationQuote(form) {
  const row = reservations.find(row => row.id === Number(form.dataset.reservationId));
  const quote = reservationQuote(Object.fromEntries(new FormData(form)), row);
  const preview = form.querySelector('[data-price-preview]');
  preview.classList.toggle('text-danger', Boolean(quote.error));
  preview.classList.toggle('text-success', !quote.error);
  preview.textContent = quote.error || 'Total · ' + money.format(quote.amount);
}

document.addEventListener('input', event => {
  const form = event.target.form;
  if (form?.querySelector('[data-price-preview]')) updateReservationQuote(form);
});

document.addEventListener('change', event => {
  const form = event.target.form;
  if (event.target.name !== 'court' || !form?.elements.mode && !form?.elements.modality) return;
  const select = form.elements.mode || form.elements.modality;
  select.innerHTML = courtModes(Number(event.target.value)).map(mode => selectOption(mode, mode)).join('');
  if (form.querySelector('[data-price-preview]')) updateReservationQuote(form);
});

function submitNewReservation(element) {
  const form = Object.fromEntries(new FormData(element));
  const court = Number(form.court);
  const client = demoClients.find(entry => entry.id === Number(form.clientId));
  if (!client || !clientActive(client) || !courtAvailable(court) || minutes(form.end) <= minutes(form.start)) {
    $('form-error').textContent = 'Selecciona un cliente activo, una cancha disponible y un horario válido.';
    return;
  }
  const quote = reservationQuote(form);
  if (quote.error) { $('form-error').textContent = quote.error; return; }
  const occupied = allBookings().filter(row => overlaps(row, { court, date: form.date, start: form.start, end: form.end }));
  const tournament = occupied.find(isTournament);
  if (occupied.length) {
    $('form-error').textContent = tournament ? `La cancha está reservada para ${tournament.client} (${tournament.start}–${tournament.end}).` : 'La instalación ya está ocupada en ese horario.';
    return;
  }
  let id = Math.max(10450, ...reservations.map(r => r.id)) + 1;
  try {
    id = nextReservationId();
    localStorage.setItem('sgcd-demo-last-reservation', String(id));
  } catch { /* The ID remains unique within the current demo rows. */ }
  reservations.push({
    id, court, client: client.name, start: form.start, end: form.end, date: form.date,
    clientId: client.id,
    status: 'confirmed', origin: 'Mostrador', modality: form.modality, ...quote
  });
  date = form.date;
  if (venue) venue = courts[court][1];
  if (activePage() === 'reservas') statusFilter = '';
  courtQuery = '';
  save(`Reserva #R-${id} creada.`);
}
