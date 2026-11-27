'use strict';

let rangoPagos = { desde: '', hasta: '' };
let pagosRegistrados = [];
let reservasPorCobrarLista = [];
let pagosCargados = false;
let pagosPendientesPage = 1;
let pagosRegistradosPage = 1;
let pagosPendientesPageSize = 10;
let pagosRegistradosPageSize = 10;

const canManagePayments = () => document.body.dataset.accountRole === 'ADMINISTRADOR';

function rangoPorDefecto() {
  const hoy = localClock()[0];
  const desde = new Date(`${hoy}T12:00:00`);
  desde.setDate(desde.getDate() - 30);
  return { desde: desde.toISOString().slice(0, 10), hasta: hoy };
}

async function cargarPagos() {
  if (!rangoPagos.desde) rangoPagos = rangoPorDefecto();
  const [pagos, porCobrar] = await Promise.all([
    pagosApi.listar(rangoPagos.desde, rangoPagos.hasta),
    pagosApi.pendientes()
  ]);
  pagosRegistrados = pagos;
  reservasPorCobrarLista = porCobrar;
  pagosCache.clear();
  for (const pago of pagos) {
    pagosCache.set(pago.reserva, { id: pago.id, importe: pago.importe, medio: pago.medio, estado: pago.estado, fecha: pago.fecha });
  }
  pagosCargados = true;
}

function totalesPagos() {
  const cobrado = pagosRegistrados.filter(pago => pago.estado === 'PAGADO').reduce((suma, pago) => suma + pago.importe, 0);
  const anulado = pagosRegistrados.filter(pago => pago.estado === 'ANULADO').reduce((suma, pago) => suma + pago.importe, 0);
  const pendiente = reservasPorCobrarLista.reduce((suma, reserva) => suma + reserva.importe, 0);
  return { cobrado, anulado, pendiente };
}

function paginarPagos(items, page, pageSize) {
  const pages = Math.max(1, Math.ceil(items.length / pageSize));
  const actual = Math.min(Math.max(1, page), pages);
  const start = (actual - 1) * pageSize;
  return { page: actual, pages, start, items: items.slice(start, start + pageSize) };
}

function paymentPagination(kind, pagina, total, totalPaginas, pageSize) {
  if (!total) return '';
  return `<div class="payment-pagination"><span>Mostrando ${(pagina - 1) * pageSize + 1}–${Math.min(pagina * pageSize, total)} de ${total}</span>
    <div class="toolbar"><label>Filas <select id="pagos-${kind}-page-size" class="form-select form-select-sm" aria-label="Filas por página">${[5, 10, 20, 50].map(size => `<option value="${size}" ${size === pageSize ? 'selected' : ''}>${size}</option>`).join('')}</select></label>
      <button class="btn btn-sm btn-light border" data-action="pagos-${kind}-previous" ${pagina === 1 ? 'disabled' : ''}>${icon('chevron-left')}</button><span class="small">${pagina} / ${totalPaginas}</span><button class="btn btn-sm btn-light border" data-action="pagos-${kind}-next" ${pagina === totalPaginas ? 'disabled' : ''}>${icon('chevron-right')}</button></div>
  </div>`;
}

function tablaPagos() {
  const pagina = paginarPagos(pagosRegistrados, pagosRegistradosPage, pagosRegistradosPageSize);
  pagosRegistradosPage = pagina.page;
  const filas = pagina.items.map(pago => [
    `<strong>#P-${pago.id}</strong>`,
    `<button class="payment-reservation-link" type="button" data-id="${pago.reserva}">#R-${pago.reserva}</button>`,
    escapeHtml(pago.cliente || 'Bloque de torneo'),
    pago.fecha,
    escapeHtml(pagosMedios[pago.medio] || pago.medio),
    money.format(pago.importe),
    `<span class="status ${pago.estado === 'PAGADO' ? 'completed' : 'cancelled'}">${pago.estado === 'PAGADO' ? 'Registrado' : 'Anulado'}</span>`,
    pago.estado === 'PAGADO' && canManagePayments() ? `<button class="btn btn-outline-danger btn-sm" data-action="void-payment-${pago.reserva}">Anular</button>` : ''
  ]);
  return `${table(['Pago', 'Reserva', 'Cliente', 'Fecha', 'Medio', 'Importe', 'Estado', ''], filas, 'No hay pagos en el rango elegido.')}${paymentPagination('registrados', pagina.page, pagosRegistrados.length, pagina.pages, pagosRegistradosPageSize)}`;
}

function tablaPorCobrar() {
  const pagina = paginarPagos(reservasPorCobrarLista, pagosPendientesPage, pagosPendientesPageSize);
  pagosPendientesPage = pagina.page;
  const filas = pagina.items.map(reserva => [
    `<button class="payment-reservation-link" type="button" data-id="${reserva.reserva}">#R-${reserva.reserva}</button>`,
    escapeHtml(reserva.cliente || '—'),
    escapeHtml(reserva.cancha),
    String(reserva.inicio).slice(0, 16),
    money.format(reserva.importe),
    canManagePayments() ? `<button class="btn btn-accent btn-sm" data-action="payment-reservation-${reserva.reserva}">Cobrar</button>` : ''
  ]);
  return `${table(['Reserva', 'Cliente', 'Cancha', 'Inicio', 'Importe', ''], filas, 'Todas las reservas confirmadas tienen pago.')}${paymentPagination('pendientes', pagina.page, reservasPorCobrarLista.length, pagina.pages, pagosPendientesPageSize)}`;
}

function paymentsView() {
  const totales = totalesPagos();
  const periodo = `<section class="card payment-period mb-3"><div class="card-body"><div class="d-flex flex-wrap align-items-end justify-content-between gap-3"><div><h2 class="h6 mb-1">Periodo de consulta</h2><p class="small text-secondary mb-0">Los totales y pagos registrados se actualizan al cambiar las fechas.</p></div><div class="toolbar"><label class="small mb-0">Desde <input type="date" id="pagos-desde" class="form-control" value="${rangoPagos.desde}" max="${rangoPagos.hasta}"></label><span class="payment-period-separator" aria-hidden="true">—</span><label class="small mb-0">Hasta <input type="date" id="pagos-hasta" class="form-control" value="${rangoPagos.hasta}" min="${rangoPagos.desde}"></label></div><div class="btn-group btn-group-sm" role="group" aria-label="Periodos rápidos"><button class="btn btn-light border" data-action="pagos-period-30">Últimos 30 días</button><button class="btn btn-light border" data-action="pagos-period-month">Este mes</button></div></div></div></section>`;
  return `${heading('Pagos', 'Cobros por adelantado y anulaciones. Solo administración.')}
    ${periodo}
    <div class="row g-2 mb-3">
      ${metric('cash-coin', 'Cobrado en el rango', money.format(totales.cobrado))}
      ${metric('exclamation-octagon', 'Anulado', money.format(totales.anulado))}
      ${metric('hourglass-split', 'Por cobrar', money.format(totales.pendiente))}
      ${metric('receipt', 'Pagos registrados', String(pagosRegistrados.length))}
    </div>
    <div class="row g-3">
      <div class="col-12 col-xxl-6">${card('Reservas por cobrar', `<div class="card-body p-0">${tablaPorCobrar()}</div>`)}</div>
      <div class="col-12 col-xxl-6">${card('Pagos registrados', `<div class="card-body p-0">${tablaPagos()}</div>`)}</div>
    </div>`;
}

async function refreshPayments() {
  if (!rangoPagos.desde || !rangoPagos.hasta) return;
  if (rangoPagos.desde > rangoPagos.hasta) return feedback('La fecha inicial no puede ser posterior a la fecha final.');
  pagosPendientesPage = 1;
  pagosRegistradosPage = 1;
  pagosCargados = false;
  try {
    await cargarPagos();
    render();
  } catch (error) {
    feedback(error.message);
  }
}

function aplicarPeriodoPagos(tipo) {
  const hoy = localClock()[0];
  const fecha = new Date(`${hoy}T12:00:00`);
  if (tipo === '30') {
    fecha.setDate(fecha.getDate() - 30);
  } else {
    fecha.setDate(1);
  }
  rangoPagos = { desde: fecha.toISOString().slice(0, 10), hasta: hoy };
  return refreshPayments();
}

async function openReservationPayment(id) {
  const row = reservaPorId(Number(id));
  const pendiente = reservasPorCobrarLista.find(entrada => entrada.reserva === Number(id));
  let saldo = row?.importe ?? pendiente?.importe ?? 0;
  let pago = null;
  try {
    pago = await pagosApi.ver(Number(id));
    saldo = pago ? Number(pago.saldo) : saldo;
  } catch (error) {
    feedback(error.message);
    return;
  }
  if (pago && pago.estado === 'PAGADO') {
    feedback('La reserva ya tiene un pago vigente.');
    return;
  }
  showDialog(`Registrar pago · #R-${id}`, `<form id="reservation-payment-form" data-reservation-id="${id}" class="row g-3">
    <div class="col-12"><p class="mb-0"><strong>Cliente</strong> ${escapeHtml(row?.cliente || pendiente?.cliente || '—')}</p>
      <p class="mb-0"><strong>Saldo pendiente</strong> ${money.format(saldo)}</p></div>
    <div class="col-sm-6"><label class="form-label">Monto<input class="form-control" name="amount" type="number" value="${saldo}" readonly></label></div>
    <div class="col-sm-6"><label class="form-label">Medio<select class="form-select" name="method">${Object.entries(pagosMedios).map(([, nombre]) => `<option>${nombre}</option>`).join('')}</select></label></div>
    <p class="small text-secondary mb-0">El pago es por el importe exacto acordado; el backend valida el estado y el doble cobro.</p>
    <p id="payment-error" class="text-danger small mb-0" role="alert"></p>
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Registrar pago</button></div></form>`);
}

async function saveReservationPayment(form) {
  const id = Number(form.dataset.reservationId);
  const valores = Object.fromEntries(new FormData(form));
  const medio = mediosPagoApi[valores.method];
  const error = $('payment-error');
  error.textContent = '';
  try {
    await pagosApi.registrar(id, medio);
    dialog.hide();
    await recargarAgenda(date);
    pagosCargados = false;
    await cargarPagos();
    feedback(`Pago registrado en #R-${id}.`);
    render();
  } catch (fallo) {
    error.textContent = fallo.message;
  }
}

function requestVoidPayment(reserva) {
  showDialog('Anular pago', `<p>Se anulará el pago de <strong>#R-${reserva}</strong> y el saldo volverá a quedar pendiente.</p>
    ${button(`confirm-void-payment-${reserva}`, 'Confirmar anulación', 'btn-danger')}`);
}

async function voidPayment(reserva) {
  try {
    await pagosApi.anular(reserva);
    dialog.hide();
    await recargarAgenda(date);
    pagosCargados = false;
    await cargarPagos();
    feedback('Pago anulado.');
    render();
  } catch (error) {
    feedback(error.message);
  }
}
