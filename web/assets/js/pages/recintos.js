const siteName = key => siteRecords.find(site => site.key === key)?.name || key;
const courtEnabled = index => !courtMeta[index]?.deleted &&
  (courtMeta[index]?.status || 'DISPONIBLE') === 'DISPONIBLE' &&
  siteRecords.some(site => site.key === courts[index]?.[1] && site.status === 'ACTIVO');
const courtAvailable = index => courtEnabled(index) &&
  (index !== largeCourt || largeCourtComponents.every(courtEnabled));
const courtStates = { DISPONIBLE: 'Disponible', MANTENCION: 'Mantención', INACTIVA: 'Inactiva' };
const courtType = index => index === largeCourt ? 'COMPUESTA' : 'CANCHA';
const courtStatus = index => courtMeta[index]?.status || 'DISPONIBLE';

function facilitiesDefinition(f, action) {
  const sites = f.kind !== 'courts';
  const items = sites ? siteRecords : courts.flatMap(([name, key, sport], index) => {
    if (courtMeta[index]?.deleted) return [];
    return [{ id: index, name, key, sport: courtModes(index).join(', '), district: siteName(key), status: courtStatus(index) }];
  });
  return {
    title: sites ? 'Recintos' : 'Canchas · ' + escapeHtml(siteName(f.site)), placeholder: sites ? 'Recinto o dirección' : 'Cancha o modalidad',
    headers: sites ? ['Recinto', 'Dirección', 'Canchas', 'Estado'] : ['Instalación', 'Recinto', 'Modalidad', 'Estado'],
    rows: items.filter(item => managementSearch(f.query, [item.name, item.address, item.sport]) &&
      (!f.status || item.status === f.status) && (!f.site || item.key === f.site) && (!f.sport || courtModes(item.id).includes(f.sport))),
    toolbar: sites ? button('manage-oracle', 'Consultar catálogo Oracle', 'btn-outline-secondary btn-sm') +
      (siteRecords.length === 0 ? button('manage-new-site', 'Agregar recinto', 'btn-accent') : '') :
      button('manage-sites', '← Todos los recintos') + button('manage-new-court', 'Agregar cancha', 'btn-accent'),
    filters: managementSelect('status', 'Todos los estados', Object.entries(sites ? activeStates : courtStates), f.status) +
      (sites ? '' : managementSelect('sport', 'Todas las modalidades', [...new Set(courts.flatMap((_, i) => courtModes(i)))].map(sport => [sport, sport]), f.sport)),
    name: item => item.name,
    cells: item => sites ? [item.address, courts.filter((court, i) => court[1] === item.key && !courtMeta[i]?.deleted).length, activeStates[item.status]] :
      [siteName(item.key), item.sport, courtStates[item.status]],
    actions: item => [action(sites ? 'courts' : 'rates', item.id, sites ? 'Administrar canchas' : 'Ver tarifas'), action('edit', item.id, 'Editar'),
      action('history', item.id, 'Ver agenda'), action('toggle', item.id,
        ['ACTIVO', 'DISPONIBLE'].includes(item.status) ? 'Desactivar' : 'Activar'),
      action('ask-delete', item.id, 'Eliminar de la maqueta', true)],
    details: item => {
      const upcoming = allBookings().filter(row => row.date >= localClock()[0] && !['cancelled', 'completed', 'maintenance'].includes(row.status) &&
        (sites ? courts[row.court][1] === item.key : row.court === item.id)).sort(byTime);
      const fields = sites ? [
        ['Dirección', item.address],
        ['Estado', activeStates[item.status]], ...weekdays.map((day, i) => [day,
          siteHours(item, i)?.join('–') || 'Cerrado'])
      ] : [['Recinto', siteName(item.key)], ['Modalidad', item.sport], ['Tipo', courtType(item.id)],
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
  const catalog = ['Fútbol 6', 'Pádel dobles', 'Tenis'];
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
    (item?.id === largeCourt ? '<p class="small text-secondary">La cancha grande ocupa las canchas 1, 2 y 3.</p>' : '') +
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
    const { recintos, canchas } = await apiGet('/dashboardadmin/api/catalogo.php');
    const container = $('oracle-catalog');
    if (!container) return;
    const dias = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];
    const catalog = recintos.map(recinto => {
      const apertura = Object.entries(recinto.horarios || {}).map(([dia, horas]) =>
        [dias[Number(dia) - 1], horas[0], horas[1]].map(escapeHtml));
      const instalaciones = canchas.filter(cancha => cancha.recinto === recinto.id).map(cancha => [
        cancha.nombre, cancha.estado, cancha.modalidades.map(modalidad => modalidad.nombre).join(', ') || 'Sin modalidad',
        String(cancha.modalidades.length)
      ].map(escapeHtml));
      return '<details class="border rounded p-2 mb-2"><summary>' + escapeHtml(recinto.nombre) +
        '</summary><p class="mt-2">' + escapeHtml(recinto.direccion + ' · ' + recinto.estado) +
        '</p>' + table(['Día', 'Abre', 'Cierra'], apertura) +
        table(['Cancha', 'Estado', 'Modalidad', 'Modalidades'], instalaciones) + '</details>';
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

function bookingUsesHourlyBlocks(court, date, start, end) {
  if (!bookingWithinHours(court, date, start, end) || start >= end) return false;
  const opening = siteHours(siteRecords.find(site => site.key === courts[court][1]), weekdayIndex(date))[0];
  return (minutes(start) - minutes(opening)) % 60 === 0 && (minutes(end) - minutes(start)) % 60 === 0;
}

function editSite(item) {
    if (managementState.instalaciones.filters.kind === 'courts') {
    return editCourt(item);
  }
  managementForm(item ? 'Editar recinto' : 'Agregar recinto', 'instalaciones', item?.id ?? 0,
    field('name', 'Nombre', item?.name, 'required maxlength="100"') +
    field('address', 'Dirección', item?.address, 'required maxlength="150"') +
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
  courts[index] = [data.name, siteKey, primary, court?.[3] || 0, court?.[4] || 0];
  courtMeta[index] = { status: data.status, modalities };
  managementState.instalaciones.selected = index;
}

function saveSiteHours(id, data, error) {
  const site = siteRecords.find(entry => entry.id === id);
  const hours = weekdays.map((_, index) => {
    const opening = data['open' + index];
    const closing = data['close' + index];
    return opening || closing ? [opening, closing] : null;
  });
  const invalid = hours.findIndex(pair => pair && (!validClock(pair[0]) || !validClock(pair[1], true) || pair[0] >= pair[1] || (minutes(pair[1]) - minutes(pair[0])) % 60 !== 0));
  if (invalid !== -1) return error(weekdays[invalid] + ' debe tener un horario divisible en bloques completos de una hora.');
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
  if (!data.name || !data.address) return error('Completa nombre y dirección.');
  if (siteRecords.some(entry => entry.id !== id && normalizeName(entry.name) === normalizeName(data.name))) return error('Ya existe un recinto con ese nombre.');
  if (site) Object.assign(site, data);
  else {
    if (siteRecords.length) return error('La entrega trabaja con un solo recinto.');
    const id = Math.max(0, ...siteRecords.map(entry => entry.id)) + 1;
    siteRecords.push({ ...data, id, key: 'site-' + id, hours: weekdays.map(() => null) });
    managementState.instalaciones.selected = id;
  }
}
