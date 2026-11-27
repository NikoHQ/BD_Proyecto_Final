'use strict';

let selectedTournament = null;
let inscripcionesTorneo = [];
let inscripcionesCargadas = false;

const torneoActual = () => panel.torneos.find(torneo => torneo.id === selectedTournament) || panel.torneos[0] || null;

const torneoEstado = {
  PLANIFICADO: { nombre: 'Planificado', clase: 'upcoming', simbolo: 'calendar-event' },
  EN_CURSO: { nombre: 'En curso', clase: 'in-progress', simbolo: 'play-circle-fill' },
  FINALIZADO: { nombre: 'Finalizado', clase: 'finished', simbolo: 'check2-circle' },
  CANCELADO: { nombre: 'Cancelado', clase: 'finished', simbolo: 'x-circle' }
};

function tournamentBadge() {
  return `<span class="status tournament-block">${icon('trophy-fill')} Torneo</span>`;
}

function tournamentStateBadge(torneo) {
  const estado = torneoEstado[torneo.estado] || { nombre: torneo.estado, clase: 'upcoming', simbolo: 'calendar-event' };
  return `<span class="status tournament-state ${estado.clase}">${icon(estado.simbolo)} ${estado.nombre}</span>`;
}

const tournamentDates = torneo => torneo.inicio === torneo.termino
  ? dayLabel(torneo.inicio) : `${dayLabel(torneo.inicio)} – ${dayLabel(torneo.termino)}`;

function tournamentCards() {
  if (!panel.torneos.length) return '<p class="empty">Todavía no hay torneos. Crea el primero.</p>';
  return `<div class="tournament-cards tournament-picker">${panel.torneos.map(torneo => {
    const seleccionado = torneo.id === torneoActual()?.id;
    return `<button type="button" class="tournament-option${seleccionado ? ' is-selected' : ''}" data-tournament="${torneo.id}" aria-pressed="${seleccionado}">
      <span class="tournament-symbol">${icon('trophy')}</span>
      <span class="tournament-card-content"><strong>${escapeHtml(torneo.nombre)}</strong>
        <span>${tournamentDates(torneo)}</span>
        <span>${escapeHtml(torneo.modalidad.nombre)} · ${torneo.inscritos} de ${torneo.cupos} equipos</span>
        ${tournamentStateBadge(torneo)}</span>
      ${icon('chevron-right')}
    </button>`;
  }).join('')}</div>`;
}

function tournamentProgress(torneo) {
  const porcentaje = Math.round(torneo.inscritos / torneo.cupos * 100);
  return `<div class="tournament-progress">
    <div class="d-flex justify-content-between gap-2"><span>Inscripción de equipos: ${torneo.inscritos} de ${torneo.cupos}</span><strong>${porcentaje}%</strong></div>
    <div class="progress" role="progressbar" aria-label="Inscripción de equipos" aria-valuemin="0" aria-valuemax="${torneo.cupos}" aria-valuenow="${torneo.inscritos}"><div class="progress-bar" style="width:${porcentaje}%"></div></div></div>`;
}

function tablaInscripciones() {
  const filas = inscripcionesTorneo.map(inscripcion => [
    `<strong>${escapeHtml(inscripcion.equipo)}</strong>`,
    escapeHtml(inscripcion.capitan.nombre),
    String(inscripcion.cantidad),
    inscripcion.fecha,
    `<span class="status ${inscripcion.estado === 'INSCRITO' ? 'confirmed' : 'cancelled'}">${inscripcion.estado === 'INSCRITO' ? 'Inscrito' : 'Retirado'}</span>`,
    `<div class="d-flex flex-wrap gap-1">
      <button class="btn btn-outline-secondary btn-sm" data-action="view-team-${inscripcion.id}">Plantilla</button>
      ${inscripcion.estado === 'INSCRITO' ? `<button class="btn btn-outline-secondary btn-sm" data-action="add-player-${inscripcion.id}">Jugador</button>
      <button class="btn btn-outline-danger btn-sm" data-action="withdraw-team-${inscripcion.id}">Retirar</button>` : ''}
    </div>`
  ]);
  return table(['Equipo', 'Capitán', 'Jugadores', 'Inscrito', 'Estado', ''], filas, 'Sin equipos inscritos en este torneo.');
}

function tournamentView() {
  if (!panel.torneos.length) {
    return `${heading('Torneos', 'Sin torneos registrados.', button('new-tournament', `${icon('plus-lg')} Nuevo torneo`, 'btn-accent'))}
      <p class="empty">Crea un torneo para inscribir equipos y programar sus bloques.</p>`;
  }
  const torneo = torneoActual();
  const restantes = torneo.cupos - torneo.inscritos;
  const abierto = torneo.estado === 'PLANIFICADO' || torneo.estado === 'EN_CURSO';
  return `${heading('Torneos', 'Inscripciones, plantillas y programación de bloques.', button('new-tournament', `${icon('plus-lg')} Nuevo torneo`, 'btn-accent'))}
    <div class="tournament-layout">
      <aside aria-label="Elegir torneo">${tournamentCards()}</aside>
      <section class="card mb-0" aria-labelledby="tournament-title">
        <div class="card-body tournament-header">
          <div class="d-flex flex-wrap align-items-start justify-content-between gap-2">
            <div><div class="d-flex flex-wrap align-items-center gap-2"><h2 id="tournament-title">${escapeHtml(torneo.nombre)}</h2>${tournamentStateBadge(torneo)}</div>
              <p class="small text-secondary mb-0">${escapeHtml(torneo.modalidad.nombre)} · ${tournamentDates(torneo)}</p>
              <p class="small text-secondary mb-0">${torneo.minimo}–${torneo.maximo} jugadores por equipo</p></div>
            <div class="d-flex flex-wrap gap-2">
              ${button('tournament-agenda', `${icon('calendar3')} Ver en Agenda`, 'btn btn-light border btn-sm')}
              ${abierto ? button('register-team', `${icon('person-plus')} Inscribir equipo`, 'btn-accent btn-sm') : ''}
            </div>
          </div>
          ${tournamentProgress(torneo)}
          <div class="d-flex flex-wrap gap-2 mt-3">
            ${abierto ? button('schedule-tournament', 'Programar cancha') : ''}
            ${abierto ? button('adjust-maximum', 'Ajustar máximo') : ''}
            ${button('delete-tournament', 'Eliminar torneo', 'btn btn-outline-danger btn-sm')}
          </div>
        </div>
        <div class="tournament-schedule border-top border-bottom">
          <div class="d-flex flex-wrap justify-content-between align-items-center gap-2">
            <span class="small text-secondary">${restantes > 0 ? `${restantes} ${restantes === 1 ? 'cupo disponible' : 'cupos disponibles'}` : 'Cupos completos'} · ${torneo.inscritos} equipos</span>
            <span class="small text-secondary">Los bloques programados aparecen en la agenda como reservas de torneo.</span>
          </div>
        </div>
        <div class="card-body p-0">${tablaInscripciones()}</div>
      </section>
    </div>`;
}

async function cargarPantallaTorneos() {
  await cargarTorneos();
  const torneo = torneoActual();
  if (!torneo) { inscripcionesTorneo = []; return; }
  selectedTournament = torneo.id;
  try {
    inscripcionesTorneo = await torneosApi.inscripciones(torneo.id);
  } catch {
    inscripcionesTorneo = [];
  }
  inscripcionesCargadas = true;
}

/* ------------------------------------------------------------------ */
/* Formularios                                                        */
/* ------------------------------------------------------------------ */

const errorTorneo = '<p class="text-danger small mt-2 mb-0" id="tournament-form-error" role="alert"></p>';
const mostrarErrorTorneo = mensaje => { const nodo = $('tournament-form-error'); if (nodo) nodo.textContent = mensaje; };

function openTournamentConfig() {
  showDialog('Nuevo torneo', `<form id="tournament-config-form" class="row g-3">
    <div class="col-12">${editSelect('modalidad', 'Modalidad', panel.modalidades.map(m => [m.id, `${m.nombre} · ${m.minimo}–${m.maximo} por equipo`]), panel.modalidades[0]?.id)}</div>
    <div class="col-12">${field('nombre', 'Nombre del torneo', '', 'required maxlength="100"')}</div>
    <div class="col-6">${field('inicio', 'Fecha de inicio', localClock()[0], 'type="date" required')}</div>
    <div class="col-6">${field('fin', 'Fecha de término', localClock()[0], 'type="date" required')}</div>
    <div class="col-6">${field('cupos', 'Cupos de equipos', '8', 'type="number" min="1" max="128" required')}</div>
    <div class="col-6">${field('minimo', 'Mínimo por equipo', '')}<small class="text-secondary">Vacío = el mínimo de la modalidad.</small></div>
    <div class="col-6">${field('maximo', 'Máximo por equipo', '')}<small class="text-secondary">Vacío = el máximo de la modalidad.</small></div>
    ${errorTorneo}
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Crear torneo</button></div></form>`);
}

function openTeamRegistration() {
  const torneo = torneoActual();
  if (!torneo) return;
  capitanSeleccionado = null;
  capitanesEncontrados = [];
  showDialog(`Inscribir equipo · ${torneo.nombre}`, `<form id="team-registration-form" class="row g-3">
    <div class="col-12">${field('equipo', 'Nombre del equipo', '', 'required maxlength="100"')}</div>
    <div class="col-12"><label class="form-label" for="captain-query">Capitán</label>
      <input class="form-control" type="search" id="captain-query" placeholder="RUT o nombre del cliente" autocomplete="off">
      <input type="hidden" id="captain-id" name="cliente" required>
      <div id="captain-results" class="list-group mt-1" hidden></div>
      <p id="captain-status" class="small text-secondary mb-0" role="status"></p></div>
    ${errorTorneo}
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Inscribir equipo</button></div></form>`);
}

function openAddPlayer(inscripcion) {
  showDialog(`Agregar jugador · ${inscripcion.equipo}`, `<form id="add-player-form" data-inscripcion="${inscripcion.id}" class="row g-3">
    <div class="col-sm-7">${field('nombre', 'Nombre del jugador', '', 'required maxlength="100"')}</div>
    <div class="col-sm-5">${field('rut', 'RUT con DV', '', 'required maxlength="12"')}</div>
    <p class="small text-secondary mb-0">Plantilla: ${inscripcion.cantidad} de ${torneoActual().maximo}. El RUT no se puede repetir en el torneo.</p>
    ${errorTorneo}
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Agregar jugador</button></div></form>`);
}

function openTournamentSchedule() {
  const torneo = torneoActual();
  showDialog(`Programar cancha · ${torneo.nombre}`, `<form id="tournament-schedule-form" class="row g-3">
    <div class="col-12"><label class="form-label">Cancha<select class="form-select" name="cancha" required>${panel.canchas.filter(cancha => canchaDisponible(cancha.id)).map(cancha => selectOption(cancha.id, `${cancha.nombre} · ${nombreRecinto(cancha.recinto)}`)).join('')}</select></label></div>
    <div class="col-12">${field('fecha', 'Fecha', torneo.inicio, 'type="date" min="' + torneo.inicio + '" max="' + torneo.termino + '" required')}</div>
    <div class="col-6">${clockField('desde', 'Desde', '18:00')}</div>
    <div class="col-6">${clockField('hasta', 'Hasta', '21:00')}</div>
    <p class="small text-secondary mb-0">El rango debe cubrir bloques completos de una hora. Cada bloque queda como reserva del torneo.</p>
    ${errorTorneo}
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Programar</button></div></form>`);
}

function openAdjustMaximum() {
  const torneo = torneoActual();
  showDialog(`Ajustar plantilla · ${torneo.nombre}`, `<form id="tournament-maximum-form" class="row g-3">
    <div class="col-6">${field('minimo', 'Mínimo por equipo', torneo.minimo, 'type="number" min="1" max="50" required')}</div>
    <div class="col-6">${field('maximo', 'Máximo por equipo', torneo.maximo, 'type="number" min="1" max="50" required')}</div>
    <p class="small text-secondary mb-0">El máximo no puede quedar bajo la plantilla activa más grande.</p>
    ${errorTorneo}
    <div class="d-flex justify-content-end"><button class="btn btn-accent">Guardar rango</button></div></form>`);
}

async function openTournamentTeams(inscripcion) {
  try {
    const detalle = await torneosApi.inscripcion(inscripcion.id);
    showDialog(`Plantilla · ${detalle.equipo}`, `<div class="d-flex justify-content-between mb-2"><strong>${escapeHtml(detalle.torneo.nombre)}</strong><span class="small text-secondary">${detalle.cantidad} de ${detalle.maximo}</span></div>
      <p class="small text-secondary">Capitán: ${escapeHtml(detalle.capitan.nombre)}</p>
      ${table(['Jugador', 'RUT'], detalle.jugadores.map(jugador => [escapeHtml(jugador.nombre), escapeHtml(jugador.rut)]), 'Sin jugadores en la plantilla.')}
      ${button(`add-player-${detalle.id}`, 'Agregar jugador', 'btn-accent mt-3')}`);
  } catch (error) {
    feedback(error.message);
  }
}

/* ------------------------------------------------------------------ */
/* Envíos                                                             */
/* ------------------------------------------------------------------ */

let capitanSeleccionado = null;
let capitanBusqueda = null;
let capitanesEncontrados = [];

function updateCaptainResults() {
  const consulta = $('captain-query')?.value.trim() || '';
  const lista = $('captain-results');
  if (!lista) return;
  clearTimeout(capitanBusqueda);
  if (consulta.length < 2) { lista.hidden = true; lista.replaceChildren(); return; }
  capitanBusqueda = setTimeout(async () => {
    try {
      const datos = await clientesApi.buscar(consulta);
      capitanesEncontrados = datos.items;
      lista.innerHTML = capitanesEncontrados.map(cliente =>
        button(`select-captain-${cliente.id}`, escapeHtml(`${cliente.nombre} · ${cliente.rut}`), 'list-group-item list-group-item-action text-start')).join('');
      lista.hidden = !lista.children.length;
      $('captain-status').textContent = lista.children.length ? '' : 'Sin coincidencias. Crea la ficha desde Reservas.';
    } catch (error) {
      $('captain-status').textContent = error.message;
    }
  }, 250);
}

async function guardarTorneo(form) {
  const datos = Object.fromEntries(new FormData(form));
  try {
    const creado = await torneosApi.crear({
      modalidad: Number(datos.modalidad), nombre: datos.nombre, inicio: datos.inicio, fin: datos.fin,
      cupos: Number(datos.cupos), minimo: datos.minimo === '' ? '' : Number(datos.minimo), maximo: datos.maximo === '' ? '' : Number(datos.maximo)
    });
    selectedTournament = creado.id;
    dialog.hide();
    await cargarPantallaTorneos();
    feedback('Torneo creado.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

async function guardarInscripcion(form) {
  const datos = Object.fromEntries(new FormData(form));
  if (!capitanSeleccionado) { mostrarErrorTorneo('Selecciona un capitán.'); return; }
  try {
    await torneosApi.inscribir({ torneo: torneoActual().id, cliente: capitanSeleccionado.id, equipo: datos.equipo });
    dialog.hide();
    await cargarPantallaTorneos();
    feedback('Equipo inscrito.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

async function guardarJugador(form) {
  const datos = Object.fromEntries(new FormData(form));
  try {
    await torneosApi.agregar({ inscripcion: Number(form.dataset.inscripcion), rut: datos.rut, nombre: datos.nombre });
    dialog.hide();
    await cargarPantallaTorneos();
    feedback('Jugador agregado.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

async function guardarProgramacion(form) {
  const datos = Object.fromEntries(new FormData(form));
  try {
    await torneosApi.programar({
      torneo: torneoActual().id, cancha: Number(datos.cancha), fecha: datos.fecha,
      desde: datos.desde, hasta: datos.hasta
    });
    dialog.hide();
    await recargarAgenda(datos.fecha);
    feedback('Bloques programados. Ya aparecen en la agenda.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

async function guardarMaximo(form) {
  const datos = Object.fromEntries(new FormData(form));
  try {
    await torneosApi.rango(torneoActual().id, Number(datos.minimo), Number(datos.maximo));
    dialog.hide();
    await cargarPantallaTorneos();
    feedback('Rango actualizado.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

async function retirarEquipo(inscripcion) {
  try {
    await torneosApi.retirar(inscripcion.id);
    dialog.hide();
    await cargarPantallaTorneos();
    feedback(`Equipo ${inscripcion.equipo} retirado.`);
    render();
  } catch (error) {
    feedback(error.message);
  }
}

function confirmarRetiro(inscripcion) {
  showDialog('Retirar equipo', `<p>Se retirará <strong>${escapeHtml(inscripcion.equipo)}</strong> del torneo y se liberará su cupo.</p>
    ${button(`confirm-withdraw-${inscripcion.id}`, 'Sí, retirar', 'btn-danger')}`);
}

function confirmarBorradoTorneo() {
  const torneo = torneoActual();
  if (!torneo) return;
  showDialog(`Eliminar torneo · ${torneo.nombre}`, `<p>¿Eliminar <strong>${escapeHtml(torneo.nombre)}</strong>?</p>
    <p class="text-danger small">También se eliminarán sus bloques programados y equipos inscritos. Esta acción no se puede deshacer.</p>
    ${errorTorneo}
    <div class="d-flex gap-2 flex-wrap"><button type="button" class="btn btn-light border" data-bs-dismiss="modal">Cancelar</button>${button('confirm-delete-tournament', 'Eliminar torneo', 'btn-danger')}</div>`);
}

async function borrarTorneo() {
  const torneo = torneoActual();
  if (!torneo) return;
  try {
    await torneosApi.borrar(torneo.id);
    panel.reservas.clear();
    await recargarAgenda(torneo.inicio);
    selectedTournament = null;
    dialog.hide();
    await cargarPantallaTorneos();
    feedback('Torneo eliminado junto con sus bloques e inscripciones.');
    render();
  } catch (error) { mostrarErrorTorneo(error.message); }
}

document.addEventListener('input', event => {
  if (event.target.id === 'captain-query') updateCaptainResults();
});
