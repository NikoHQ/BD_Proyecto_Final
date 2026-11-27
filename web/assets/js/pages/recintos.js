'use strict';

const recintosRuta = '/dashboardadmin/api/recintos.php';
const courtStates = { DISPONIBLE: 'Disponible', MANTENCION: 'Mantención', INACTIVA: 'Inactiva' };
const weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const nombreDia = dia => weekdays[dia - 1];
let modalidadesAdministracion;
let deportesAdministracion = [];
let horarioRecintoActual;
let horariosRecinto = [];
let horarioBloqueActual;
let bloquesHorario = [];

async function cargarModalidadesAdministracion() {
  const datos = await apiGet(recintosRuta, { accion: 'modalidades' });
  modalidadesAdministracion = datos.modalidades;
  deportesAdministracion = datos.deportes;
}

function facilitiesDefinition(f, action) {
  if (f.kind === 'modalities') return modalidadesDefinition(f, action);
  if (f.kind === 'sports') return deportesDefinition(f, action);
  const sites = f.kind !== 'courts';
  const items = sites ? panel.recintos : panel.canchas.filter(cancha => cancha.recinto === f.site);
  const sport = item => item.modalidades?.map(mode => mode.nombre).join(', ');
  const title = sites ? 'Sucursales' : 'Canchas · ' + escapeHtml(nombreRecinto(f.site));
  const estados = sites ? activeStates : courtStates;
  return {
    title, placeholder: sites ? 'Sucursal o dirección' : 'Cancha o modalidad',
    headers: sites ? ['Sucursal', 'Dirección', 'Canchas', 'Estado'] : ['Instalación', 'Sucursal', 'Modalidad', 'Estado'],
    rows: items.filter(item => managementSearch(f.query, [item.nombre, item.direccion, sport(item)]) &&
      (!f.status || item.estado === f.status) && (!f.sport || item.modalidades?.some(mode => String(mode.id) === f.sport))),
    toolbar: sites ? button('manage-sports', 'Administrar deportes') +
      button('manage-modalities', 'Administrar modalidades') +
      button('manage-new-site', 'Agregar sucursal', 'btn-accent') :
      button('manage-sites', '← Todas las sucursales') +
      button('manage-hours-' + f.site, 'Horario semanal') +
      button('manage-new-court', 'Agregar cancha', 'btn-accent'),
    filters: managementSelect('status', 'Todos los estados', Object.entries(estados), f.status) +
      (sites ? '' : managementSelect('sport', 'Todas las modalidades',
        panel.modalidades.map(mode => [String(mode.id), mode.nombre]), f.sport)),
    name: item => item.nombre,
    cells: item => sites
      ? [item.direccion, String(panel.canchas.filter(cancha => cancha.recinto === item.id).length), estados[item.estado]]
      : [nombreRecinto(item.recinto), sport(item) || 'Sin modalidad activa', estados[item.estado]],
    actions: item => [
      action(sites ? 'courts' : 'rates', item.id, sites ? 'Administrar canchas' : 'Ver tarifas'),
      ...(sites ? [action('hours', item.id, 'Horario semanal')] : []),
      action('edit', item.id, 'Editar'), action('history', item.id, 'Ver agenda'),
      action('toggle', item.id, ['ACTIVO', 'DISPONIBLE'].includes(item.estado) ? 'Desactivar' : 'Activar'),
      action('ask-delete', item.id, 'Eliminar', true)
    ],
    details: item => {
      const fields = sites ? [['Dirección', item.direccion], ['Estado', estados[item.estado]],
        ...weekdays.map((day, i) => [day, item.horarios?.[i + 1]?.join('–') || 'Cerrado'])]
        : [['Sucursal', nombreRecinto(item.recinto)], ['Modalidad', sport(item)], ['Tipo', item.tipo],
          ['Estado', estados[item.estado]]];
      const proximas = reservasPanel().filter(row => row.fecha >= localClock()[0] &&
        ['pending', 'confirmed'].includes(row.estado) &&
        (sites ? canchaPorId(row.canchaId)?.recinto === item.id : row.canchaId === item.id))
        .sort((a, b) => a.fecha.localeCompare(b.fecha) || a.start.localeCompare(b.start));
      return managementDetails('Detalle · ' + escapeHtml(item.nombre), [...fields,
        ['Próximo bloque', proximas[0] ? proximas[0].fecha + ' · ' + proximas[0].start : '']],
      button('manage-' + (sites ? 'courts-' : 'rates-') + item.id, sites ? 'Administrar canchas' : 'Ver tarifas', 'btn-accent') +
      (sites ? button('manage-hours-' + item.id, 'Horario semanal') : '') +
      button('manage-edit-' + item.id, 'Editar ficha') + button('manage-history-' + item.id, 'Ver agenda'));
    }
  };
}

function modalidadesDefinition(f, action) {
  const deporte = item => deportesAdministracion.find(entry => entry.id === item.deporte)?.nombre || '';
  return {
    title: 'Modalidades', placeholder: 'Modalidad o deporte',
    headers: ['Modalidad', 'Deporte', 'Máximo por equipo', 'Estado'],
    toolbar: button('manage-sites', '← Todas las sucursales') +
      button('manage-new-modality', 'Agregar modalidad', 'btn-accent'),
    filters: managementSelect('status', 'Todos los estados', Object.entries(activeStates), f.status),
    rows: (modalidadesAdministracion || []).filter(item => managementSearch(f.query, [item.nombre, deporte(item)]) &&
      (!f.status || item.estado === f.status)),
    name: item => item.nombre,
    cells: item => [deporte(item), `${item.minimo}–${item.maximo}`, activeStates[item.estado]],
    actions: item => [action('edit', item.id, 'Editar'), action('toggle', item.id,
      item.estado === 'ACTIVO' ? 'Desactivar' : 'Activar'), action('ask-delete', item.id, 'Eliminar', true)],
    details: item => managementDetails('Detalle · ' + escapeHtml(item.nombre), [
      ['Deporte', deporte(item)], ['Jugadores por equipo', `${item.minimo}–${item.maximo}`], ['Estado', activeStates[item.estado]]
    ], button('manage-edit-' + item.id, 'Editar modalidad'))
  };
}

function deportesDefinition(f, action) {
  return {
    title: 'Deportes', placeholder: 'Nombre del deporte',
    headers: ['Deporte', 'Estado'],
    toolbar: button('manage-sites', '← Todas las sucursales') +
      button('manage-new-sport', 'Agregar deporte', 'btn-accent'),
    filters: managementSelect('status', 'Todos los estados', Object.entries(activeStates), f.status),
    rows: (deportesAdministracion || []).filter(item =>
      managementSearch(f.query, [item.nombre]) && (!f.status || item.estado === f.status)),
    name: item => item.nombre,
    cells: item => [activeStates[item.estado]],
    actions: item => [action('edit', item.id, 'Editar'), action('toggle', item.id,
      item.estado === 'ACTIVO' ? 'Desactivar' : 'Activar'), action('ask-delete', item.id, 'Eliminar', true)],
    details: item => managementDetails('Detalle · ' + escapeHtml(item.nombre), [
      ['Estado', activeStates[item.estado]]
    ], button('manage-edit-' + item.id, 'Editar deporte'))
  };
}

function abrirDeporte(item = null) {
  managementForm(item ? 'Editar deporte' : 'Agregar deporte', 'deporte', item?.id ?? 0,
    field('nombre', 'Nombre', item?.nombre, 'required maxlength="50"') +
    (item ? editSelect('estado', 'Estado', Object.entries(activeStates), item.estado) : ''));
}

function abrirModalidad(item = null) {
  const deportes = deportesAdministracion.filter(entry => entry.estado === 'ACTIVO' || entry.id === item?.deporte);
  if (!deportes.length) return showDialog('Sin deportes disponibles', '<p>El catálogo necesita un deporte activo.</p>');
  managementForm(item ? 'Editar modalidad' : 'Agregar modalidad', 'modalidad', item?.id ?? 0,
    field('nombre', 'Nombre', item?.nombre, 'required maxlength="80"') +
    editSelect('deporte', 'Deporte', deportes.map(entry => [entry.id, entry.nombre]), item?.deporte) +
    field('minimo', 'Mínimo por equipo', item?.minimo ?? 1, 'type="number" required min="1" max="50" step="1"') +
    field('maximo', 'Máximo por equipo', item?.maximo, 'type="number" required min="1" max="50" step="1"') +
    (item ? editSelect('estado', 'Estado', Object.entries(activeStates), item.estado) : ''));
}

async function abrirCancha(item = null) {
  const asignadas = item ? await apiGet(recintosRuta, { accion: 'cancha-modalidades', id: item.id }) : [];
  if (!modalidadesAdministracion) await cargarModalidadesAdministracion();
  const opciones = modalidadesAdministracion.filter(mode => mode.estado === 'ACTIVO' || asignadas.includes(mode.id));
  if (!opciones.length) return showDialog('Sin modalidades', '<p>Agrega una modalidad activa antes de configurar la cancha.</p>');
  const choices = opciones.map(mode => '<label class="form-check mb-1">' +
    '<input class="form-check-input" type="checkbox" name="modalidades" value="' + mode.id + '"' +
    (asignadas.includes(mode.id) ? ' checked' : '') + '> ' + escapeHtml(mode.nombre) +
    (mode.estado === 'INACTIVO' ? ' (inactiva)' : '') + '</label>').join('');
  const tipos = [
    ['FUTBOL_6', 'Fútbol 6'], ['PADEL', 'Pádel'], ['TENIS', 'Tenis'], ['CANCHA', 'Cancha']
  ];
  if (item?.tipo && !tipos.some(([tipo]) => tipo === item.tipo)) tipos.unshift([item.tipo, item.tipo]);
  const componentes = panel.componentes.filter(par => par.grande === item?.id)
    .map(par => canchaPorId(par.pequena)?.nombre).filter(Boolean);
  managementForm(item ? 'Editar instalación' : 'Agregar cancha', 'cancha', item?.id ?? 0,
    field('nombre', 'Nombre', item?.nombre, 'required maxlength="100"') +
    editSelect('tipo', 'Tipo de cancha', tipos, item?.tipo) +
    (componentes.length ? '<p class="small text-secondary">Componentes: ' + escapeHtml(componentes.join(', ')) + '</p>' : '') +
    '<fieldset class="border rounded p-3 mb-3"><legend class="fs-6 float-none w-auto mb-1">Modalidades admitidas</legend>' +
    choices + '</fieldset>' + editSelect('estado', 'Estado', Object.entries(courtStates), item?.estado || 'DISPONIBLE'));
}

function abrirRecinto(item = null) {
  managementForm(item ? 'Editar sucursal' : 'Agregar sucursal', 'recinto', item?.id ?? 0,
    field('nombre', 'Nombre', item?.nombre, 'required maxlength="100"') +
    field('direccion', 'Dirección', item?.direccion, 'required maxlength="150"') +
    editSelect('estado', 'Estado', Object.entries(activeStates), item?.estado || 'ACTIVO'));
}

async function abrirHorarios(sitio) {
  const horarios = await apiGet(recintosRuta, { accion: 'horarios', id: sitio.id });
  horarioRecintoActual = sitio;
  horariosRecinto = horarios;
  const filas = weekdays.map((dia, i) => {
    const horario = horarios.find(h => h.dia === i + 1);
    const acciones = horario
      ? button('manage-hours-edit-' + horario.id, 'Editar') + button('manage-blocks-' + horario.id, 'Ver bloques') +
        button('manage-hours-confirm-' + horario.id, 'Eliminar', 'btn-outline-danger btn-sm')
      : button('manage-hours-new-' + (i + 1), 'Agregar horario');
    return [dia, horario ? escapeHtml(horario.apertura + '–' + horario.cierre) : 'Cerrado',
      '<div class="d-flex gap-1 flex-wrap">' + acciones + '</div>'];
  });
  showDialog('Horario semanal · ' + sitio.nombre, table(['Día', 'Horario', 'Acciones'], filas));
}

function editarHorario(horario, dia = horario?.dia) {
  managementForm('Horario · ' + nombreDia(dia), 'horario', horario?.id ?? 0,
    '<input type="hidden" name="dia" value="' + dia + '">' +
    clockField('apertura', 'Apertura', horario?.apertura) +
    clockField('cierre', 'Cierre', horario?.cierre) +
    button('manage-hours-back', 'Volver al horario semanal'));
}

async function abrirBloques(horario) {
  const bloques = await apiGet(recintosRuta, { accion: 'bloques', id: horario.id });
  horarioBloqueActual = horario;
  bloquesHorario = bloques;
  const filas = bloques.map(bloque => [escapeHtml(bloque.inicio), escapeHtml(bloque.fin),
    button('manage-block-edit-' + bloque.id, 'Editar') +
    button('manage-block-confirm-' + bloque.id, 'Eliminar', 'btn-outline-danger btn-sm')]);
  showDialog('Bloques del ' + nombreDia(horario.dia).toLowerCase(),
    '<div class="d-flex gap-2 flex-wrap mb-3">' +
    button('manage-hours-back', '← Horario semanal') +
    button('manage-block-new', 'Agregar bloque', 'btn-accent') + '</div>' +
    table(['Inicio', 'Término', 'Acciones'], filas, 'Sin bloques horarios.'));
}

function editarBloque(bloque = null) {
  managementForm(bloque ? 'Editar bloque' : 'Agregar bloque', 'bloque', bloque?.id ?? 0,
    '<p class="small text-secondary">Cada bloque dura una hora.</p>' +
    clockField('inicio', 'Inicio', bloque?.inicio) + clockField('fin', 'Término', bloque?.fin) +
    button('manage-blocks-' + horarioBloqueActual.id, 'Volver a bloques'));
}

async function refrescarCatalogoAdministracion() {
  panel.catalogoCargado = false;
  await cargarCatalogo();
}

async function guardarInstalacion(entidad, id, datos, formData) {
  if (entidad === 'cancha') {
    datos.modalidades = formData.getAll('modalidades');
    datos.recinto = managementState.instalaciones.filters.site;
  } else if (entidad === 'horario') {
    datos.recinto = horarioRecintoActual.id;
  } else if (entidad === 'bloque') {
    datos.horario = horarioBloqueActual.id;
  }
  const actualizado = await apiPost(recintosRuta, { accion: entidad + '-guardar' }, { ...datos, id });
  if (entidad === 'modalidad' || entidad === 'deporte') await cargarModalidadesAdministracion();
  await refrescarCatalogoAdministracion();
  if (entidad === 'horario') await abrirHorarios(horarioRecintoActual);
  else if (entidad === 'bloque') await abrirBloques(horarioBloqueActual);
  else {
    managementState.instalaciones.selected = actualizado.id;
    dialog.hide();
  }
  await render();
  feedback('Cambios guardados.');
}

function confirmarBorrado(label, action, back = '') {
  showDialog('Eliminar registro', '<p>¿Eliminar <strong>' + escapeHtml(label) + '</strong>?</p>' +
    '<p class="text-danger small" role="alert" id="management-error"></p>' +
    '<div class="d-flex gap-2 flex-wrap">' + back + button(action, 'Confirmar eliminación', 'btn-danger') + '</div>');
}

async function borrarInstalacion(entidad, id) {
  await apiPost(recintosRuta, { accion: entidad + '-borrar' }, { id });
  if (entidad === 'modalidad' || entidad === 'deporte') await cargarModalidadesAdministracion();
  await refrescarCatalogoAdministracion();
  if (entidad === 'horario') await abrirHorarios(horarioRecintoActual);
  else if (entidad === 'bloque') await abrirBloques(horarioBloqueActual);
  else dialog.hide();
  await render();
  feedback('Registro eliminado.');
}

async function accionInstalacionEspecial(action) {
  if (action === 'manage-sites') {
    if (panelRoute().site) location.hash = 'instalaciones';
    else {
      Object.assign(managementState.instalaciones, { filters: {}, page: 1, selected: null });
      await render();
    }
  } else if (action === 'manage-modalities') {
    await cargarModalidadesAdministracion();
    Object.assign(managementState.instalaciones, { filters: { kind: 'modalities' }, page: 1, selected: null });
    await render();
  } else if (action === 'manage-sports') {
    await cargarModalidadesAdministracion();
    Object.assign(managementState.instalaciones, { filters: { kind: 'sports' }, page: 1, selected: null });
    await render();
  } else if (action === 'manage-new-site') abrirRecinto();
  else if (action === 'manage-new-sport') abrirDeporte();
  else if (action === 'manage-new-court') await abrirCancha();
  else if (action === 'manage-new-modality') abrirModalidad();
  else if (action === 'manage-hours-back') await abrirHorarios(horarioRecintoActual);
  else if (action === 'manage-block-new') editarBloque();
  else {
    const match = /^manage-(hours-(?:edit|new|confirm|delete)|blocks|block-(?:edit|confirm|delete))-(\d+)$/.exec(action);
    if (!match) return false;
    const [, kind, raw] = match;
    const id = Number(raw);
    const horario = horariosRecinto.find(entry => entry.id === id);
    const bloque = bloquesHorario.find(entry => entry.id === id);
    if (kind === 'hours-new') editarHorario(null, id);
    if (kind === 'hours-edit' && horario) editarHorario(horario);
    if (kind === 'hours-confirm' && horario) confirmarBorrado('el horario del ' + nombreDia(horario.dia).toLowerCase(),
      'manage-hours-delete-' + id, button('manage-hours-back', 'Volver'));
    if (kind === 'hours-delete' && horario) await borrarInstalacion('horario', id);
    if (kind === 'blocks' && horario) await abrirBloques(horario);
    if (kind === 'block-edit' && bloque) editarBloque(bloque);
    if (kind === 'block-confirm' && bloque) confirmarBorrado('el bloque ' + bloque.inicio + '–' + bloque.fin,
      'manage-block-delete-' + id, button('manage-blocks-' + horarioBloqueActual.id, 'Volver'));
    if (kind === 'block-delete' && bloque) await borrarInstalacion('bloque', id);
  }
  return true;
}

async function accionInstalacion(kind, item) {
  const { kind: vista } = managementState.instalaciones.filters;
  const entidad = vista === 'courts' ? 'cancha' : vista === 'modalities' ? 'modalidad'
    : vista === 'sports' ? 'deporte' : 'recinto';
  if (kind === 'courts') location.hash = courtRoute(item);
  if (kind === 'rates') location.hash = courtRoute(recintoPorId(item.recinto)) + '/tarifas/' + item.id;
  if (kind === 'history') {
    venue = String(item.recinto || item.id);
    courtQuery = entidad === 'cancha' ? item.nombre : '';
    location.hash = 'agenda';
  }
  if (kind === 'edit') {
    if (entidad === 'cancha') return abrirCancha(item);
    if (entidad === 'modalidad') return abrirModalidad(item);
    if (entidad === 'deporte') return abrirDeporte(item);
    return abrirRecinto(item);
  }
  if (kind === 'toggle') {
    const estado = entidad === 'cancha'
      ? (item.estado === 'DISPONIBLE' ? 'INACTIVA' : 'DISPONIBLE')
      : (item.estado === 'ACTIVO' ? 'INACTIVO' : 'ACTIVO');
    await apiPost(recintosRuta, { accion: entidad + '-estado' }, { id: item.id, estado });
    if (entidad === 'modalidad' || entidad === 'deporte') await cargarModalidadesAdministracion();
    await refrescarCatalogoAdministracion();
    await render();
    feedback('Estado actualizado.');
  }
  if (kind === 'ask-delete') confirmarBorrado(item.nombre, 'manage-delete-' + item.id);
  if (kind === 'delete') await borrarInstalacion(entidad, item.id);
}
