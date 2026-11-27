'use strict';

let statusFilter = '';
let reservationQuery = '';
let reservationCourtFilter = '';
let reservationOriginFilter = '';
let reservationDateScope = 'today';
let selectedReservationId = null;
let reservationPage = 1;
let reservationPageSize = 10;

/** Pagos ya consultados, por reserva. La fuente sigue siendo SGCD_PKG_PAGOS. */
const pagosCache = new Map();
const pagosMedios = { EFECTIVO: 'Efectivo', DEBITO: 'Débito', CREDITO: 'Crédito', TRANSFERENCIA: 'Transferencia' };
const mediosPagoApi = Object.fromEntries(Object.entries(pagosMedios).map(([api, ui]) => [ui, api]));


function paymentSummary(row) {
  const pago = pagosCache.get(row.id);
  const acordado = Number(row.importe);
  const pagado = pago && pago.estado === 'PAGADO' ? Number(pago.importe) : 0;
  if (pago?.estado === 'ANULADO') return { label: 'Anulado', className: 'cancelled', paid: 0, remaining: acordado };
  if (pagado > 0) return { label: 'Pagado', className: 'completed', paid: pagado, remaining: Math.max(0, acordado - pagado) };
  return { label: 'Pendiente', className: 'pending', paid: 0, remaining: acordado };
}

const canRegisterReservationPayment = row =>
  !row.torneoId && row.estado === 'confirmed' && document.body.dataset.accountRole === 'ADMINISTRADOR';

const reservationStateLabel = row => row.torneoId ? tournamentBadge() : badge(row.estado);
const esSolicitudWebPendiente = row => !row.torneoId && row.origen === 'Web' && row.estado === 'pending';
const puedeResolverSolicitudWeb = row => esSolicitudWebPendiente(row) && document.body.dataset.accountRole === 'ADMINISTRADOR';

function reservationActionsMenu(row) {
  if (row.torneoId) return `<div class="dropdown"><button class="btn btn-outline-secondary btn-sm" type="button" data-bs-toggle="dropdown" aria-label="Acciones de ${label(row)}">${icon('three-dots-vertical')}</button><ul class="dropdown-menu dropdown-menu-end"><li><button class="dropdown-item" data-action="reservation-menu-${row.id}">Ver detalle</button></li></ul></div>`;
  const solicitudWeb = esSolicitudWebPendiente(row);
  const editable = ['pending', 'confirmed'].includes(row.estado) && !solicitudWeb;
  return `<div class="dropdown"><button class="btn btn-outline-secondary btn-sm" type="button" data-bs-toggle="dropdown" aria-label="Acciones de ${label(row)}">${icon('three-dots-vertical')}</button><ul class="dropdown-menu dropdown-menu-end">
    <li><button class="dropdown-item" data-action="reservation-menu-${row.id}">Ver detalle</button></li>
    ${puedeResolverSolicitudWeb(row) ? `<li><button class="dropdown-item" data-action="confirm-${row.id}">Aprobar solicitud</button></li><li><button class="dropdown-item text-danger" data-action="ask-cancel-${row.id}">Rechazar solicitud</button></li>` : ''}
    ${row.estado === 'pending' && !solicitudWeb && document.body.dataset.accountRole === 'ADMINISTRADOR' ? `<li><button class="dropdown-item" data-action="confirm-${row.id}">Confirmar</button></li>` : ''}
    ${editable ? `<li><button class="dropdown-item" data-action="edit-reservation-${row.id}">Reprogramar</button></li>` : ''}
    ${canRegisterReservationPayment(row) ? `<li><button class="dropdown-item" data-action="payment-reservation-${row.id}">Registrar pago</button></li>` : ''}
    ${editable ? `<li><hr class="dropdown-divider"></li><li><button class="dropdown-item text-danger" data-action="ask-cancel-${row.id}">Cancelar reserva</button></li>` : ''}
  </ul></div>`;
}

function solicitudesWebPendientes(rows) {
  if (!rows.length) return '';
  const items = [...rows]
    .sort((a, b) => a.fecha.localeCompare(b.fecha) || a.start.localeCompare(b.start))
    .map(row => `<tr data-reservation="${row.id}">
      <td><strong>${escapeHtml(row.cliente)}</strong><small class="d-block text-secondary">${label(row)}</small></td>
      <td>${escapeHtml(row.cancha)}<small class="d-block text-secondary">${escapeHtml(row.modalidad)}</small></td>
      <td>${dayLabel(row.fecha)}<small class="d-block text-secondary">${row.start}–${row.end}</small></td>
      <td>${money.format(row.importe)}</td>
      <td><div class="d-flex flex-wrap gap-1 justify-content-end">${button(`confirm-${row.id}`, 'Aprobar', 'btn-accent btn-sm')}${button(`ask-cancel-${row.id}`, 'Rechazar solicitud', 'btn btn-outline-danger btn-sm')}</div></td>
    </tr>`).join('');
  return `<section class="card mb-3"><div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2"><div><h2 class="card-title mb-0">Solicitudes web pendientes</h2><p class="small text-secondary mb-0">Aprueba o rechaza las reservas solicitadas por clientes antes de ocupar la cancha.</p></div><span class="status pending">${icon('hourglass-split')} ${rows.length}</span></div><div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead><tr><th>Cliente</th><th>Cancha</th><th>Fecha y horario</th><th>Total</th><th class="text-end">Decisión</th></tr></thead><tbody>${items}</tbody></table></div></section>`;
}

function reservationFilters(rows) {
  const term = normalizeName(reservationQuery);
  return rows.filter(row => {
    const matchText = !term || [label(row), row.cliente, row.cancha].some(value =>
      normalizeName(String(value ?? '')).includes(term));
    const matchDate = reservationDateScope === 'all' || row.fecha === date;
    const matchStatus = !statusFilter || row.estado === statusFilter;
    const matchCourt = reservationCourtFilter === '' || row.canchaId === Number(reservationCourtFilter);
    const matchOrigin = !reservationOriginFilter || row.origen === reservationOriginFilter;
    return matchText && matchDate && matchStatus && matchCourt && matchOrigin;
  }).sort((a, b) => a.fecha.localeCompare(b.fecha) || a.start.localeCompare(b.start));
}

function reservationDetailPanel(row) {
  if (!row) return card('Detalle de reserva', '<div class="card-body"><p class="empty px-0">Selecciona una reserva para ver sus datos y acciones.</p></div>');
  const solicitudWeb = esSolicitudWebPendiente(row);
  const editable = ['pending', 'confirmed'].includes(row.estado) && !row.torneoId && !solicitudWeb;
  const actions = puedeResolverSolicitudWeb(row)
    ? button(`confirm-${row.id}`, 'Aprobar solicitud', 'btn-accent w-100')
    : row.estado === 'pending' && document.body.dataset.accountRole === 'ADMINISTRADOR'
      ? button(`confirm-${row.id}`, 'Confirmar reserva', 'btn-accent w-100') : '';
  return card('Detalle de reserva', `<div class="card-body reservation-detail">
    <div class="d-flex justify-content-between gap-2 align-items-start"><strong class="fs-5">${label(row)}</strong>${reservationStateLabel(row)}</div>
    <dl class="detail-list">
      <dt>${icon('person')} Cliente</dt><dd>${escapeHtml(row.cliente)}</dd>
      <dt>${icon('geo-alt')} Cancha</dt><dd>${escapeHtml(row.cancha)} · ${escapeHtml(nombreRecinto(canchaPorId(row.canchaId)?.recinto))}</dd>
      <dt>${icon('calendar3')} Fecha</dt><dd>${dayLabel(row.fecha)}</dd>
      <dt>${icon('clock')} Horario</dt><dd>${row.start}–${row.end}</dd>
      <dt>${icon('dribbble')} Modalidad</dt><dd>${escapeHtml(row.modalidad)}</dd>
      <dt>${icon('share')} Origen</dt><dd>${escapeHtml(row.origen)}</dd>
      <dt>${icon('cash-stack')} Total</dt><dd>${money.format(row.importe)}</dd>
    </dl>
    <div class="d-grid gap-2 mt-3">${actions}${solicitudWeb && puedeResolverSolicitudWeb(row) ? button(`ask-cancel-${row.id}`, 'Rechazar solicitud', 'btn btn-outline-danger') : ''}${editable ? button(`edit-reservation-${row.id}`, `${icon('pencil')} Reprogramar`, 'btn btn-light border') : ''}${canRegisterReservationPayment(row) ? button(`payment-reservation-${row.id}`, `${icon('credit-card')} Registrar pago`, 'btn btn-light border') : ''}${editable ? button(`ask-cancel-${row.id}`, 'Cancelar reserva', 'btn btn-outline-danger') : ''}</div>
  </div>`);
}

function reservationsView() {
  const allRows = reservasPanel();
  const filtered = reservationFilters(allRows);
  const pageCount = Math.max(1, Math.ceil(filtered.length / reservationPageSize));
  reservationPage = Math.min(reservationPage, pageCount);
  const pageStart = (reservationPage - 1) * reservationPageSize;
  const visibleRows = filtered.slice(pageStart, pageStart + reservationPageSize);
  if (!selectedReservationId || !allRows.some(row => row.id === selectedReservationId)) selectedReservationId = visibleRows[0]?.id || null;
  const selected = allRows.find(row => row.id === selectedReservationId);
  const todayRows = allRows.filter(row => row.fecha === date && row.estado !== 'cancelled');
  const webPendingRows = allRows.filter(esSolicitudWebPendiente);
  const projected = todayRows.filter(row => !row.torneoId).reduce((sum, row) => sum + row.importe, 0);
  const statusOptions = `<option value="">Todos los estados</option>${Object.entries(statuses).filter(([key]) => key !== 'maintenance').map(([key, value]) => `<option value="${key}" ${key === statusFilter ? 'selected' : ''}>${value}</option>`).join('')}`;
  const courtOptions = `<option value="">Todas las canchas</option>${panel.canchas.map(cancha => `<option value="${cancha.id}" ${reservationCourtFilter !== '' && Number(reservationCourtFilter) === cancha.id ? 'selected' : ''}>${escapeHtml(cancha.nombre)} · ${escapeHtml(nombreRecinto(cancha.recinto))}</option>`).join('')}`;
  const origins = ['', 'Web', 'Mostrador', 'Torneo'];
  const tableRows = visibleRows.map(row => `<tr class="${row.id === selectedReservationId ? 'is-selected' : ''}" data-reservation="${row.id}">
      <td><button class="reservation-link" data-reservation="${row.id}">${label(row)}</button></td><td>${escapeHtml(row.cliente)}</td><td>${escapeHtml(row.cancha)}</td><td>${row.start}–${row.end}</td>
      <td>${reservationStateLabel(row)}</td><td>${money.format(row.importe)}</td><td>${escapeHtml(row.origen)}</td>
      <td>${reservationActionsMenu(row)}</td></tr>`).join('');
  const actions = button('new', `${icon('plus-lg')} Nueva reserva`, 'btn-accent');
  return `${heading('Reservas', 'Gestiona reservas, confirmaciones y pagos.', actions)}
    <div class="row g-2 mb-3">${metric('calendar2-check', 'Reservas del día', todayRows.length)}${metric('hourglass-split', 'Solicitudes web por resolver', webPendingRows.length)}${metric('exclamation-triangle', 'Torneos del día', todayRows.filter(row => row.torneoId).length)}${metric('cash-stack', 'Ingresos del día', money.format(projected))}</div>
    ${solicitudesWebPendientes(webPendingRows)}
    <div class="row g-3 align-items-start reservation-layout"><div class="col-12 col-xxl-9">${card(`Reservas del ${dateLabel.format(new Date(`${date}T12:00:00`))}`, `<div class="card-body border-bottom reservation-tools">
      <div class="toolbar"><input id="reservation-query" type="search" class="form-control" value="${escapeHtml(reservationQuery)}" placeholder="Buscar por ID, cliente o cancha" aria-label="Buscar reservas"><div class="btn-group" role="group" aria-label="Periodo"><button class="btn btn-sm ${reservationDateScope === 'today' ? 'btn-accent' : 'btn-light border'}" data-action="reservation-today">Día</button><button class="btn btn-sm ${reservationDateScope === 'all' ? 'btn-accent' : 'btn-light border'}" data-action="reservation-all">Todas</button></div></div>
      <div class="toolbar mt-2"><select id="reservation-status" class="form-select" aria-label="Filtrar por estado">${statusOptions}</select><select id="reservation-court" class="form-select" aria-label="Filtrar por cancha">${courtOptions}</select><select id="reservation-origin" class="form-select" aria-label="Filtrar por origen">${origins.map(origin => `<option value="${origin}" ${origin === reservationOriginFilter ? 'selected' : ''}>${origin || 'Todos los orígenes'}</option>`).join('')}</select><button class="btn btn-link ms-auto" data-action="clear-reservation-filters">Limpiar filtros</button></div></div>
      ${filtered.length ? `<div class="table-responsive"><table class="table table-hover reservation-table mb-0"><thead><tr><th>ID</th><th>Cliente</th><th>Cancha</th><th>Horario</th><th>Estado</th><th>Importe</th><th>Origen</th><th></th></tr></thead><tbody>${tableRows}</tbody></table></div><div class="reservation-pagination"><span>Mostrando ${pageStart + 1}–${Math.min(pageStart + reservationPageSize, filtered.length)} de ${filtered.length}</span><div class="toolbar"><label>Filas <select id="reservation-page-size" class="form-select form-select-sm" aria-label="Filas por página">${[5, 10, 20, 50].map(size => `<option value="${size}" ${size === reservationPageSize ? 'selected' : ''}>${size}</option>`).join('')}</select></label><button class="btn btn-sm btn-light border" data-action="reservation-previous" ${reservationPage === 1 ? 'disabled' : ''}>${icon('chevron-left')}</button><span class="small">${reservationPage} / ${pageCount}</span><button class="btn btn-sm btn-light border" data-action="reservation-next" ${reservationPage === pageCount ? 'disabled' : ''}>${icon('chevron-right')}</button></div></div>` : '<p class="empty">No hay reservas para los filtros aplicados.</p>'}`) }</div><div class="col-12 col-xxl-3">${reservationDetailPanel(selected)}</div></div>`;
}

/* ------------------------------------------------------------------ */
/* Alta y reprogramación                                               */
/* ------------------------------------------------------------------ */

let clienteSeleccionado = null;
let clienteBusqueda = null;
let clientesEncontrados = [];

function clientPickerFields() {
  const text = clienteSeleccionado ? `${clienteSeleccionado.nombre} · ${clienteSeleccionado.rut}` : '';
  return `<div class="col-12"><label class="form-label" for="reservation-client-query">Cliente</label>
    <input class="form-control" type="search" id="reservation-client-query" value="${escapeHtml(text)}" placeholder="Escribe el RUT o nombre del cliente" autocomplete="off">
    <input type="hidden" id="reservation-client-id" name="clientId" value="${clienteSeleccionado?.id || ''}">
    <div id="reservation-client-results" class="list-group mt-1" role="group" aria-label="Coincidencias de clientes" hidden></div>
    <p id="reservation-client-status" class="small text-secondary mb-0" role="status"></p>
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

function updateReservationClientResults() {
  const query = $('reservation-client-query')?.value.trim() || '';
  const lista = $('reservation-client-results');
  const estado = $('reservation-client-status');
  if (!lista) return;
  clearTimeout(clienteBusqueda);
  if (query.length < 2) {
    lista.hidden = true;
    lista.replaceChildren();
    estado.textContent = '';
    return;
  }
  clienteBusqueda = setTimeout(async () => {
    try {
      const datos = await clientesApi.buscar(query);
      clientesEncontrados = datos.items;
      lista.innerHTML = clientesEncontrados.map(cliente =>
        button(`select-reservation-client-${cliente.id}`, escapeHtml(`${cliente.nombre} · ${cliente.rut}`), 'list-group-item list-group-item-action text-start')
      ).join('');
      if (!clientesEncontrados.length && parseRut(query)) {
        lista.innerHTML = button('open-reservation-client-create', `Crear cliente con RUT ${escapeHtml(parseRut(query))}`, 'list-group-item list-group-item-action text-start');
      }
      lista.hidden = !lista.children.length;
      estado.textContent = datos.total > clientesEncontrados.length ? 'Se muestran las primeras coincidencias. Afina la búsqueda.' : '';
      if (!clientesEncontrados.length && !parseRut(query)) estado.textContent = 'Sin coincidencias. Para crear una ficha, ingresa el RUT completo con DV.';
    } catch (error) {
      estado.textContent = error.message;
    }
  }, 250);
}

function selectReservationClient(cliente) {
  clienteSeleccionado = cliente;
  $('reservation-client-id').value = cliente.id;
  $('reservation-client-query').value = `${cliente.nombre} · ${cliente.rut}`;
  $('reservation-client-status').textContent = 'Cliente seleccionado.';
  $('reservation-client-results').hidden = true;
  $('reservation-client-results').replaceChildren();
}

function toggleReservationClientCreate(open) {
  const campos = $('reservation-client-create-fields');
  const consulta = $('reservation-client-query');
  if (!campos) return;
  campos.hidden = !open;
  campos.disabled = !open;
  consulta.readOnly = open;
  if (open) {
    campos.querySelector('[name="reservationClientRut"]').value = parseRut(consulta.value) || '';
    $('reservation-client-results').hidden = true;
    campos.querySelector('input').focus();
  } else {
    consulta.focus();
  }
}

async function saveReservationClient() {
  const campos = $('reservation-client-create-fields');
  if ([...campos.querySelectorAll('input')].some(field => !field.reportValidity())) return;
  const error = $('reservation-client-create-error');
  const datos = {
    nombre: campos.querySelector('[name="reservationClientName"]').value.trim(),
    rut: campos.querySelector('[name="reservationClientRut"]').value.trim(),
    telefono: campos.querySelector('[name="reservationClientPhone"]').value.trim(),
    correo: campos.querySelector('[name="reservationClientEmail"]').value.trim().toLowerCase()
  };
  error.textContent = '';
  try {
    const ficha = await clientesApi.crear(datos);
    selectReservationClient({ id: ficha.id, nombre: ficha.nombre, rut: ficha.rut });
    toggleReservationClientCreate(false);
    feedback('Ficha de cliente creada.');
  } catch (fallo) {
    error.textContent = fallo.message;
  }
}

function canchaOpciones(seleccion = null) {
  return panel.canchas.filter(cancha => canchaDisponible(cancha.id) || cancha.id === seleccion).map(cancha =>
    selectOption(cancha.id, `${cancha.nombre} · ${nombreRecinto(cancha.recinto)}`, cancha.id === seleccion)).join('');
}

function modalidadOpciones(canchaId, seleccion = null) {
  return (canchaPorId(canchaId)?.modalidades || []).map(modalidad =>
    selectOption(modalidad.id, modalidad.nombre, modalidad.id === seleccion)).join('');
}

const bloquesEntre = (inicio, fin) => (minutes(fin) - minutes(inicio)) / 60;

function camposHorario(inicio, fin) {
  return `<div class="col-6">${clockField('start', 'Inicio', inicio)}</div><div class="col-6">${clockField('end', 'Término', fin, { end: true })}</div>`;
}

function newReservation() {
  clienteSeleccionado = null;
  const cancha = panel.canchas.find(entry => canchaDisponible(entry.id) &&
    (!venue || String(entry.recinto) === String(venue))) || panel.canchas.find(entry => canchaDisponible(entry.id));
  if (!cancha) return feedback('No hay canchas disponibles para reservar.');
  showDialog('Nueva reserva', `<form id="reservation-form" class="row g-3">
    ${clientPickerFields()}
    <div class="col-12"><label class="form-label" for="court">Instalación</label><select class="form-select" id="court" name="court" required>${canchaOpciones(cancha.id)}</select></div>
    <div class="col-12">${editSelect('modality', 'Modalidad', (cancha.modalidades).map(m => [m.id, m.nombre]), cancha.modalidades[0]?.id)}</div>
    <div class="col-12"><label class="form-label" for="booking-day">Fecha</label><input type="date" id="booking-day" class="form-control" name="date" value="${date}" min="${localClock()[0]}" required></div>
    ${camposHorario('16:00', '17:00')}
    <div class="col-12"><div class="border rounded p-3 pricing-box"><h3 class="h6">Precio de la reserva</h3>
      <output class="fw-semibold" data-price-preview aria-live="polite">Completa cancha, fecha y horario.</output></div></div>
    <p class="small text-secondary mb-0">Origen: Mostrador · Estado inicial: Confirmada</p>
    <div id="form-error" class="text-danger small" role="alert"></div>
    <div class="d-flex justify-content-end"><button class="btn btn-accent" type="submit">Guardar reserva</button></div>
  </form>`);
  updateReservationQuote($('reservation-form'));
}

function editReservation(id) {
  const row = reservaPorId(id);
  if (!row || !['pending', 'confirmed'].includes(row.estado) || row.torneoId) return;
  showDialog(`Reprogramar ${label(row)}`, `<form id="edit-reservation-form" data-reservation-id="${id}" class="row g-3">
    <div class="col-12"><dl class="row mb-0"><dt class="col-4">Cliente</dt><dd class="col-8">${escapeHtml(row.cliente)}</dd>
      <dt class="col-4">Cancha</dt><dd class="col-8">${escapeHtml(row.cancha)} · ${escapeHtml(row.modalidad)}</dd></dl></div>
    <div class="col-12"><label class="form-label">Fecha<input class="form-control" type="date" name="date" value="${row.fecha}" required></label></div>
    ${camposHorario(row.start, row.end)}
    <div class="col-12"><output class="fw-semibold" data-price-preview aria-live="polite"></output></div>
    <p id="edit-reservation-error" class="text-danger small mb-0" role="alert"></p>
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Guardar cambios</button></div></form>`);
  updateReservationQuote($('edit-reservation-form'));
}

function datosReserva(form) {
  const valores = Object.fromEntries(new FormData(form));
  const canchaId = Number(valores.court ?? reservaPorId(Number(form.dataset.reservationId))?.canchaId);
  const modalidadId = Number(valores.modality ?? reservaPorId(Number(form.dataset.reservationId))?.modalidadId);
  return { cancha: canchaId, modalidad: modalidadId, fecha: valores.date || valores.fecha, hora: valores.start,
    bloques: bloquesEntre(valores.start, valores.end) };
}

async function updateReservationQuote(form) {
  const preview = form?.querySelector('[data-price-preview]');
  if (!preview) return;
  const datos = datosReserva(form);
  if (!datos.fecha || !validClock(datos.hora) || !validClock((new FormData(form)).get('end') || '', true) ||
      !Number.isInteger(datos.bloques) || datos.bloques < 1) {
    preview.textContent = 'Elige una fecha y un horario de bloques completos.';
    preview.classList.add('text-danger');
    return;
  }
  preview.textContent = 'Consultando tarifa…';
  try {
    const cotizacion = await reservasApi.cotizar(datos);
    preview.textContent = 'Total · ' + money.format(cotizacion.total);
    preview.classList.remove('text-danger');
    preview.classList.add('text-success');
  } catch (error) {
    preview.textContent = error.message;
    preview.classList.add('text-danger');
  }
}

async function submitNewReservation(form) {
  const error = $('form-error');
  error.textContent = '';
  const datos = datosReserva(form);
  if (!clienteSeleccionado) { error.textContent = 'Selecciona un cliente.'; return; }
  if (!datos.fecha || !validClock(datos.hora) || !Number.isInteger(datos.bloques) || datos.bloques < 1) {
    error.textContent = 'Elige una fecha y un horario de bloques completos.'; return;
  }
  try {
    const { id } = await reservasApi.crear({ ...datos, cliente: clienteSeleccionado.id });
    date = datos.fecha;
    dialog.hide();
    await recargarAgenda(date);
    feedback(`Reserva #R-${id} creada.`);
    render();
  } catch (fallo) {
    error.textContent = fallo.message;
  }
}

async function saveReservationEdit(form) {
  const row = reservaPorId(Number(form.dataset.reservationId));
  const error = $('edit-reservation-error');
  if (!row) return;
  const datos = datosReserva(form);
  if (!datos.fecha || !validClock(datos.hora) || !Number.isInteger(datos.bloques) || datos.bloques < 1) {
    error.textContent = 'Elige una fecha y un horario de bloques completos.'; return;
  }
  try {
    await reservasApi.reprogramar({ id: row.id, fecha: datos.fecha, hora: datos.hora, bloques: datos.bloques });
    dialog.hide();
    await recargarAgenda(datos.fecha);
    feedback(`Reserva ${label(row)} reprogramada.`);
    render();
  } catch (fallo) {
    error.textContent = fallo.message;
  }
}

document.addEventListener('input', event => {
  const form = event.target.form;
  if (form?.querySelector('[data-price-preview]')) updateReservationQuote(form);
});

document.addEventListener('change', event => {
  if (event.target.name === 'court' && $('reservation-form')) {
    const canchaId = Number(event.target.value);
    const select = $('reservation-form').elements.modality;
    select.innerHTML = modalidadOpciones(canchaId);
    updateReservationQuote($('reservation-form'));
  }
  if (event.target.id === 'booking-day' || event.target.name === 'date') {
    const form = event.target.form;
    if (form?.querySelector('[data-price-preview]')) updateReservationQuote(form);
  }
});

/** Tabla compacta de reservas para los dialogos de clientes. */
function reservationTable(rows, empty = 'Sin reservas registradas.') {
  return table(['Reserva', 'Cliente', 'Instalación', 'Horario', 'Estado', 'Importe'], rows.map(row => [
    label(row), escapeHtml(row.cliente), escapeHtml(row.cancha),
    `<span class="text-nowrap">${row.fecha} · ${row.start}–${row.end}</span>`,
    reservationStateLabel(row), money.format(row.importe)
  ]), empty);
}

function reservationDetails(id) {
  const row = reservaPorId(id);
  if (!row) return;
  const editable = ['pending', 'confirmed'].includes(row.estado) && !row.torneoId;
  const acciones = row.torneoId
    ? `<button class="btn btn-accent" type="button" data-action="tournament-agenda-${row.torneoId}">Ver torneo</button>`
    : `<div class="d-flex flex-wrap gap-2">${row.estado === 'pending' && document.body.dataset.accountRole === 'ADMINISTRADOR' ? button(`confirm-${id}`, 'Confirmar reserva', 'btn-accent') : ''}${editable ? button(`edit-reservation-${id}`, 'Reprogramar') : ''}${canRegisterReservationPayment(row) ? button(`payment-reservation-${id}`, 'Registrar pago') : ''}${editable ? button(`ask-cancel-${id}`, 'Cancelar reserva', 'btn-outline-danger') : ''}</div>`;
  showDialog(`Reserva ${label(row)}`, `
    <div class="d-flex justify-content-between align-items-start gap-2 mb-3"><strong>${escapeHtml(row.cliente)}</strong>${reservationStateLabel(row)}</div>
    <dl class="row mb-3"><dt class="col-4">Instalación</dt><dd class="col-8">${escapeHtml(row.cancha)} · ${escapeHtml(nombreRecinto(canchaPorId(row.canchaId)?.recinto))}</dd>
      <dt class="col-4">Modalidad</dt><dd class="col-8">${escapeHtml(row.modalidad)}</dd>
      <dt class="col-4">Horario</dt><dd class="col-8">${row.fecha} · ${row.start}–${row.end}</dd>
      <dt class="col-4">Origen</dt><dd class="col-8">${escapeHtml(row.origen)}</dd>
      <dt class="col-4">Importe</dt><dd class="col-8">${money.format(row.importe)}</dd></dl>
    ${acciones}`);
}
