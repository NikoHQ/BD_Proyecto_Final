function automaticQuote(court, mode, date, start, end) {
  const bands = demoTariffs.filter(rate => rate.court === court && rate.mode === mode &&
    rate.day === weekdayIndex(date) && rate.status === 'ACTIVA' &&
    rate.from <= date && (!rate.until || date <= rate.until));
  const startMinute = minutes(start);
  const endMinute = minutes(end);
  const cuts = [...new Set([startMinute, endMinute, ...bands.flatMap(rate =>
    [minutes(rate.start), minutes(rate.end)].filter(cut => cut > startMinute && cut < endMinute))])].sort((a, b) => a - b);
  let total = 0;
  const ids = new Set();
  for (let i = 0; i < cuts.length - 1; i++) {
    const band = bands.find(rate => minutes(rate.start) <= cuts[i] && minutes(rate.end) >= cuts[i + 1]);
    if (!band) return null;
    ids.add(band.id);
    total += band.rate * (cuts[i + 1] - cuts[i]) / 60;
  }
  return { amount: Math.round(total), tariffIds: [...ids], priceMode: 'automatic' };
}

function tariffsDefinition(f) {
  const options = String(f.court ?? '');
  return {
    title: 'Tarifas', placeholder: 'Cancha, recinto, modalidad o día',
    description: 'Configura el valor por hora de cada franja. Puedes dividir una franja para cobrar un precio distinto el mismo día.',
    headers: ['Tarifa', 'Modalidad', 'Día', 'Franja', 'Valor por hora', 'Estado'],
    toolbar: button('manage-new-tariff', 'Nueva tarifa', 'btn-accent'),
    filters: (panelRoute().court === undefined ? managementSelect('court', 'Todas las canchas', courts.flatMap(([name, site], i) =>
      courtMeta[i]?.deleted ? [] : [[String(i), siteName(site) + ' · ' + name]]), options) : '') +
      managementSelect('day', 'Todos los días', weekdays.map((day, i) => [String(i), day]), f.day) +
      managementSelect('status', 'Todos los estados', [['ACTIVA', 'Activa'], ['INACTIVA', 'Inactiva']], f.status),
    rows: demoTariffs.filter(rate => courts[rate.court] && !courtMeta[rate.court]?.deleted &&
      (options === '' || Number(options) === rate.court) && (!f.day || String(rate.day) === f.day) &&
      (!f.status || f.status === rate.status) &&
      managementSearch(f.query, [courts[rate.court][0], siteName(courts[rate.court][1]), rate.mode, weekdays[rate.day]]))
      .sort((a, b) => a.court - b.court || a.day - b.day || a.start.localeCompare(b.start)),
    name: rate => courts[rate.court][0],
    cells: rate => [rate.mode, weekdays[rate.day], rate.start + '–' + rate.end, money.format(rate.rate),
      rate.status === 'ACTIVA' ? 'Activa' : 'Inactiva'],
    actions: rate => [['manage-rate-edit-' + rate.id, 'Editar tarifa'], ['manage-rate-split-' + rate.id, 'Dividir franja'], ['manage-rate-toggle-' + rate.id,
      rate.status === 'ACTIVA' ? 'Desactivar' : 'Activar']],
    details: rate => managementDetails('Detalle de tarifa', [
      ['Recinto', siteName(courts[rate.court][1])], ['Cancha', courts[rate.court][0]], ['Modalidad', rate.mode],
      ['Día', weekdays[rate.day]], ['Franja', rate.start + '–' + rate.end], ['Desde', rate.from],
      ['Hasta', rate.until || 'Sin fecha de término'], ['Por hora', money.format(rate.rate)]
    ], button('manage-rate-split-' + rate.id, 'Dividir franja', 'btn-accent') +
      button('manage-rate-edit-' + rate.id, 'Editar tarifa'))
  };
}

function editTariff(rate = null) {
  const ids = courts.flatMap((_, i) => courtMeta[i]?.deleted ? [] : [i]);
  if (!ids.length) return showDialog('Sin canchas', '<p>Agrega una cancha para configurar su tarifa.</p>');
  const filtered = managementState.tarifas.filters.court;
  const court = rate?.court ?? (filtered !== undefined && filtered !== '' && ids.includes(Number(filtered)) ? Number(filtered) : ids[0]);
  managementForm(rate ? 'Editar tarifa' : 'Nueva tarifa', 'tariff', rate?.id || 0,
    editSelect('court', 'Cancha', ids.map(i => [String(i), siteName(courts[i][1]) + ' · ' + courts[i][0]]), String(court)) +
    editSelect('mode', 'Modalidad', courtModes(court).map(mode => [mode, mode]), rate?.mode) +
    editSelect('day', 'Día', weekdays.map((day, i) => [String(i), day]),
      String(rate?.day ?? (managementState.tarifas.filters.day || weekdayIndex(localClock()[0])))) +
    '<div class="row"><div class="col-6">' + clockField('start', 'Desde (hora)', rate?.start || '08:00') +
    '</div><div class="col-6">' + clockField('end', 'Hasta (hora)', rate?.end || '22:00', { end: true }) + '</div></div>' +
    '<p class="small text-secondary">Usa HH:MM, por ejemplo 22:00–24:00. Escribe 24:00 para terminar a medianoche.</p>' +
    field('from', 'Vigente desde', rate?.from || localClock()[0], 'type="date" required') +
    field('until', 'Vigente hasta', rate?.until, 'type="date"') +
    field('rate', 'Valor por hora (CLP)', rate?.rate, 'type="number" min="1" max="999999999" step="1" required') +
    editSelect('status', 'Estado', [['ACTIVA', 'Activa'], ['INACTIVA', 'Inactiva']], rate?.status || 'ACTIVA'));
}

function tariffConflict(rate) {
  return rate.status === 'ACTIVA' && demoTariffs.some(other => other.id !== rate.id &&
    other.status === 'ACTIVA' && other.court === rate.court && other.mode === rate.mode && other.day === rate.day &&
    rate.start < other.end && other.start < rate.end && (!rate.until || other.from <= rate.until) &&
    (!other.until || rate.from <= other.until));
}

function saveTariff(id, data, error) {
  const rate = { ...data, id: id || nextTariffId, court: Number(data.court), day: Number(data.day), rate: Number(data.rate) };
  if (!validClock(rate.start) || !validClock(rate.end, true)) return error('Escribe las horas en formato HH:MM.');
  if (rate.start >= rate.end) return error('La hora de término debe ser posterior al inicio. Para medianoche escribe 24:00.');
  if (rate.until && rate.until < rate.from) return error('La fecha de término de vigencia debe ser igual o posterior a la fecha de inicio.');
  if (!courtModes(rate.court).includes(rate.mode)) return error('Selecciona una modalidad admitida por la cancha.');
  if (tariffConflict(rate)) return error('La franja se cruza con otra tarifa activa. Si quieres cambiar el precio desde cierta hora, usa Dividir franja en la tarifa existente.');
  const existing = demoTariffs.find(other => other.id === id);
  if (existing) Object.assign(existing, rate);
  else { demoTariffs.push(rate); nextTariffId++; }
  managementState.tarifas.selected = rate.id;
  saveManagement();
  save('Tarifa guardada en la maqueta.');
}

function openTariffSplit(rate) {
  managementForm('Dividir franja · ' + weekdays[rate.day], 'tariff-split', rate.id,
    '<p>' + escapeHtml(courts[rate.court][0] + ' · ' + rate.mode) + '</p>' +
    '<p class="small text-secondary">La franja ' + escapeHtml(rate.start + '–' + rate.end) +
    ' se dividirá en dos con la misma vigencia. El primer tramo conserva su precio de ' +
    money.format(rate.rate) + ' por hora.</p>' +
    clockField('splitAt', 'Hora de cambio (HH:MM)', rate.start < '18:00' && '18:00' < rate.end ? '18:00' : '') +
    field('rate', 'Precio por hora del segundo tramo (CLP)', rate.rate,
      'type="number" min="1" max="999999999" step="1" required'));
}

function saveTariffSplit(id, data, error) {
  const rate = demoTariffs.find(entry => entry.id === id);
  if (!rate) return error('La tarifa ya no está disponible.');
  const value = Number(data.rate);
  if (!validClock(data.splitAt) ||
      data.splitAt <= rate.start || data.splitAt >= rate.end) {
    return error('Elige una hora entre ' + rate.start + ' y ' + rate.end + '.');
  }
  if (!Number.isSafeInteger(value) || value < 1 || value > 999999999) return error('Ingresa un precio por hora válido.');
  const first = { ...rate, end: data.splitAt };
  const second = { ...rate, start: data.splitAt, rate: value };
  if (tariffConflict(first) || tariffConflict(second)) return error('Las franjas se cruzan con otra tarifa activa.');
  Object.assign(rate, first);
  demoTariffs.push({ ...second, id: nextTariffId++ });
  saveManagement();
  save('Franja dividida. Los precios ya se aplican a nuevas cotizaciones.');
}

function tariffAction(action) {
  if (action === 'manage-new-tariff') return editTariff();
  const match = /^manage-rate-(edit|toggle|split)-(\d+)$/.exec(action);
  if (!match) return;
  const rate = demoTariffs.find(rate => rate.id === Number(match[2]));
  if (!rate) return;
  if (match[1] === 'edit') return editTariff(rate);
  if (match[1] === 'split') return openTariffSplit(rate);
  const status = rate.status === 'ACTIVA' ? 'INACTIVA' : 'ACTIVA';
  if (tariffConflict({ ...rate, status })) return feedback('La tarifa se cruza con una franja activa.');
  rate.status = status;
  saveManagement();
  save('Estado de tarifa actualizado.');
}
