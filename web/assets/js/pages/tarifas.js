'use strict';

const tarifasRuta = '/dashboardadmin/api/tarifas.php';
const estadosTarifa = { ACTIVA: 'Activa', INACTIVA: 'Inactiva' };
let tarifasAdministracion;

async function cargarTarifas() {
  if (tarifasAdministracion) return;
  if (!modalidadesAdministracion) await cargarModalidadesAdministracion();
  tarifasAdministracion = await apiGet(tarifasRuta);
}

const nombreModalidadTarifa = id => modalidadesAdministracion?.find(mode => mode.id === id)?.nombre || '';
const nombreCanchaTarifa = id => canchaPorId(id)?.nombre || '';
const tarifaFutura = tarifa => tarifa.desde > localClock()[0];
const franjaTarifa = tarifa => tarifa.inicio + '–' + tarifa.fin;
const opcionesCanchasTarifa = () => panel.canchas.map(cancha => [String(cancha.id),
  nombreRecinto(cancha.recinto) + ' · ' + cancha.nombre]);
const opcionesDiaTarifa = () => weekdays.map((dia, i) => [String(i + 1), dia]);

function accionesTarifa(tarifa) {
  const id = tarifa.id;
  const futura = tarifaFutura(tarifa);
  return [
    ...(futura ? [['manage-rate-edit-' + id, 'Editar tarifa']] : []),
    ...(futura && tarifa.estado === 'ACTIVA' && minutes(tarifa.fin) - minutes(tarifa.inicio) >= 120
      ? [['manage-rate-split-' + id, 'Dividir franja']] : []),
    ['manage-rate-toggle-' + id, tarifa.estado === 'ACTIVA' ? 'Desactivar' : 'Activar'],
    ...(futura ? [['manage-rate-confirm-' + id, 'Eliminar', true]] : [])
  ];
}

function tariffsDefinition(f) {
  const filteredCourt = String(f.court ?? '');
  return {
    title: 'Tarifas', placeholder: 'Cancha, sucursal, modalidad o día',
    description: 'Configura el valor por hora de cada franja.',
    headers: ['Tarifa', 'Modalidad', 'Día', 'Franja', 'Valor por hora', 'Estado'],
    toolbar: button('manage-new-tariff', 'Nueva tarifa', 'btn-accent'),
    filters: (panelRoute().court === undefined
      ? managementSelect('court', 'Todas las canchas', opcionesCanchasTarifa(), filteredCourt) : '') +
      managementSelect('day', 'Todos los días', opcionesDiaTarifa(), f.day) +
      managementSelect('status', 'Todos los estados', Object.entries(estadosTarifa), f.status),
    rows: (tarifasAdministracion || []).filter(tarifa =>
      (!filteredCourt || Number(filteredCourt) === tarifa.cancha) &&
      (!f.day || Number(f.day) === tarifa.dia) && (!f.status || f.status === tarifa.estado) &&
      managementSearch(f.query, [
        nombreCanchaTarifa(tarifa.cancha), nombreRecinto(canchaPorId(tarifa.cancha)?.recinto),
        nombreModalidadTarifa(tarifa.modalidad), nombreDia(tarifa.dia)
      ])),
    name: tarifa => nombreCanchaTarifa(tarifa.cancha),
    cells: tarifa => [nombreModalidadTarifa(tarifa.modalidad), nombreDia(tarifa.dia), franjaTarifa(tarifa),
      money.format(tarifa.valor), estadosTarifa[tarifa.estado]],
    actions: accionesTarifa,
    details: tarifa => managementDetails('Detalle de tarifa', [
      ['Sucursal', nombreRecinto(canchaPorId(tarifa.cancha)?.recinto)], ['Cancha', nombreCanchaTarifa(tarifa.cancha)],
      ['Modalidad', nombreModalidadTarifa(tarifa.modalidad)], ['Día', nombreDia(tarifa.dia)],
      ['Franja', franjaTarifa(tarifa)], ['Vigente desde', tarifa.desde], ['Vigente hasta', tarifa.hasta],
      ['Por hora', money.format(tarifa.valor)], ['Estado', estadosTarifa[tarifa.estado]]
    ], accionesTarifa(tarifa).map(([accion, texto, peligro]) =>
      button(accion, texto, peligro ? 'btn-outline-danger btn-sm' : '')).join(''))
  };
}

function editarTarifa(tarifa = null) {
  const canchas = panel.canchas.filter(cancha => cancha.modalidades.length || cancha.id === tarifa?.cancha);
  if (!canchas.length) return showDialog('Sin canchas con modalidades', '<p>Asigna una modalidad a una cancha antes de configurar tarifas.</p>');
  const filtrada = canchaPorId(managementState.tarifas.filters.court);
  const cancha = tarifa ? canchaPorId(tarifa.cancha) : filtrada?.modalidades.length ? filtrada : canchas[0];
  const opciones = canchas.map(entry => [String(entry.id), nombreRecinto(entry.recinto) + ' · ' + entry.nombre]);
  const dia = tarifa?.dia ?? Number(managementState.tarifas.filters.day || diaSemanaIso(localClock()[0]));
  const horas = horarioDe(cancha.recinto, dia);
  const selectCancha = editSelect('cancha', 'Cancha', opciones, String(cancha.id));
  managementForm(tarifa ? 'Editar tarifa' : 'Nueva tarifa', 'tariff', tarifa?.id ?? 0,
    (tarifa
      ? '<p class="small text-secondary">' + escapeHtml(cancha.nombre + ' · ' + nombreModalidadTarifa(tarifa.modalidad)) + '</p>'
      : selectCancha + editSelect('modalidad', 'Modalidad', cancha.modalidades.map(mode => [String(mode.id), mode.nombre]))) +
    editSelect('dia', 'Día', opcionesDiaTarifa(), String(dia)) +
    '<div class="row"><div class="col-6">' + clockField('inicio', 'Desde (hora)', tarifa?.inicio || horas?.[0]) +
    '</div><div class="col-6">' + clockField('fin', 'Hasta (hora)', tarifa?.fin || horas?.[1]) + '</div></div>' +
    field('desde', 'Vigente desde', tarifa?.desde || localClock()[0], 'type="date" required') +
    field('hasta', 'Vigente hasta', tarifa?.hasta, 'type="date"') +
    field('valor', 'Valor por hora (CLP)', tarifa?.valor, 'type="number" min="1" max="999999999" step="1" required'));
}

function abrirDivisionTarifa(tarifa) {
  managementForm('Dividir franja · ' + nombreDia(tarifa.dia), 'tariff-split', tarifa.id,
    '<p>' + escapeHtml(nombreCanchaTarifa(tarifa.cancha) + ' · ' + nombreModalidadTarifa(tarifa.modalidad)) + '</p>' +
    '<p class="small text-secondary">La franja ' + escapeHtml(franjaTarifa(tarifa)) +
    ' se dividirá en dos con la misma vigencia. El primer tramo conserva su precio de ' +
    money.format(tarifa.valor) + ' por hora.</p>' +
    clockField('hora', 'Hora de corte') +
    field('valor', 'Valor por hora del segundo tramo (CLP)', tarifa.valor, 'type="number" min="1" max="999999999" step="1" required'));
}

async function mutarTarifa(accion, datos, mensaje) {
  const r = await apiPost(tarifasRuta, { accion }, datos);
  tarifasAdministracion = undefined;
  await cargarTarifas();
  if (r.id) managementState.tarifas.selected = r.id;
  dialog.hide();
  await render();
  feedback(mensaje);
}

function guardarTarifa(id, datos, dividir = false) {
  const tarifa = tarifasAdministracion?.find(entry => entry.id === id);
  if (dividir) {
    const corte = minutes(datos.hora) - minutes(tarifa.inicio);
    if (corte <= 0 || corte % 60 || datos.hora >= tarifa.fin) {
      throw new Error('Selecciona un corte entre dos bloques completos de una hora.');
    }
    return mutarTarifa('dividir', { ...datos, id }, 'Franja dividida.');
  }
  const cancha = canchaPorId(tarifa?.cancha ?? datos.cancha);
  const horas = horarioDe(cancha?.recinto, Number(datos.dia));
  if (!horas || datos.inicio < horas[0] || datos.fin > horas[1] || datos.inicio >= datos.fin ||
      (minutes(datos.inicio) - minutes(horas[0])) % 60 || (minutes(datos.fin) - minutes(datos.inicio)) % 60) {
    throw new Error('La tarifa debe cubrir bloques completos de una hora dentro del horario de la sucursal.');
  }
  return mutarTarifa(id ? 'editar' : 'crear', { ...datos, id }, 'Tarifa guardada.');
}

async function tariffAction(action) {
  if (action === 'manage-new-tariff') return editarTarifa();
  const m = /^manage-rate-(edit|split|toggle|confirm|delete)-(\d+)$/.exec(action);
  if (!m) return;
  const tarifa = tarifasAdministracion?.find(entry => entry.id === Number(m[2]));
  if (!tarifa) return;
  if (m[1] === 'edit') return editarTarifa(tarifa);
  if (m[1] === 'split') return abrirDivisionTarifa(tarifa);
  if (m[1] === 'confirm') return confirmarBorrado('la tarifa de ' + nombreCanchaTarifa(tarifa.cancha), 'manage-rate-delete-' + tarifa.id);
  if (m[1] === 'delete') return mutarTarifa('borrar', { id: tarifa.id }, 'Tarifa eliminada.');
  return mutarTarifa('estado', { id: tarifa.id, estado: tarifa.estado === 'ACTIVA' ? 'INACTIVA' : 'ACTIVA' },
    'Estado de la tarifa actualizado.');
}

document.addEventListener('change', event => {
  const form = event.target.form;
  if (form?.dataset.page !== 'tariff' || event.target.name !== 'cancha') return;
  const cancha = canchaPorId(event.target.value);
  form.elements.modalidad.innerHTML = cancha.modalidades.map(mode => selectOption(mode.id, mode.nombre)).join('');
});
