let selectedTournament = 0;
let selectedTournamentDay = tournaments[0].days[0];
const tournamentDates = ({ days }) => days.length === 1
  ? dayLabel(days[0]) : `${dayLabel(days[0])} – ${dayLabel(days.at(-1))}`;
function tournamentBadge() {
  return `<span class="status tournament-block">${icon('trophy-fill')} Torneo</span>`;
}
function tournamentState(tournament) {
  const state = tournamentStates[tournament.state];
  return tournament.state === 'PLANIFICADO' && localClock()[0] < tournament.days[0]
    ? { ...state, name: 'Próximamente' } : state;
}
function tournamentStateBadge(tournament) {
  const state = tournamentState(tournament);
  return `<span class="status tournament-state ${state.className}">${icon(state.symbol)} ${state.name}</span>`;
}
function tournamentProgress(tournament, compact = false) {
  const percent = Math.round(tournament.teams / tournament.capacity * 100);
  return `<div class="tournament-progress${compact ? ' compact' : ''}">
    <div class="d-flex justify-content-between gap-2"><span>${compact ? `${tournament.teams}/${tournament.capacity} equipos` : `Inscripción de equipos: ${tournament.teams} de ${tournament.capacity}`}</span><strong>${percent}%</strong></div>
    <div class="progress" role="progressbar" aria-label="Inscripción de equipos" aria-valuemin="0" aria-valuemax="${tournament.capacity}" aria-valuenow="${tournament.teams}"><div class="progress-bar" style="width:${percent}%"></div></div>
  </div>`;
}
function tournamentCards(selectable) {
  return `<div class="tournament-cards${selectable ? ' tournament-picker' : ''}">${tournaments.map((tournament, index) => {
    if (!selectable && !['PLANIFICADO', 'EN_CURSO'].includes(tournament.state)) return '';
    const selected = selectable && index === selectedTournament;
    return `<button type="button" class="tournament-option${selected ? ' is-selected' : ''}" data-tournament="${index}" ${selectable ? `aria-pressed="${selected}"` : ''}>
      <span class="tournament-symbol">${icon('trophy')}</span>
      <span class="tournament-card-content"><strong>${escapeHtml(tournament.name)}</strong>
        <span>${tournamentDates(tournament)}</span>
        <span>${escapeHtml(siteName(tournament.site))} · ${tournament.teams} de ${tournament.capacity} equipos</span>
        ${tournamentStateBadge(tournament)}</span>
      ${icon('chevron-right')}
    </button>`;
  }).join('')}</div>`;
}
function tournamentView() {
  const tournament = tournaments[selectedTournament];
  const blocks = tournamentBookings.filter(row => row.tournamentId === selectedTournament && row.status !== 'cancelled');
  const scheduled = blocks.filter(row => row.date === selectedTournamentDay);
  const committed = [...new Set(scheduled.map(row => row.court))];
  const rows = allBookings().filter(row => row.date === selectedTournamentDay && committed.includes(row.court)).sort(byTime);
  const totalMinutes = scheduled.reduce((total, row) => total + minutes(row.end) - minutes(row.start), 0);
  const duration = `${Math.floor(totalMinutes / 60)} h${totalMinutes % 60 ? ` ${totalMinutes % 60} min` : ''}`;
  const dates = tournament.days.map(day => `<button class="btn btn-sm ${day === selectedTournamentDay ? 'btn-accent' : 'btn-outline-secondary'}" type="button" data-action="tournament-day-${day}" aria-pressed="${day === selectedTournamentDay}">${dayLabel(day)}</button>`).join('');
  const legend = [tournamentBadge(), ...Object.keys(statuses).filter(state => rows.some(row => !isActiveTournamentBlock(row) && row.status === state)).map(badge)].join('');
  const [today, time] = localClock();
  const nextBlock = blocks.sort(byTime).find(row => row.date > today || (row.date === today && row.start >= time));
  const remaining = tournament.capacity - tournament.teams;
  const canRegister = tournamentRegistrationOpen(tournament);
  const facilities = committed.map(court => `<span class="facility-chip">${icon('geo-alt')} ${escapeHtml(courts[court][0])}</span>`).join('');
  const summary = `<aside class="tournament-summary" aria-label="Resumen del torneo">
    ${card('Resumen de uso', `<div class="card-body summary-list">
      <div><span>${icon('geo-alt')}</span><p>Canchas usadas<strong>${committed.length} de ${courts.filter(([, site]) => site === tournament.site).length}</strong></p></div>
      <div><span>${icon('clock')}</span><p>Horas reservadas<strong>${duration}</strong></p></div>
      <div><span>${icon('flag')}</span><p>Próximo hito<strong>${nextBlock ? `${escapeHtml(nextBlock.activity)} · ${dayLabel(nextBlock.date)} ${nextBlock.start}` : 'Sin bloques próximos'}</strong></p></div>
    </div><div class="summary-facilities"><strong>Instalaciones comprometidas</strong><div>${facilities || '<span class="text-secondary small">Sin canchas asignadas</span>'}</div></div>`) }
    ${card('Inscripción', `<div class="card-body planning-note"><span class="planning-icon">${icon(canRegister ? 'info-circle' : 'lock')}</span><div><strong>${canRegister ? (remaining === 1 ? '1 cupo disponible' : `${remaining} cupos disponibles`) : (!remaining ? 'Cupos completos' : tournament.state === 'PLANIFICADO' && !blocks.length ? 'Programa una cancha para abrir inscripciones' : 'Inscripciones cerradas')}</strong></div></div>`)}
  </aside>`;
  return `${heading('Torneos', '', button('new-tournament', `${icon('plus-lg')} Nuevo torneo`, 'btn-accent'))}
    <div class="tournament-layout">
      <aside aria-label="Elegir torneo">${tournamentCards(true)}</aside>
      <section class="card mb-0" aria-labelledby="tournament-title">
        <div class="card-body tournament-header">
          <div class="d-flex flex-wrap align-items-start justify-content-between gap-2">
            <div><div class="d-flex flex-wrap align-items-center gap-2"><h2 id="tournament-title">${escapeHtml(tournament.name)}</h2>${tournamentStateBadge(tournament)}</div><p class="small text-secondary mb-0">${escapeHtml(siteName(tournament.site))} · ${tournament.sport} · ${tournamentDates(tournament)}</p><p class="small text-secondary mb-0">${tournament.teamSize} por equipo · ${tournament.discount}% de descuento de cancha</p></div>
            <div class="d-flex flex-wrap gap-2">
              ${button('tournament-agenda', `${icon('calendar3')} Ver en Agenda`, 'btn btn-light border btn-sm')}
              ${canRegister ? button('register-team', `${icon('person-plus')} Inscribir equipo`, 'btn-accent btn-sm') : ''}
            </div>
          </div>
          ${tournamentProgress(tournament)}
          <div class="d-flex flex-wrap gap-2 mt-3">
            ${canScheduleTournament(tournament) ? button('schedule-tournament', 'Programar cancha') : ''}
            ${button('view-tournament-teams', 'Ver equipos')}
            ${button('manage-tournament', 'Administrar torneo')}
          </div>
        </div>
        <div class="tournament-schedule border-top border-bottom">
          <div class="d-flex flex-wrap gap-2" role="group" aria-label="Días del torneo">${dates}</div>
          <div class="d-flex flex-wrap justify-content-between align-items-center gap-2 mt-2"><span class="small text-secondary">${committed.length} ${committed.length === 1 ? 'cancha comprometida' : 'canchas comprometidas'} · ${duration} reservadas</span><div class="legend">${legend}</div></div>
        </div>
        ${scheduled.length ? timeline(rows, committed, selectedTournamentDay, selectedTournament) : '<p class="empty">Sin bloques reservados para este día.</p>'}
      </section>
      ${summary}
    </div>`;
}
function tournamentRegistrationOpen(tournament) {
  return tournament.state === 'PLANIFICADO' && tournament.teams < tournament.capacity &&
    localClock()[0] <= tournament.days.at(-1) && tournamentBlocks(tournament).length > 0;
}
const tournamentBlocks = tournament => tournamentBookings.filter(
  row => tournaments[row.tournamentId] === tournament && row.status !== 'cancelled'
);
const canScheduleTournament = tournament => ['PLANIFICADO', 'EN_CURSO'].includes(tournament.state);
const canEditTournament = tournament => tournament.state === 'PLANIFICADO' &&
  !tournament.roster.length && !tournament.teams && !tournamentBlocks(tournament).length;
const tournamentFormError = '<p class="text-danger small mt-2 mb-0" id="tournament-form-error" role="alert"></p>';
const showTournamentError = message => { $('tournament-form-error').textContent = message; };
const venueSports = site => [...new Set(courts.flatMap((row, i) => row[1] === site && courtAvailable(i) ? courtModes(i) : []))];

function openTournamentConfig(edit = false) {
  const tournament = edit ? tournaments[selectedTournament] : null;
  const demoSites = siteRecords.filter(entry => entry.status === 'ACTIVO' && venueSports(entry.key).length).map(entry => entry.key);
  if (!demoSites.length) return showDialog('Sin recintos disponibles', '<p>Activa un recinto con una instalación disponible.</p>');
  if (tournament && !canEditTournament(tournament)) return;
  const today = localClock()[0];
  const site = tournament?.site || demoSites[0];
  showDialog(edit ? 'Editar configuración' : 'Nuevo torneo', `
    <form id="tournament-config-form" data-edit="${edit}">
      <div class="row g-3">
        <label class="col-12">Nombre del torneo<input class="form-control" name="name" maxlength="100" required value="${escapeHtml(tournament?.name || '')}"></label>
        <label class="col-sm-6">Recinto<select class="form-select" id="tournament-site" name="site">${demoSites.map(value => selectOption(value, siteName(value), value === site)).join('')}</select></label>
        <label class="col-sm-6">Modalidad<select class="form-select" id="tournament-sport" name="sport">${venueSports(site).map(value => selectOption(value, value, value === tournament?.sport)).join('')}</select></label>
        <label class="col-sm-6">Fecha de inicio<input class="form-control" type="date" name="startDate" min="${today}" required value="${tournament?.days[0] || today}"></label>
        <label class="col-sm-6">Fecha de término<input class="form-control" type="date" name="endDate" min="${today}" required value="${tournament?.days.at(-1) || today}"></label>
        <label class="col-sm-6">Cupos de equipos<input class="form-control" type="number" name="capacity" min="2" max="128" required value="${tournament?.capacity ?? 8}"></label>
        <label class="col-sm-6">Jugadores por equipo<input class="form-control" type="number" name="teamSize" min="1" max="50" required value="${tournament?.teamSize ?? 2}"><small class="text-secondary">Incluye al capitán. Para modalidad individual usa 1.</small></label>
        <label class="col-sm-6">Descuento de cancha (%)<input class="form-control" type="number" name="discount" min="0" max="100" step="0.01" required value="${tournament?.discount ?? 0}"></label>
      </div>
      ${tournamentFormError}${modalActions(edit ? 'Guardar configuración' : 'Crear torneo')}
    </form>`);
}
function saveTournamentConfig(form) {
  const fields = Object.fromEntries(new FormData(form));
  const name = fields.name.trim();
  const edit = form.dataset.edit === 'true';
  const existing = edit ? tournaments[selectedTournament] : null;
  if (existing && !canEditTournament(existing)) return;
  if (!name || fields.endDate < fields.startDate) return showTournamentError('Ingresa un nombre y un rango de fechas válido.');
  if (tournaments.some(t => t !== existing && t.site === fields.site && t.name.toLowerCase() === name.toLowerCase())) {
    return showTournamentError('Ya existe un torneo con ese nombre en el recinto.');
  }
  const config = {
    name, site: fields.site, sport: fields.sport, capacity: Number(fields.capacity),
    teamSize: Number(fields.teamSize), discount: Number(fields.discount),
    days: [...new Set([fields.startDate, fields.endDate])]
  };
  if (existing) Object.assign(existing, config);
  else {
    selectedTournament = tournaments.length;
    tournaments.push({ ...config, state: 'PLANIFICADO', roster: [], teams: 0 });
  }
  selectedTournamentDay = fields.startDate;
  completeTournamentAction(edit ? 'Configuración actualizada.' : 'Torneo creado. Ya puedes programar las canchas.');
}
function openTournamentSchedule() {
  const tournament = tournaments[selectedTournament];
  if (!canScheduleTournament(tournament)) return;
  const choices = courts.flatMap(([name, site], index) =>
    courtAvailable(index) && site === tournament.site && courtModes(index).includes(tournament.sport) ? [selectOption(index, name)] : []);
  showDialog('Programar cancha', `
    <p class="fw-semibold">${escapeHtml(tournament.name)}</p>
    <form id="tournament-schedule-form">
      <div class="row g-3">
        <label class="col-sm-6">Fecha<input class="form-control" type="date" name="date" min="${tournament.days[0]}" max="${tournament.days.at(-1)}" value="${selectedTournamentDay}" required></label>
        <label class="col-sm-6">Cancha<select class="form-select" name="court" required>${choices.join('')}</select></label>
        <div class="col-6">${clockField("start", "Inicio", "")}</div>
        <div class="col-6">${clockField("end", "Término", "", { end: true })}</div>
        <label class="col-12">Actividad (opcional)<input class="form-control" name="activity" maxlength="100" placeholder="Fase de grupos"></label>
      </div>
      ${tournamentFormError}${modalActions('Reservar bloque')}
    </form>`);
}
function saveTournamentBlock(form) {
  const tournament = tournaments[selectedTournament];
  if (!canScheduleTournament(tournament)) return;
  const { court, date: day, start, end, activity } = Object.fromEntries(new FormData(form));
  const facility = courts[Number(court)];
  if (!facility || !courtAvailable(Number(court)) || facility[1] !== tournament.site || !courtModes(Number(court)).includes(tournament.sport) ||
      day < tournament.days[0] || day > tournament.days.at(-1) ||
      !validClock(start) || !validClock(end, true) || start >= end) {
    return showTournamentError('Revisa la cancha, la fecha y el orden de las horas.');
  }
  if (!bookingWithinHours(Number(court), day, start, end)) return showTournamentError('El bloque queda fuera del horario del recinto.');
  const block = {
    id: nextTournamentBookingId, tournamentId: selectedTournament, court: Number(court), date: day,
    start, end, activity: activity.trim() || 'Bloque de torneo',
    client: tournament.name, status: 'confirmed', origin: 'Torneo', amount: 0
  };
  const crossing = conflicts(block)[0];
  if (crossing) return showTournamentError(`La cancha ya está ocupada de ${crossing.start} a ${crossing.end}.`);
  tournamentBookings.push(block);
  nextTournamentBookingId++;
  if (!tournament.days.includes(day)) tournament.days.push(day);
  tournament.days.sort();
  selectedTournamentDay = day;
  completeTournamentAction('Cancha reservada. El bloque ya aparece en Agenda.');
}
function canEditTeam(tournament, team) {
  return Boolean(team && !team.withdrawn && ['PLANIFICADO', 'EN_CURSO'].includes(tournament.state));
}
function teamCaptain(team) {
  return demoClients.find(client => client.id === team.captainId) || team.players[0];
}
function openTeamRegistration(teamIndex = null) {
  const tournament = tournaments[selectedTournament];
  const editing = teamIndex !== null;
  const team = editing ? tournament.roster[teamIndex] : null;
  if (editing ? !canEditTeam(tournament, team) : !tournamentRegistrationOpen(tournament)) return;
  const captain = team ? teamCaptain(team) : null;
  showDialog(editing ? 'Editar equipo' : 'Inscribir equipo', `
    <p class="fw-semibold mb-1">${escapeHtml(tournament.name)}</p>
    <p class="small text-secondary">Usa datos ficticios para probar la inscripción.</p>
    <form id="team-registration-form" data-tournament-id="${selectedTournament}" data-team-index="${teamIndex ?? ''}" autocomplete="off">
      <label for="team-name" class="form-label">Nombre del equipo</label>
      <input class="form-control mb-3" id="team-name" name="teamName" maxlength="100" value="${escapeHtml(team?.name || '')}" required>
      <label for="captain-query" class="form-label">Capitán</label>
      <input class="form-control" type="search" id="captain-query" placeholder="Escribe el RUT o nombre del cliente" value="${escapeHtml(captain ? captain.name + ' · ' + captain.rut : '')}" aria-describedby="captain-help">
      <input type="hidden" id="team-captain" name="captainId" value="${captain?.id ?? ''}">
      <div id="captain-results" class="list-group mt-1" role="group" aria-label="Coincidencias de clientes" hidden></div>
      <p id="captain-status" class="small text-secondary mb-0" role="status"></p>
      <p id="captain-help" class="form-text">El capitán queda inscrito como primer jugador del equipo.</p>
      <fieldset id="captain-create-fields" class="border rounded p-3 mt-2" hidden disabled>
        <legend class="fs-6 fw-semibold">Ficha del cliente</legend>
        <div class="row g-2">
          <label class="col-sm-7">Nombre completo<input class="form-control" name="captainName" maxlength="100" required></label>
          <label class="col-sm-5">RUT con DV<input class="form-control" name="captainRut" maxlength="12" required></label>
          <label class="col-sm-6">Teléfono (opcional)<input class="form-control" type="tel" name="captainPhone" maxlength="20"></label>
          <label class="col-sm-6">Correo (opcional)<input class="form-control" type="email" name="captainEmail" maxlength="150"></label>
        </div>
        <p id="captain-create-error" class="text-danger small mb-0" role="alert"></p>
        <div class="d-flex flex-wrap gap-2 mt-2">
          ${button('save-captain', 'Guardar y seleccionar', 'btn-accent btn-sm')}
          ${button('close-captain-create', 'Cancelar alta')}
        </div>
      </fieldset>
      <fieldset class="mt-3 border-top pt-3">
        <legend class="fs-6 fw-semibold mb-1">Plantilla · ${tournament.teamSize} ${tournament.teamSize === 1 ? 'jugador' : 'jugadores'}</legend>
        ${tournament.teamSize === 1 ? '<p class="small text-secondary mb-2">El capitán ocupa el único lugar de la plantilla.</p>' :
          Array.from({ length: tournament.teamSize - 1 }, (_, i) => `
            <div class="row g-2 mb-2">
              <label class="col-sm-7">Jugador ${i + 2} · Nombre completo<input class="form-control" name="playerName" value="${escapeHtml(team?.players[i + 1]?.name || '')}" maxlength="100" required></label>
              <label class="col-sm-5">Jugador ${i + 2} · RUT con DV<input class="form-control" name="playerRut" value="${escapeHtml(team?.players[i + 1]?.rut || '')}" maxlength="12" required></label>
            </div>`).join('')}
      </fieldset>
      <p id="team-form-error" class="text-danger small mt-2 mb-0" role="alert"></p>
      <div class="d-flex flex-wrap justify-content-end gap-2 mt-3">
        ${editing ? button('view-tournament-teams', 'Volver a equipos') : '<button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancelar</button>'}
        <button type="submit" class="btn btn-accent">${editing ? 'Guardar equipo' : 'Inscribir equipo'}</button>
      </div>
    </form>`);
}
function updateCaptainResults() {
  $('team-captain').value = '';
  const query = $('captain-query').value.trim();
  const exactRut = parseRut(query);
  const rutQuery = compactRut(query);
  const nameQuery = normalizeName(query);
  const matches = query ? demoClients.filter(client => exactRut
    ? client.rut === exactRut
    : normalizeName(client.name).includes(nameQuery) || (rutQuery && compactRut(client.rut).includes(rutQuery))) : [];
  const list = $('captain-results');
  const status = $('captain-status');
  const limit = 5;
  list.innerHTML = matches.slice(0, limit).map(client =>
    button(`select-captain-${client.id}`, escapeHtml(`${client.name} · ${client.rut}`), 'list-group-item list-group-item-action text-start')
  ).join('');
  if (exactRut && !matches.length) {
    list.innerHTML = button('open-captain-create', `Crear cliente con RUT ${escapeHtml(exactRut)}`, 'list-group-item list-group-item-action text-start');
  }
  list.hidden = !list.children.length;
  status.textContent = '';
  if (matches.length > limit) status.textContent = 'Se muestran 5 coincidencias. Afina la búsqueda.';
  if (query && !matches.length) {
    status.textContent = exactRut ? 'El RUT no tiene ficha de cliente.' : 'Sin coincidencias. Para crear una ficha, ingresa el RUT completo con DV.';
  }
}
function selectCaptain(client) {
  if (!clientActive(client)) {
    $('captain-status').textContent = 'La ficha está inactiva.';
    return;
  }
  $('team-captain').value = client.id;
  $('captain-query').value = `${client.name} · ${client.rut}`;
  $('captain-status').textContent = 'Capitán seleccionado.';
  $('captain-results').hidden = true;
  $('captain-results').replaceChildren();
  $('captain-query').focus();
}
function toggleCaptainCreate(open) {
  const query = $('captain-query');
  const fields = $('captain-create-fields');
  fields.hidden = !open;
  fields.disabled = !open;
  query.readOnly = open;
  if (open) {
    fields.querySelector('[name="captainRut"]').value = parseRut(query.value) || '';
    $('captain-results').hidden = true;
    fields.querySelector('input').focus();
  } else {
    if (!$('team-captain').value) updateCaptainResults();
    query.focus();
  }
}
function saveCaptain() {
  const fields = $('captain-create-fields');
  if ([...fields.querySelectorAll('input')].some(field => !field.reportValidity())) return;
  const form = $('team-registration-form').elements;
  const name = form.captainName.value.trim();
  const rut = parseRut(form.captainRut.value);
  const email = form.captainEmail.value.trim().toLowerCase();
  const error = $('captain-create-error');
  if (!rut || !name) { error.textContent = 'Ingresa el nombre y un RUT válido.'; return; }
  let client = demoClients.find(entry => entry.rut === rut);
  if (!client) {
    if (email && demoClients.some(entry => entry.email === email)) {
      error.textContent = 'Ese correo ya está asociado a otra ficha.';
      return;
    }
    client = { id: nextClientId++, name, rut, phone: form.captainPhone.value.trim(), email, type: 'Persona' };
    demoClients.push(client);
    saveManagement();
  }
  fields.querySelectorAll('input').forEach(input => { input.value = ''; });
  error.textContent = '';
  selectCaptain(client);
  toggleCaptainCreate(false);
}
function submitTeamRegistration(form) {
  const tournament = tournaments[Number(form.dataset.tournamentId)];
  const editing = form.dataset.teamIndex !== '';
  const existing = editing ? tournament.roster[Number(form.dataset.teamIndex)] : null;
  const teamName = form.elements.teamName.value.trim();
  const error = message => { $('team-form-error').textContent = message; };
  const captain = demoClients.find(client => client.id === Number(form.elements.captainId.value));
  if (!$('captain-create-fields').hidden) return error('Guarda o cancela la ficha del cliente antes de continuar.');
  if (!teamName || !captain || !clientActive(captain)) return error('Ingresa el nombre del equipo y selecciona un capitán activo.');
  if (editing ? !canEditTeam(tournament, existing) : !tournamentRegistrationOpen(tournament)) {
    return error(editing ? 'Este equipo no admite cambios.' : 'Este torneo ya no admite inscripciones.');
  }
  if (tournament.roster.some(team => team !== existing && normalizeName(team.name) === normalizeName(teamName))) {
    return error('Ya existe un equipo con ese nombre en el torneo.');
  }
  const data = new FormData(form);
  const ruts = data.getAll('playerRut');
  const players = data.getAll('playerName').map((name, index) => {
    const rut = parseRut(ruts[index]);
    const client = demoClients.find(entry => entry.rut === rut);
    return { name: client?.name || name.trim(), rut };
  });
  if (players.length !== tournament.teamSize - 1 || players.some(player => !player.name || !player.rut)) {
    return error('Completa la plantilla con nombres y RUT válidos.');
  }
  players.unshift({ name: captain.name, rut: captain.rut });
  const playerRuts = new Set(players.map(player => player.rut));
  if (playerRuts.size !== players.length) return error('Hay un RUT repetido dentro del equipo.');
  if (tournament.roster.some(team => team !== existing && !team.withdrawn &&
      (playerRuts.has(teamCaptain(team)?.rut) || team.players.slice(1).some(player => playerRuts.has(player.rut))))) {
    return error('Uno de los jugadores ya está inscrito en otro equipo de este torneo.');
  }
  const changes = { name: teamName, captainId: captain.id, players };
  if (existing) Object.assign(existing, changes);
  else tournament.roster.push({ ...changes, withdrawn: false });
  tournament.teams = tournament.roster.filter(team => !team.withdrawn).length;
  saveDemoTournaments();
  render();
  openTournamentTeams();
  feedback(`Equipo «${teamName}» ${editing ? 'actualizado' : 'inscrito'} en la maqueta.`);
}
function completeTournamentAction(message) {
  saveDemoTournaments();
  dialog.hide();
  render();
  feedback(message);
}
function openTournamentTeams() {
  const tournament = tournaments[selectedTournament];
  const teams = tournament.roster.map((team, index) => {
    const captain = teamCaptain(team);
    return `
    <details class="border rounded p-2 mb-2">
      <summary>
        <strong>${escapeHtml(team.name)}</strong>
        <span class="status ${team.withdrawn ? 'cancelled' : 'completed'}">${team.withdrawn ? 'Retirado' : 'Inscrito'}</span>
        <span class="d-block ms-3 small text-secondary">Capitán: ${escapeHtml(captain?.name || '—')}</span>
      </summary>
      <ol class="small mt-2 mb-2">${team.players.map((player, i) =>
        `<li>${escapeHtml((i === 0 ? captain : player).name)} · ${escapeHtml((i === 0 ? captain : player).rut)}${i === 0 ? ' · Capitán' : ''}</li>`).join('')}</ol>
      <div class="d-flex flex-wrap gap-2">
      ${canEditTeam(tournament, team) ? button(`edit-team-${index}`, 'Editar equipo', 'btn-accent btn-sm') : ''}
      ${tournament.state === 'PLANIFICADO' && !team.withdrawn ?
        button(`withdraw-team-${index}`, 'Retirar equipo', 'btn-outline-danger btn-sm') : ''}
      </div>
    </details>`;
  }).join('');
  showDialog('Equipos del torneo', `
    <p class="fw-semibold">${escapeHtml(tournament.name)} · ${tournament.teams} de ${tournament.capacity} inscritos</p>
    ${teams || '<p class="text-secondary">Todavía no hay equipos inscritos.</p>'}`);
}
function requestTeamWithdrawal(index) {
  const tournament = tournaments[selectedTournament];
  const team = tournament.roster[index];
  if (tournament.state !== 'PLANIFICADO' || !team || team.withdrawn) return;
  showDialog('Retirar equipo', `<p>Se liberará el cupo de <strong>${escapeHtml(team.name)}</strong>.</p>
    <div class="d-flex gap-2">${button('view-tournament-teams', 'Volver')}
    ${button(`confirm-team-withdrawal-${index}`, 'Confirmar retiro', 'btn-danger btn-sm')}</div>`);
}
function confirmTeamWithdrawal(index) {
  const tournament = tournaments[selectedTournament];
  const team = tournament.roster[index];
  if (tournament.state !== 'PLANIFICADO' || !team || team.withdrawn) return;
  team.withdrawn = true;
  tournament.teams = tournament.roster.filter(entry => !entry.withdrawn).length;
  saveDemoTournaments();
  render();
  openTournamentTeams();
  feedback('Equipo retirado. El cupo quedó disponible.');
}
function canStartTournament(tournament) {
  const [today] = localClock();
  return tournament.state === 'PLANIFICADO' && today >= tournament.days[0] &&
    today <= tournament.days.at(-1) && tournamentBlocks(tournament).length > 0;
}
function openTournamentManagement() {
  const tournament = tournaments[selectedTournament];
  const blocks = tournamentBlocks(tournament).sort(byTime);
  const active = canScheduleTournament(tournament);
  showDialog('Administrar torneo', `
    <div class="d-flex flex-wrap gap-2 align-items-center mb-3"><strong>${escapeHtml(tournament.name)}</strong>${tournamentStateBadge(tournament)}</div>
    <div class="d-flex flex-wrap gap-2 mb-3">
      ${canEditTournament(tournament) ? button('edit-tournament', 'Editar configuración') : ''}
      ${canStartTournament(tournament) ? button('ask-start-tournament', 'Iniciar torneo', 'btn-accent btn-sm') : ''}
      ${tournament.state === 'EN_CURSO' ? button('ask-finish-tournament', 'Finalizar torneo', 'btn-accent btn-sm') : ''}
      ${active ? button('ask-cancel-tournament', 'Cancelar torneo', 'btn-outline-danger btn-sm') : ''}
    </div>
    <h3 class="fs-6">Bloques reservados</h3>
    ${blocks.map(block => `<div class="border-top py-2 d-flex flex-wrap justify-content-between align-items-center gap-2">
      <span class="small">${dayLabel(block.date)} · ${block.start}–${block.end} · ${escapeHtml(courts[block.court][0])}</span>
      ${active ? button(`ask-release-tournament-block-${block.id}`, 'Liberar bloque', 'btn-outline-danger btn-sm') : ''}
    </div>`).join('') || '<p class="small text-secondary mb-0">Sin bloques activos.</p>'}`);
}
const transitionDetails = {
  start: ['Iniciar torneo', 'Al iniciar se cierran las inscripciones.', 'EN_CURSO'],
  finish: ['Finalizar torneo', 'Se cerrará la programación del torneo.', 'FINALIZADO'],
  cancel: ['Cancelar torneo', 'Se liberarán los bloques que aún no hayan terminado.', 'CANCELADO']
};
function tournamentTransition(action, confirmed = false) {
  const tournament = tournaments[selectedTournament];
  const allowed = action === 'start' ? canStartTournament(tournament)
    : action === 'finish' ? tournament.state === 'EN_CURSO' : canScheduleTournament(tournament);
  if (!allowed) return;
  const [title, message, state] = transitionDetails[action];
  if (!confirmed) {
    return showDialog(title, `<p>${message}</p><div class="d-flex gap-2">
      ${button('manage-tournament', 'Volver')}
      ${button(`confirm-${action}-tournament`, title, action === 'cancel' ? 'btn-danger btn-sm' : 'btn-accent btn-sm')}</div>`);
  }
  tournament.state = state;
  if (state === 'CANCELADO') {
    const [today, time] = localClock();
    tournamentBlocks(tournament).forEach(block => {
      if (block.date > today || (block.date === today && block.end > time)) block.status = 'cancelled';
    });
  }
  completeTournamentAction(`Torneo ${tournamentStates[state].name.toLowerCase()}.`);
}
function releaseTournamentBlock(id, confirmed = false) {
  const tournament = tournaments[selectedTournament];
  const block = tournamentBlocks(tournament).find(row => row.id === id);
  if (!block || !canScheduleTournament(tournament)) return;
  if (!confirmed) {
    return showDialog('Liberar bloque', `<p>${escapeHtml(courts[block.court][0])} · ${dayLabel(block.date)} · ${block.start}–${block.end}</p>
      <div class="d-flex gap-2">${button('manage-tournament', 'Volver')}
      ${button(`confirm-release-tournament-block-${id}`, 'Confirmar liberación', 'btn-danger btn-sm')}</div>`);
  }
  block.status = 'cancelled';
  saveDemoTournaments();
  render();
  openTournamentManagement();
  feedback('Bloque liberado en Agenda.');
}
