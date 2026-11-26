const dialog = bootstrap.Modal.getOrCreateInstance($('dialog'));
const label = row => `#R-${row.id}`;
const statuses = { pending: 'Pendiente', confirmed: 'Confirmada', completed: 'Completada', cancelled: 'Cancelada', maintenance: 'Mantención' };
const statusIcons = { pending: 'hourglass-split', confirmed: 'check-circle', completed: 'check2-all', cancelled: 'x-circle', maintenance: 'tools' };
const badge = state => `<span class="status ${state}">${icon(statusIcons[state])} ${statuses[state]}</span>`;
const button = (action, name, opts = '') => `<button type="button" class="btn ${opts || 'btn-outline-secondary btn-sm'}" data-action="${action}">${name}</button>`;
const details = (row, name = 'Ver') => `<button type="button" class="btn btn-outline-secondary btn-sm" data-id="${row.id}" aria-label="Ver ${label(row)}">${name}</button>`;

function heading(title, description, actions = '') {
  return `<div class="page-head"><div><h1>${title}</h1>${description ? `<p>${description}</p>` : ''}</div>${actions ? `<div class="toolbar">${actions}</div>` : ''}</div>`;
}
function card(title, content, actions = '') {
  return `<section class="card mb-0 h-100"><div class="card-header d-flex justify-content-between align-items-center flex-wrap gap-2"><h2 class="card-title mb-0">${title}</h2>${actions}</div>${content}</section>`;
}
function table(headers, rows, empty = 'Sin resultados para mostrar.', rowAttributes = () => '') {
  if (!rows.length) return `<p class="empty">${empty}</p>`;
  return `<div class="table-responsive"><table class="table table-hover align-middle mb-0"><thead><tr>${headers.map(h => `<th scope="col">${h}</th>`).join('')}</tr></thead><tbody>${rows.map((row, index) => `<tr ${rowAttributes(index)}>${row.map(cell => `<td>${cell}</td>`).join('')}</tr>`).join('')}</tbody></table></div>`;
}
function metric(symbol, name, value) {
  return `<div class="col-6 col-xl-3"><div class="card mb-0 h-100"><div class="card-body metric"><span class="metric-icon">${icon(symbol)}</span><div><span class="metric-label">${name}</span><strong class="metric-value">${value}</strong></div></div></div></div>`;
}
function showDialog(title, body) {
  $('dialog-title').textContent = title;
  $('dialog-body').innerHTML = body;
  dialog.show();
}
const selectOption = (value, name, selected = false) =>
  `<option value="${escapeHtml(value)}"${selected ? ' selected' : ''}>${escapeHtml(name)}</option>`;
const modalActions = label => `<div class="d-flex justify-content-end flex-wrap gap-2 mt-3">
  <button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cerrar</button>
  <button type="submit" class="btn btn-accent">${label}</button></div>`;
function field(name, label, value = '', options = '') {
  return '<label class="form-label w-100">' + label + '<input class="form-control" name="' + name +
    '" value="' + escapeHtml(value ?? '') + '" ' + options + '></label>';
}

const clockPattern = '([01][0-9]|2[0-3]):[0-5][0-9]';
const endClockPattern = clockPattern + '|24:00';
function validClock(value, allowMidnight = false) {
  return new RegExp('^(?:' + (allowMidnight ? endClockPattern : clockPattern) + ')$').test(value);
}

function clockField(name, label, value = '', { required = true, end = false } = {}) {
  return field(name, label, value, 'type="text" maxlength="5" autocomplete="off" placeholder="HH:MM" ' +
    'pattern="' + (end ? endClockPattern : clockPattern) + '" title="' +
    (end ? 'Formato de 24 horas, de 00:00 a 24:00' : 'Formato de 24 horas, de 00:00 a 23:59') + '"' +
    (required ? ' required' : ''));
}

function editSelect(name, label, values, value) {
  return '<label class="form-label w-100">' + label + '<select class="form-select" name="' + name + '">' +
    values.map(([key, text]) => selectOption(key, text, key === value)).join('') + '</select></label>';
}

function managementForm(title, page, id, fields) {
  showDialog(title, '<form id="management-edit" data-page="' + page + '" data-record="' + id + '">' + fields +
    '<p class="text-danger small" role="alert" id="management-error"></p>' + modalActions('Guardar cambios') + '</form>');
}
function feedback(message) {
  const toast = document.createElement('div');
  toast.className = 'toast text-bg-dark border-0';
  toast.innerHTML = `<div class="d-flex"><div class="toast-body">${escapeHtml(message)}</div><button class="btn-close btn-close-white me-2 m-auto" data-bs-dismiss="toast" aria-label="Cerrar aviso"></button></div>`;
  $('notice').append(toast);
  toast.addEventListener('hidden.bs.toast', () => toast.remove());
  new bootstrap.Toast(toast).show();
}
