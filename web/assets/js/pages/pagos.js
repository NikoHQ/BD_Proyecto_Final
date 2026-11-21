const paymentMethods = ['Efectivo', 'Débito', 'Crédito', 'Transferencia'];
const canManagePayments = () => document.body.dataset.accountRole === 'ADMINISTRADOR';

function paymentRows() {
  return normalRows().flatMap(row => (row.payments || []).map((payment, index) => ({
    id: payment.id || (row.id * 1000 + index + 1), row, payment,
    client: clientForReservation(row), date: payment.date || row.date,
    status: payment.voided ? 'ANULADO' : 'REGISTRADO'
  })));
}
function paymentSummary(row) {
  const payments = row.payments || [];
  const paid = payments.reduce((total, payment) => total + (payment.voided ? 0 : payment.amount), 0);
  if (row.status === 'cancelled') return { label: 'No aplica', className: 'cancelled', paid, remaining: 0 };
  if (paid >= row.amount && row.amount > 0) return { label: 'Pagado', className: 'completed', paid, remaining: 0 };
  if (paid > 0) return { label: `Abono ${money.format(paid)}`, className: 'pending', paid, remaining: row.amount - paid };
  return { label: 'Pendiente', className: 'pending', paid: 0, remaining: row.amount };
}
function openReservationPayment(id) {
  const row = reservations.find(entry => entry.id === id);
  if (!row || row.status === 'cancelled') return;
  const payment = paymentSummary(row);
  showDialog(`Registrar pago · ${label(row)}`, `<form id="reservation-payment-form" data-reservation-id="${id}" class="row g-3">
    <div class="col-12"><p class="mb-0"><strong>Saldo pendiente</strong> ${money.format(payment.remaining)}</p></div>
    <div class="col-sm-6"><label class="form-label">Monto<input class="form-control" name="amount" type="number" min="1" max="${payment.remaining}" value="${payment.remaining}" required></label></div>
    <div class="col-sm-6"><label class="form-label">Medio<select class="form-select" name="method"><option>Efectivo</option><option>Débito</option><option>Crédito</option><option>Transferencia</option></select></label></div>
    <p class="small text-secondary mb-0">El backend registrará el pago y validará el saldo.</p><p id="payment-error" class="text-danger small mb-0" role="alert"></p>
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Registrar pago</button></div></form>`);
}
function saveReservationPayment(form) {
  const row = reservations.find(entry => entry.id === Number(form.dataset.reservationId));
  if (!row || row.status === 'cancelled') return;
  const values = Object.fromEntries(new FormData(form));
  const payment = paymentSummary(row);
  const amount = Number(values.amount);
  if (!Number.isFinite(amount) || amount <= 0 || amount > payment.remaining) {
    $('payment-error').textContent = 'El monto debe ser mayor que cero y no superar el saldo pendiente.';
    return;
  }
  row.payments ||= [];
  row.payments.push({ amount, method: values.method, date: localClock()[0] });
  selectedReservationId = row.id;
  save(`Pago de ${money.format(amount)} registrado en la maqueta.`);
}
function paymentsDefinition(f, action) {
  return {
    title: 'Pagos', placeholder: 'ID, reserva, nombre o RUT', headers: ['Pago', 'Cliente', 'Fecha', 'Medio', 'Importe', 'Estado'],
    rows: paymentRows().filter(item => managementSearch(f.query,
      ['P-' + item.id, item.id, label(item.row), item.row.client], item.client?.rut) &&
      (!f.method || item.payment.method === f.method) && (!f.status || item.status === f.status) && (!f.date || item.date === f.date)),
    filters: managementSelect('method', 'Todos los medios', paymentMethods.map(method => [method, method]), f.method) +
      managementSelect('status', 'Todos los estados', [['REGISTRADO', 'Registrado'], ['ANULADO', 'Anulado']], f.status) +
      '<input type="date" class="form-control form-control-sm" data-management-filter="date" aria-label="Fecha del pago" value="' +
      escapeHtml(f.date || '') + '">',
    name: item => '#P-' + item.id,
    cells: item => [item.row.client, item.date, item.payment.method, money.format(item.payment.amount),
      item.payment.voided ? 'Anulado' : 'Registrado'],
    actions: item => [action('history', item.id, 'Ver reserva'),
      ...(canManagePayments() && !item.payment.voided ? [action('edit', item.id, 'Editar'),
        action('ask-delete', item.id, 'Anular pago de la maqueta', true)] : [])],
    details: item => managementDetails('Detalle de pago', [
      ['Movimiento', '#P-' + item.id], ['Reserva', label(item.row)], ['Cliente', item.row.client], ['RUT', item.client?.rut],
      ['Fecha', item.date], ['Medio', item.payment.method], ['Importe', money.format(item.payment.amount)],
      ['Saldo de la reserva', money.format(paymentSummary(item.row).remaining)],
      ['Estado', item.payment.voided ? 'Anulado' : 'Registrado'], ['Motivo de anulación', item.payment.voidReason]
    ].filter(([key, value]) => key !== 'Motivo de anulación' || value),
    canManagePayments() && !item.payment.voided ? button('manage-edit-' + item.id, 'Editar pago') : '')
  };
}

function editPayment(item) {
  if (!canManagePayments() || item.payment.voided) return;
  return managementForm('Editar pago #P-' + item.id, 'pagos', item.id,
    field('date', 'Fecha del pago', item.date, 'type="date" required') +
    field('amount', 'Importe', item.payment.amount, 'type="number" min="1" step="1" required') +
    editSelect('method', 'Medio', paymentMethods.map(method => [method, method]), item.payment.method));
}

function savePayment(id, data, error) {
  const item = paymentRows().find(payment => payment.id === id);
  if (!item || !canManagePayments() || item.payment.voided) return error('Se requiere permiso de administrador.');
  const amount = Number(data.amount);
  const others = paymentSummary(item.row).paid - item.payment.amount;
  if (!Number.isSafeInteger(amount) || amount <= 0 || amount + others > item.row.amount) {
    return error('El importe debe ser positivo y no superar el saldo disponible para este pago.');
  }
  Object.assign(item.payment, { id, amount, method: data.method, date: data.date });
}
