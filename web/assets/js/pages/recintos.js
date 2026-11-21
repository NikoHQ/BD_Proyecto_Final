const siteName = key => siteRecords.find(site => site.key === key)?.name || key;
const courtAvailable = index => !courtMeta[index]?.deleted &&
  (courtMeta[index]?.status || 'DISPONIBLE') === 'DISPONIBLE' &&
  siteRecords.some(site => site.key === courts[index]?.[1] && site.status === 'ACTIVO');
const courtStates = { DISPONIBLE: 'Disponible', MANTENCION: 'Mantención', INACTIVA: 'Inactiva' };
const courtTypes = ['CANCHA', 'GIMNASIO', 'SALA', 'PISCINA'];
const courtType = index => courtMeta[index]?.type || ({ 3: 'GIMNASIO', 5: 'SALA' }[index] || 'CANCHA');
const courtStatus = index => courtMeta[index]?.status || 'DISPONIBLE';

function facilitiesDefinition(f, action) {
  const sites = f.kind !== 'courts';
  const items = sites ? siteRecords : courts.flatMap(([name, key, sport], index) => {
    if (courtMeta[index]?.deleted) return [];
    return [{ id: index, name, key, sport: courtModes(index).join(', '), district: siteName(key), status: courtStatus(index) }];
  });
  return {
    title: sites ? 'Recintos' : 'Canchas · ' + escapeHtml(siteName(f.site)), placeholder: sites ? 'Recinto, dirección o comuna' : 'Cancha o modalidad',
    headers: sites ? ['Recinto', 'Comuna', 'Canchas', 'Estado'] : ['Instalación', 'Recinto', 'Modalidad', 'Estado'],
    rows: items.filter(item => managementSearch(f.query, [item.name, item.district, item.address, item.sport, item.phone]) &&
      (!f.status || item.status === f.status) && (!f.site || item.key === f.site) && (!f.sport || courtModes(item.id).includes(f.sport))),
    toolbar: sites ? button('manage-oracle', 'Consultar catálogo Oracle', 'btn-outline-secondary btn-sm') +
      button('manage-new-site', 'Agregar recinto', 'btn-accent') :
      button('manage-sites', '← Todos los recintos') + button('manage-new-court', 'Agregar cancha', 'btn-accent'),
    filters: managementSelect('status', 'Todos los estados', Object.entries(sites ? activeStates : courtStates), f.status) +
      (sites ? '' : managementSelect('sport', 'Todas las modalidades', [...new Set(courts.flatMap((_, i) => courtModes(i)))].map(sport => [sport, sport]), f.sport)),
    name: item => item.name,
    cells: item => sites ? [item.district, courts.filter((court, i) => court[1] === item.key && !courtMeta[i]?.deleted).length, activeStates[item.status]] :
      [siteName(item.key), item.sport, courtStates[item.status]],
    actions: item => [action(sites ? 'courts' : 'rates', item.id, sites ? 'Administrar canchas' : 'Ver tarifas'), action('edit', item.id, 'Editar'),
      action('history', item.id, 'Ver agenda'), action('toggle', item.id,
        ['ACTIVO', 'DISPONIBLE'].includes(item.status) ? 'Desactivar' : 'Activar'),
      action('ask-delete', item.id, 'Eliminar de la maqueta', true)],
    details: item => {
      const upcoming = allBookings().filter(row => row.date >= localClock()[0] && !['cancelled', 'completed', 'maintenance'].includes(row.status) &&
        (sites ? courts[row.court][1] === item.key : row.court === item.id)).sort(byTime);
      const fields = sites ? [
        ['Comuna', item.district], ['Dirección', item.address], ['Teléfono', item.phone],
        ['Estado', activeStates[item.status]], ...weekdays.map((day, i) => [day,
          siteHours(item, i)?.join('–') || 'Cerrado'])
      ] : [['Recinto', siteName(item.key)], ['Modalidad', item.sport], ['Tipo', courtType(item.id)],
        ['Superficie', courtMeta[item.id]?.surface ? courtMeta[item.id].surface + ' m²' : ''],
        ['Estado', courtStates[item.status]]];
      return managementDetails('Detalle · ' + escapeHtml(item.name), [...fields, ['Próximas reservas', String(upcoming.length)],
        ['Próximo bloque', upcoming[0] ? upcoming[0].date + ' · ' + upcoming[0].start : '']],
      button('manage-' + (sites ? 'courts-' : 'rates-') + item.id, sites ? 'Administrar canchas' : 'Ver tarifas', 'btn-accent') +
      (sites ? button('manage-hours-' + item.id, 'Editar horario semanal') : '') +
      button('manage-edit-' + item.id, 'Editar ficha') + button('manage-history-' + item.id, 'Ver agenda'));
    }
  };
}
function modalityChoices() {
  const catalog = ['Fútbol 5', 'Fútbol 7', 'Pádel dobles', 'Básquetbol 5x5', 'Vóleibol 6x6', 'Entrenamiento funcional'];
  return [...new Set([...catalog, ...courts.flatMap((_, index) => courtModes(index))])]
    .sort((a, b) => a.localeCompare(b, 'es'));
}

function editCourt(item = null) {
  const assigned = item ? courtModes(item.id) : [];
  const choices = modalityChoices().map(mode =>
    '<label class="form-check mb-1"><input class="form-check-input" type="checkbox" name="modalities" value="' +
    escapeHtml(mode) + '"' + (assigned.includes(mode) ? ' checked' : '') + '> <span class="form-check-label">' +
    escapeHtml(mode) + '</span></label>').join('');
  managementForm(item ? 'Editar instalación' : 'Agregar cancha', 'court', item?.id ?? -1,
    field('name', 'Nombre', item?.name, 'required maxlength="100"') +
    editSelect('type', 'Tipo', courtTypes.map(type => [type, type]), courtType(item?.id)) +
    field('surface', 'Superficie (m²)', courtMeta[item?.id]?.surface, 'type="number" min=".01" max="999999.99" step=".01"') +
    '<fieldset class="border rounded p-3 mb-3"><legend class="fs-6 float-none w-auto mb-1">Modalidades admitidas</legend>' +
    '<p class="small text-secondary mb-2">Marca una o más modalidades del catálogo.</p>' + choices + '</fieldset>' +
    editSelect('status', 'Estado', Object.entries(courtStates), item?.status || 'DISPONIBLE'));
}

function editSiteHours(site) {
  const days = weekdays.map((day, index) => {
    const hours = siteHours(site, index);
    return '<fieldset class="row align-items-end g-2 mb-3"><legend class="h6 mb-0">' + day + '</legend>' +
      '<div class="col-6">' + clockField('open' + index, 'Apertura', hours?.[0], { required: false }) + '</div>' +
      '<div class="col-6">' + clockField('close' + index, 'Cierre', hours?.[1], { required: false, end: true }) + '</div></fieldset>';
  });
  managementForm('Horario semanal · ' + site.name, 'hours', site.id,
    '<p class="small text-secondary">Usa HH:MM en formato de 24 horas. Para cerrar a medianoche escribe 24:00. Deja ambos campos vacíos si el recinto no abre ese día.</p>' + days.join(''));
}
async function showOracleCatalog() {
  showDialog('Catálogo Oracle', '<p id="oracle-catalog" role="status">Consultando recintos y canchas…</p>');
  try {
    const response = await fetch('catalogo-oracle.php');
    if (!response.ok) throw new Error('Oracle no disponible');
    const { recintos, horarios, canchas } = await response.json();
    const container = $('oracle-catalog');
    if (!container) return;
    const catalog = recintos.map(site => {
      const opening = horarios.filter(row => row.ID_RECINTO === site.ID_RECINTO).map(row => [
        ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'][Number(row.DIA_SEMANA_HORARIO) - 1],
        row.HORA_APERTURA_HORARIO, row.HORA_CIERRE_HORARIO
      ].map(escapeHtml));
      const facilities = canchas.filter(row => row.ID_RECINTO === site.ID_RECINTO).map(row => [
        row.NOMBRE_CANCHA, row.ESTADO_CANCHA, row.NOMBRE_MODALIDAD || 'Sin modalidad', row.TARIFAS_ACTIVAS
      ].map(escapeHtml));
      return '<details class="border rounded p-2 mb-2"><summary>' + escapeHtml(site.NOMBRE_RECINTO) +
        '</summary><p class="mt-2">' + escapeHtml(site.DIRECCION_RECINTO + ' · ' + site.COMUNA_RECINTO + ' · ' + site.ESTADO_RECINTO) +
        '</p>' + table(['Día', 'Abre', 'Cierra'], opening) +
        table(['Cancha', 'Estado', 'Modalidad', 'Tarifas activas'], facilities) + '</details>';
    }).join('');
    container.outerHTML = '<div id="oracle-catalog"><p class="small text-secondary">Consulta de solo lectura.</p>' +
      (catalog || '<p>Oracle todavía no tiene recintos.</p>') + '</div>';
  } catch {
    const container = $('oracle-catalog');
    if (container) container.textContent = 'No se pudo consultar el catálogo de Oracle.';
  }
}
const weekdays = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
const weekdayIndex = date => (new Date(date + 'T12:00:00Z').getUTCDay() + 6) % 7;
const courtModes = index => courtMeta[index]?.modalities || (courts[index] ? [courts[index][2]] : []);
const siteHours = (site, day) => site?.hours ? site.hours[day] : ['08:00', '22:00'];
function bookingWithinHours(court, date, start, end) {
  const site = siteRecords.find(site => site.key === courts[court]?.[1]);
  const hours = site && siteHours(site, weekdayIndex(date));
  return Boolean(hours && start >= hours[0] && end <= hours[1]);
}

function editSite(item) {
    if (managementState.instalaciones.filters.kind === 'courts') {
    return editCourt(item);
  }
  managementForm(item ? 'Editar recinto' : 'Agregar recinto', 'instalaciones', item?.id ?? 0,
    field('name', 'Nombre', item?.name, 'required maxlength="100"') +
    field('district', 'Comuna', item?.district, 'required maxlength="80"') +
    field('address', 'Dirección', item?.address, 'required maxlength="200"') +
    field('phone', 'Teléfono', item?.phone, 'type="tel" maxlength="20"') +
    editSelect('status', 'Estado', Object.entries(activeStates), item?.status || 'ACTIVO'));
}

function saveCourt(id, data, formData, error) {
  const court = courts[id];
  const siteKey = court?.[1] || managementState.instalaciones.filters.site;
  const choices = modalityChoices();
  const modalities = [...new Set(formData.getAll('modalities'))];
  if (!modalities.length || modalities.some(mode => !choices.includes(mode))) {
    return error('Selecciona al menos una modalidad del catálogo.');
  }
  if (!siteRecords.some(site => site.key === siteKey)) return error('Selecciona un recinto válido.');
  if (!data.name || courts.some((entry, index) => index !== id && !courtMeta[index]?.deleted &&
    entry[1] === siteKey && normalizeName(entry[0]) === normalizeName(data.name))) return error('Usa un nombre único en el recinto.');
  if (court && (demoTariffs.some(rate => rate.court === id && !modalities.includes(rate.mode)) ||
    allBookings().some(row => row.court === id && !modalities.includes(row.modality ||
      (isTournament(row) ? tournaments[row.tournamentId].sport : court[2]))))) {
    return error('Conserva las modalidades que tienen tarifas o reservas vinculadas.');
  }
  const index = court ? id : courts.length;
  const primary = court && modalities.includes(court[2]) ? court[2] : modalities[0];
  modalities.sort((left, right) => (left === primary ? -1 : right === primary ? 1 : 0));
  courts[index] = [data.name, siteKey, primary, court?.[3] || 0];
  courtMeta[index] = { type: data.type, status: data.status, surface: data.surface, modalities };
  managementState.instalaciones.selected = index;
}

function saveSiteHours(id, data, error) {
  const site = siteRecords.find(entry => entry.id === id);
  const hours = weekdays.map((_, index) => {
    const opening = data['open' + index];
    const closing = data['close' + index];
    return opening || closing ? [opening, closing] : null;
  });
  const invalid = hours.findIndex(pair => pair && (!validClock(pair[0]) || !validClock(pair[1], true) || pair[0] >= pair[1]));
  if (invalid !== -1) return error(weekdays[invalid] + ' debe tener una apertura anterior al cierre.');
  const conflict = allBookings().find(row => {
    if (courts[row.court][1] !== site.key || row.date < localClock()[0] ||
        !['pending', 'confirmed'].includes(row.status)) return false;
    const pair = hours[weekdayIndex(row.date)];
    return !pair || row.start < pair[0] || row.end > pair[1];
  });
  if (conflict) return error('El cambio deja fuera del horario la reserva ' + label(conflict) + '. Reprograma ese bloque primero.');
  site.hours = hours;
}

function saveSite(id, data, error) {
  const site = siteRecords.find(entry => entry.id === id);
  if (!data.name || !data.district || !data.address) return error('Completa nombre, dirección y comuna.');
  if (siteRecords.some(entry => entry.id !== id && normalizeName(entry.name) === normalizeName(data.name) &&
    normalizeName(entry.district) === normalizeName(data.district))) return error('Ya existe un recinto con ese nombre y comuna.');
  if (site) Object.assign(site, data);
  else {
    const id = Math.max(0, ...siteRecords.map(entry => entry.id)) + 1;
    siteRecords.push({ ...data, id, key: 'site-' + id, hours: weekdays.map(() => null) });
    managementState.instalaciones.selected = id;
  }
}
