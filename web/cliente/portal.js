'use strict';

const $vista = () => document.getElementById('vista');
const clienteId = Number(document.body.dataset.cliente);
const autenticado = document.body.dataset.autenticado === '1';
const urlAcceso = '/cliente/login.php';
const esc = valor => String(valor ?? '').replace(/[&<>"']/g, caracter => ({
  '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;'
}[caracter]));
const pesos = new Intl.NumberFormat('es-CL', { style: 'currency', currency: 'CLP' });
const etiquetaEstado = {
  PENDIENTE: ['Pendiente de confirmación', 'pendiente'],
  CONFIRMADA: ['Confirmada', 'confirmada'],
  COMPLETADA: ['Completada', 'completada'],
  CANCELADA: ['Cancelada', 'cancelada']
};
const etiquetaTorneo = {
  PLANIFICADO: ['Planificado', 'pendiente'], EN_CURSO: ['En curso', 'confirmada'],
  FINALIZADO: ['Finalizado', 'completada'], CANCELADO: ['Cancelado', 'cancelada']
};

function hoyISO() {
  return new Intl.DateTimeFormat('sv-SE', {
    timeZone: 'America/Santiago', year: 'numeric', month: '2-digit', day: '2-digit'
  }).format(new Date());
}

function sumarDias(fecha, dias) {
  const base = new Date(`${fecha}T12:00:00`);
  base.setDate(base.getDate() + dias);
  return base.toISOString().slice(0, 10);
}

function diaSemana(fecha) {
  return (new Date(`${fecha}T12:00:00`).getDay() + 6) % 7 + 1;
}

function fechaLarga(fecha) {
  return new Intl.DateTimeFormat('es-CL', {
    timeZone: 'America/Santiago', weekday: 'long', day: 'numeric', month: 'long'
  }).format(new Date(`${fecha}T12:00:00`));
}

const portal = {
  seccion: 'reservar',
  catalogo: null,
  filtro: null,
  horarios: null,
  seleccion: null,
  cotizacion: null,
  mias: [],
  torneos: [],
  detalle: null,
  plantilla: null,
  confirmarRetiro: null,
  cancelacionReserva: null,
  aviso: null,
  error: null,
  seq: 0
};

const canchaPorId = id => portal.catalogo?.canchas.find(cancha => cancha.id === Number(id));
const recintoDe = cancha => portal.catalogo?.recintos.find(recinto => recinto.id === cancha.recinto);
const recintoPorId = id => portal.catalogo?.recintos.find(recinto => recinto.id === Number(id));
const bloquesDelRecinto = (fecha, recintoId) => {
  const recinto = recintoPorId(recintoId);
  return recinto?.bloques?.[diaSemana(fecha)] || [];
};
const nombreModalidad = id => portal.catalogo?.modalidades.find(modalidad => modalidad.id === Number(id))?.nombre || '';

function modalidadesDisponibles() {
  const usadas = new Set(portal.catalogo.canchas.filter(cancha => cancha.estado === 'DISPONIBLE')
    .flatMap(cancha => cancha.modalidades.map(modalidad => modalidad.id)));
  return portal.catalogo.modalidades.filter(modalidad => usadas.has(modalidad.id));
}

function canchasDeModalidad(modalidadId, recintoId = null) {
  return portal.catalogo.canchas.filter(cancha => cancha.estado === 'DISPONIBLE' &&
    (recintoId === null || cancha.recinto === Number(recintoId)) &&
    cancha.modalidades.some(modalidad => modalidad.id === Number(modalidadId)));
}

function recintosDisponibles() {
  return portal.catalogo.recintos.filter(recinto => recinto.estado === 'ACTIVO' &&
    portal.catalogo.canchas.some(cancha => cancha.recinto === recinto.id && cancha.estado === 'DISPONIBLE'));
}

function estadoReserva(estado) {
  const [texto, clase] = etiquetaEstado[estado] || [estado, 'pendiente'];
  return `<span class="status ${clase}">${esc(texto)}</span>`;
}

function avisoHtml() {
  const partes = [];
  if (portal.aviso) partes.push(`<p class="alert alert-success" role="status">${esc(portal.aviso)}</p>`);
  if (portal.error) partes.push(`<p class="alert alert-danger" role="alert">${esc(portal.error)}</p>`);
  return partes.join('');
}

function pintar() {
  const seccion = location.hash.slice(1) || 'reservar';
  portal.seccion = ['reservar', 'reservas', 'torneos', 'cuenta'].includes(seccion) ? seccion : 'reservar';
  document.querySelectorAll('.site-nav a').forEach(enlace =>
    enlace.classList.toggle('active', enlace.dataset.seccion === portal.seccion));
  const vistas = {
    reservar: vistaReservar,
    reservas: vistaReservas,
    torneos: vistaTorneos,
    cuenta: vistaCuenta
  };
  $vista().innerHTML = avisoHtml() + vistas[portal.seccion]();
  portal.aviso = null;
  portal.error = null;
}

/* ------------------------------------------------------------------ */
/* Reservar                                                           */
/* ------------------------------------------------------------------ */

function vistaReservar() {
  if (!portal.catalogo) return cargando('Leyendo el catálogo del recinto…');
  const recintos = recintosDisponibles();
  const filtro = portal.filtro || (portal.filtro = {
    recinto: recintos[0]?.id ?? '',
    modalidad: modalidadesDisponibles()[0]?.id ?? '',
    fecha: hoyISO(),
    cancha: '',
    hora: ''
  });
  const modalidadesRecinto = modalidadesDisponibles().filter(modalidad =>
    canchasDeModalidad(modalidad.id, filtro.recinto).length);
  if (!modalidadesRecinto.some(modalidad => modalidad.id === Number(filtro.modalidad))) filtro.modalidad = modalidadesRecinto[0]?.id ?? '';
  const canchasFiltradas = canchasDeModalidad(filtro.modalidad, filtro.recinto);
  if (!canchasFiltradas.some(cancha => cancha.id === Number(filtro.cancha))) filtro.cancha = canchasFiltradas[0]?.id ?? '';
  const bloques = bloquesDelRecinto(filtro.fecha, filtro.recinto);
  if (!bloques.some(bloque => bloque.inicio === filtro.hora)) filtro.hora = bloques[0]?.inicio ?? '';
  const opcionesRecinto = recintos.map(recinto =>
    `<option value="${recinto.id}" ${Number(filtro.recinto) === recinto.id ? 'selected' : ''}>${esc(recinto.nombre)}</option>`).join('');
  const modalidades = modalidadesRecinto.map(modalidad =>
    `<option value="${modalidad.id}" ${Number(filtro.modalidad) === modalidad.id ? 'selected' : ''}>${esc(modalidad.nombre)}</option>`).join('');
  const opcionesHora = bloques.map(bloque => `<option value="${bloque.inicio}" ${filtro.hora === bloque.inicio ? 'selected' : ''}>Desde las ${bloque.inicio}</option>`).join('');
  return `<section class="hero hero-photo">
      <div class="hero-copy"><span class="eyebrow"><i class="bi bi-geo-alt-fill" aria-hidden="true"></i> Las Rastras · Talca</span><h1>Tu próximo partido empieza aquí.</h1>
        <p>Encuentra una cancha libre en minutos.</p><span class="hero-feature"><i class="bi bi-car-front-fill" aria-hidden="true"></i> Estacionamiento</span></div>
      <form id="busqueda-form" class="search-panel">
        <h2>Busca tu horario</h2>
        <div class="search-fields">
          <label>Recinto<select class="form-select" name="recinto">${opcionesRecinto}</select></label>
          <label>Qué quieres jugar<select class="form-select" name="modalidad">${modalidades}</select></label>
          <label>Cuándo<input class="form-control" type="date" name="fecha" min="${hoyISO()}" value="${esc(filtro.fecha)}" required></label>
          <label>Hora<select class="form-select" name="hora">${opcionesHora}</select></label>
          <button class="btn btn-success">Ver disponibilidad <i class="bi bi-arrow-right" aria-hidden="true"></i></button>
        </div>
      </form>
    </section>
    ${portal.horarios ? `<div class="split availability-area">
      <section class="surface"><h2>Horarios disponibles</h2>${horariosHtml()}</section>
      <aside class="surface side">${portal.seleccion ? resumenHtml() : `<h2>Tu selección</h2><p class="mb-0">Elige un bloque libre para ver el precio y solicitar la reserva.</p>`}</aside>
    </div>` : ''}`;
}

function horariosHtml() {
  if (!portal.horarios.length) return '<p class="notice mt-3 mb-0">No hay canchas disponibles desde esa hora. Prueba otro horario o fecha.</p>';
  return `<p class="mb-3 text-secondary">${esc(fechaLarga(portal.filtro.fecha))} · ${esc(recintoPorId(portal.filtro.recinto)?.nombre || '')}</p>
    <div class="slot-list">${portal.horarios.map(bloque =>
      `<button type="button" class="surface slot text-start" data-hora="${bloque.hora}" data-cancha="${bloque.cancha}">
          <span class="slot-icon"><i class="bi bi-clock" aria-hidden="true"></i></span>
          <strong>${bloque.hora}–${bloque.termino}</strong>
          <span class="small text-secondary">${esc(canchaPorId(bloque.cancha)?.nombre || '')}</span>
          <span class="status confirmada">Libre</span></button>`
    ).join('')}</div>`;
}

function resumenHtml() {
  const seleccion = portal.seleccion;
  const cancha = canchaPorId(seleccion.cancha);
  const total = portal.cotizacion ? pesos.format(portal.cotizacion.total) : '—';
  return `<h2>Revisa tu reserva</h2>
    <dl class="summary-data">
      <div><i class="bi bi-bullseye" aria-hidden="true"></i><div><dt>Modalidad</dt><dd>${esc(nombreModalidad(seleccion.modalidad))}</dd></div></div>
      <div><i class="bi bi-geo-alt" aria-hidden="true"></i><div><dt>Recinto y cancha</dt><dd>${esc(cancha?.nombre || '')} · ${esc(recintoDe(cancha)?.nombre || '')}</dd></div></div>
      <div><i class="bi bi-calendar3" aria-hidden="true"></i><div><dt>Fecha</dt><dd>${esc(fechaLarga(seleccion.fecha))}</dd></div></div>
      <div><i class="bi bi-clock" aria-hidden="true"></i><div><dt>Horario</dt><dd>${esc(seleccion.hora)}–${esc(portal.horarios?.find(bloque => bloque.hora === seleccion.hora && bloque.cancha === seleccion.cancha)?.termino || '')}</dd></div></div>
    </dl>
    <div class="summary-total"><span>Total</span><strong>${total}</strong></div>
    <p class="small text-secondary mt-2 mb-2">La reserva nace pendiente: el recinto la confirma en recepción.</p>
    <div class="actions"><button type="button" class="btn btn-success" data-solicitar>Solicitar reserva</button></div>`;
}

function cargando(mensaje) {
  return `<p class="notice" role="status"><span class="spinner-border spinner-border-sm" aria-hidden="true"></span> ${esc(mensaje)}</p>`;
}

async function buscarHorarios(form) {
  if (!autenticado) {
    window.location.assign(urlAcceso);
    return;
  }
  const datos = Object.fromEntries(new FormData(form));
  const canchas = canchasDeModalidad(datos.modalidad, datos.recinto);
  portal.filtro = { recinto: Number(datos.recinto), modalidad: Number(datos.modalidad), fecha: datos.fecha,
    cancha: 0, hora: datos.hora };
  portal.seleccion = null;
  portal.cotizacion = null;
  portal.error = null;
  const bloques = bloquesDelRecinto(portal.filtro.fecha, portal.filtro.recinto)
    .filter(bloque => bloque.inicio >= portal.filtro.hora);
  if (!bloques.length || !canchas.length) { portal.horarios = []; return pintar(); }
  $vista().innerHTML = avisoHtml() + cargando('Consultando bloques libres…');
  try {
    const respuestas = await Promise.all(bloques.flatMap(bloque => canchas.map(async cancha => {
      const respuesta = await apiGet('/api/reservas.php', {
        accion: 'disponible', cancha: cancha.id, modalidad: portal.filtro.modalidad,
        fecha: portal.filtro.fecha, hora: bloque.inicio, bloques: 1
      });
      return respuesta.disponible ? { cancha: cancha.id, hora: bloque.inicio, termino: bloque.termino } : null;
    })));
    portal.horarios = respuestas.filter(Boolean).sort((a, b) => a.hora.localeCompare(b.hora) || a.cancha - b.cancha);
  } catch (error) {
    portal.error = error.message;
    portal.horarios = [];
  }
  pintar();
}

async function seleccionarHora(hora, cancha) {
  portal.seleccion = { ...portal.filtro, hora, cancha, bloques: 1 };
  await cotizar();
}

async function cotizar() {
  if (!portal.seleccion) return;
  portal.cotizacion = null;
  portal.error = null;
  pintar();
  try {
    portal.cotizacion = await apiGet('/api/reservas.php', {
      accion: 'cotizar', cancha: portal.seleccion.cancha, modalidad: portal.seleccion.modalidad,
      fecha: portal.seleccion.fecha, hora: portal.seleccion.hora, bloques: portal.seleccion.bloques
    });
  } catch (error) {
    portal.error = error.message;
    portal.seleccion = null;
  }
  pintar();
}

async function solicitarReserva() {
  if (!portal.seleccion) return;
  $vista().innerHTML = avisoHtml() + cargando('Enviando la solicitud…');
  try {
    await apiPost('/api/reservas.php', { accion: 'solicitar' }, {
      cancha: portal.seleccion.cancha, modalidad: portal.seleccion.modalidad,
      fecha: portal.seleccion.fecha, hora: portal.seleccion.hora, bloques: portal.seleccion.bloques
    });
    portal.aviso = 'Solicitud enviada. Queda pendiente de confirmación en el recinto.';
    portal.seleccion = null;
    portal.horarios = null;
    portal.cotizacion = null;
    await cargarMias();
    location.hash = '#reservas';
  } catch (error) {
    portal.error = error.message;
  }
  pintar();
}

/* ------------------------------------------------------------------ */
/* Mis reservas                                                       */
/* ------------------------------------------------------------------ */

async function cargarMias() {
  portal.mias = await apiGet('/api/reservas.php', {
    accion: 'mias', desde: sumarDias(hoyISO(), -180), hasta: sumarDias(hoyISO(), 120)
  });
  // El ID se asigna al crear: descendente equivale a mostrar primero las
  // solicitudes más recientes, independiente de la fecha en que se jugarán.
  portal.mias.sort((a, b) => Number(b.id) - Number(a.id));
  return portal.mias;
}

async function cancelarMiReserva(id) {
  try {
    await apiPost('/api/reservas.php', { accion: 'cancelar' }, { id });
    portal.cancelacionReserva = null;
    portal.aviso = 'Solicitud cancelada. El horario volvió a quedar disponible.';
    await cargarMias();
  } catch (error) {
    portal.error = error.message;
  }
  pintar();
}

function vistaReservas() {
  if (!portal.mias.length) {
    return `<h1 class="h2">Mis reservas</h1><div class="surface empty"><span class="sport-symbol"><i class="bi bi-ticket-perforated" aria-hidden="true"></i></span>
      <p>Todavía no tienes reservas. <a href="#reservar">Busca un horario</a> para comenzar.</p></div>`;
  }
  const filas = portal.mias.map(reserva => {
    const inicio = String(reserva.inicio).split(' ');
    const termino = String(reserva.termino).split(' ');
    const acciones = reserva.estado !== 'PENDIENTE'
      ? '<span class="text-secondary small">—</span>'
      : portal.cancelacionReserva === reserva.id
        ? `<div class="actions"><button type="button" class="btn btn-outline-danger btn-sm" data-confirmar-cancelacion="${reserva.id}">Sí, cancelar</button><button type="button" class="btn btn-light border btn-sm" data-descartar-cancelacion>Volver</button></div>`
        : `<button type="button" class="btn btn-outline-danger btn-sm" data-preparar-cancelacion="${reserva.id}">Cancelar</button>`;
    return `<tr>
      <td>${esc(inicio[0])}</td>
      <td>${esc(inicio[1]?.slice(0, 5))}–${esc(termino[1]?.slice(0, 5))}</td>
      <td>${esc(reserva.cancha.nombre)}</td>
      <td>${esc(reserva.modalidad.nombre)}</td>
      <td>${estadoReserva(reserva.estado)}</td>
      <td>${pesos.format(reserva.importe)}</td><td>${acciones}</td></tr>`;
  }).join('');
  return `<div class="page-heading"><div><h1 class="h2">Mis reservas</h1><p>Solo se muestran tus reservas en este recinto.</p></div>
      <a class="btn btn-outline-success" href="#reservar">Nueva reserva</a></div>
    <div class="surface table-responsive"><table class="table align-middle mb-0">
      <thead><tr><th>Fecha</th><th>Horario</th><th>Cancha</th><th>Modalidad</th><th>Estado</th><th>Importe</th><th>Acciones</th></tr></thead>
      <tbody>${filas}</tbody></table></div>`;
}

/* ------------------------------------------------------------------ */
/* Torneos                                                            */
/* ------------------------------------------------------------------ */

async function cargarTorneos() {
  portal.torneos = await apiGet('/api/torneos.php', { accion: 'torneos' });
  return portal.torneos;
}

function vistaTorneos() {
  if (!portal.torneos.length) return `<h1 class="h2">Torneos</h1><p class="empty">No hay torneos publicados por ahora.</p>`;
  return `<div class="page-heading"><div><h1 class="h2">Torneos</h1><p>Inscribe un equipo con su plantilla completa.</p></div></div>
    <div class="tournament-grid">${portal.torneos.map(torneo => {
      const [texto, clase] = etiquetaTorneo[torneo.estado] || [torneo.estado, 'pendiente'];
      const cupos = torneo.cupos - torneo.inscritos;
      const abierto = torneo.estado === 'PLANIFICADO';
      return `<article class="surface tournament-tile">
        <div class="d-flex justify-content-between gap-2"><h2 class="fs-5 mb-0">${esc(torneo.nombre)}</h2><span class="status ${clase}">${esc(texto)}</span></div>
        <p class="small mb-0">${esc(torneo.modalidad.nombre)} · ${esc(torneo.inicio)} al ${esc(torneo.termino)}</p>
        <p class="small mb-0">${torneo.inscritos} de ${torneo.cupos} equipos · ${torneo.minimo}–${torneo.maximo} jugadores por equipo</p>
        ${torneo.mi_inscripcion
          ? `<div class="actions"><span class="status confirmada">Estás inscrito</span>
              <button type="button" class="btn btn-outline-success btn-sm" data-detalle="${torneo.mi_inscripcion}">Ver mi plantilla</button></div>`
          : abierto && cupos > 0
            ? `<button type="button" class="btn btn-success btn-sm" data-preparar-inscripcion="${torneo.id}">Preparar inscripción</button>`
            : `<p class="small mb-0">${cupos > 0 ? 'Inscripciones cerradas' : 'Cupos completos'}</p>`}
      </article>`;
    }).join('')}</div>
    ${portal.plantilla ? plantillaInscripcionHtml() : ''}
    ${portal.detalle ? detalleInscripcionHtml() : ''}`;
}

function crearBorradorPlantilla(torneo, detalle = null) {
  const companeros = detalle ? detalle.jugadores.filter(jugador => !jugador.capitan) : [];
  const cuposCompaneros = Math.max(0, torneo.maximo - 1);
  return {
    modo: detalle ? 'editar' : 'crear',
    torneo,
    inscripcion: detalle?.id ?? null,
    capitan: detalle?.capitan?.nombre || 'Tú (capitán)',
    equipo: detalle?.equipo || '',
    jugadores: Array.from({ length: cuposCompaneros }, (_, indice) => companeros[indice] || { nombre: '', rut: '' }),
    revisar: false
  };
}

function plantillaInscripcionHtml() {
  const plantilla = portal.plantilla;
  const titulo = plantilla.modo === 'crear' ? 'Completa la inscripción' : 'Editar plantilla';
  const obligatorios = Math.max(0, plantilla.torneo.minimo - 1);
  const jugadores = plantilla.jugadores.map((jugador, indice) => `<div class="row g-2 align-items-end mb-2">
      <div class="col-12 col-md-6"><label class="form-label mb-1" for="jugador-nombre-${indice}">Integrante ${indice + 2}: nombre completo${indice >= obligatorios ? ' (suplente opcional)' : ''}</label>
        <input id="jugador-nombre-${indice}" class="form-control" name="nombre-${indice}" maxlength="100" value="${esc(jugador.nombre)}" ${indice < obligatorios ? 'required' : ''}></div>
      <div class="col-12 col-md-6"><label class="form-label mb-1" for="jugador-rut-${indice}">RUT</label>
        <input id="jugador-rut-${indice}" class="form-control" name="rut-${indice}" maxlength="12" placeholder="12.345.678-9" value="${esc(jugador.rut)}" ${indice < obligatorios ? 'required' : ''}></div>
    </div>`).join('');
  if (plantilla.revisar) {
    return `<section class="surface mt-3" id="confirmar-inscripcion">
      <h2 class="fs-4">Confirma tu inscripción</h2>
      <p class="mb-2">Revisa los datos antes de ocupar un cupo en <strong>${esc(plantilla.torneo.nombre)}</strong>.</p>
      <dl class="summary-data mb-3">
        <div><i class="bi bi-people" aria-hidden="true"></i><div><dt>Equipo</dt><dd>${esc(plantilla.equipo)}</dd></div></div>
        <div><i class="bi bi-person-badge" aria-hidden="true"></i><div><dt>Capitán</dt><dd>${esc(plantilla.capitan)}</dd></div></div>
      </dl>
      <ul class="list-group tournament-roster mb-3">${plantilla.jugadores.filter(jugador => jugador.nombre || jugador.rut).map((jugador, indice) =>
        `<li class="list-group-item d-flex justify-content-between gap-2"><span>${indice + 2}. ${esc(jugador.nombre)}</span><small>${esc(jugador.rut)}</small></li>`).join('')}</ul>
      <div class="actions"><button type="button" class="btn btn-outline-secondary" data-volver-plantilla>Volver a editar</button>
        <button type="button" class="btn btn-success" data-confirmar-inscripcion>Confirmar inscripción</button></div>
    </section>`;
  }
  return `<section class="surface mt-3" id="plantilla-inscripcion">
    <h2 class="fs-4">${titulo}</h2>
    <p class="mb-3">El capitán es la cuenta con la que iniciaste sesión. Este torneo requiere entre ${plantilla.torneo.minimo} y ${plantilla.torneo.maximo} jugadores; los cupos adicionales son suplentes opcionales.</p>
    <form data-plantilla-inscripcion>
      <div class="row g-2 align-items-end mb-3"><div class="col-12 col-md-6"><label class="form-label" for="nombre-equipo">Nombre del equipo</label>
        <input id="nombre-equipo" class="form-control" name="equipo" maxlength="100" value="${esc(plantilla.equipo)}" required></div>
        <div class="col-12 col-md-6"><label class="form-label">Capitán</label><div class="form-control bg-light">${esc(plantilla.capitan)}</div></div></div>
      ${jugadores || '<p class="notice">Este torneo es individual: tú completas la plantilla.</p>'}
      <div class="actions mt-3"><button type="button" class="btn btn-outline-secondary" data-cancelar-plantilla>Cancelar</button>
        <button class="btn btn-success">Revisar inscripción</button></div>
    </form>
  </section>`;
}

function detalleInscripcionHtml() {
  const detalle = portal.detalle;
  const jugadores = detalle.jugadores.length
    ? `<ul class="list-group tournament-roster">${detalle.jugadores.map(jugador =>
        `<li class="list-group-item d-flex justify-content-between"><span>${esc(jugador.nombre)}${jugador.capitan ? ' <span class="status confirmada">Capitán</span>' : ''}</span><small>${esc(jugador.rut)}</small></li>`).join('')}</ul>`
    : '<p class="small mb-0">La plantilla está vacía.</p>';
  return `<section class="surface mt-3" id="detalle-inscripcion">
    <div class="d-flex flex-wrap justify-content-between gap-2 mb-2">
      <div><h2 class="fs-5 mb-0">${esc(detalle.equipo)}</h2>
        <p class="small mb-0">${esc(detalle.torneo.nombre)} · capitán ${esc(detalle.capitan.nombre)} · ${detalle.cantidad} de ${detalle.maximo} jugadores</p></div>
      <div class="actions">
        ${detalle.estado === 'INSCRITO' ? `<button type="button" class="btn btn-outline-success btn-sm" data-editar-plantilla="${detalle.id}">Editar plantilla</button>
          <button type="button" class="btn btn-outline-danger btn-sm withdraw-team" data-retirar="${detalle.id}">Retirar equipo</button>` : '<span class="status cancelada">Retirado</span>'}
      </div></div>
    ${jugadores}
    ${detalle.estado === 'INSCRITO' ? `<p class="small text-secondary mt-2 mb-0">La plantilla se modifica completa para evitar equipos incompletos.</p>` : ''}
    ${portal.confirmarRetiro === detalle.id ? `<div class="alert alert-danger mt-3 mb-0 d-flex flex-wrap align-items-center gap-2">
        <span>¿Retirar el equipo del torneo?</span>
        <button type="button" class="btn btn-danger btn-sm" data-confirmar-retiro="${detalle.id}">Sí, retirar</button>
        <button type="button" class="btn btn-light border btn-sm" data-cancelar-retiro>Cancelar</button></div>` : ''}
  </section>`;
}

/* ------------------------------------------------------------------ */
/* Cuenta                                                             */
/* ------------------------------------------------------------------ */

function vistaCuenta() {
  const nombre = document.body.dataset.clienteNombre || '';
  return `<div class="split access-split">
    <section class="surface">
      <h1 class="h2">Mi cuenta</h1>
      <dl class="summary-data">
        <div><i class="bi bi-person" aria-hidden="true"></i><div><dt>Cliente</dt><dd>${esc(nombre)}</dd></div></div>
        <div><i class="bi bi-hash" aria-hidden="true"></i><div><dt>Ficha</dt><dd>#${clienteId}</dd></div></div>
      </dl>
      <form method="post" action="/cliente/logout.php" class="mt-3">
        <input type="hidden" name="csrf" value="${esc(apiCsrf())}">
        <button class="btn btn-outline-danger">Cerrar sesión</button>
      </form>
    </section>
    <aside class="surface side">
      <h2>¿Necesitas cambiar tus datos?</h2>
      <p class="mb-0">El nombre, teléfono y correo de la ficha los actualiza el personal del recinto en recepción.</p>
    </aside>
  </div>`;
}

/* ------------------------------------------------------------------ */
/* Eventos                                                            */
/* ------------------------------------------------------------------ */

document.addEventListener('change', event => {
  if (event.target.closest('#busqueda-form')) {
    const datos = Object.fromEntries(new FormData(event.target.form));
    portal.filtro = { recinto: Number(datos.recinto), modalidad: Number(datos.modalidad), fecha: datos.fecha,
      cancha: Number(datos.cancha || 0), hora: datos.hora || '' };
    portal.horarios = null;
    return pintar();
  }
});

document.addEventListener('submit', async event => {
  const form = event.target;
  if (form.id === 'busqueda-form') { event.preventDefault(); return buscarHorarios(form); }

  if (form.dataset.plantillaInscripcion !== undefined) {
    event.preventDefault();
    const plantilla = portal.plantilla;
    if (!plantilla) return;
    portal.plantilla = {
      ...plantilla,
      equipo: form.elements.equipo.value.trim(),
      jugadores: plantilla.jugadores.map((_, indice) => ({
        nombre: form.elements[`nombre-${indice}`].value.trim(),
        rut: form.elements[`rut-${indice}`].value.trim()
      })),
      revisar: true
    };
    return pintar();
  }
});

document.addEventListener('click', async event => {
  const boton = event.target.closest('[data-hora], [data-solicitar], [data-detalle], [data-preparar-inscripcion], [data-editar-plantilla], [data-cancelar-plantilla], [data-volver-plantilla], [data-confirmar-inscripcion], [data-retirar], [data-confirmar-retiro], [data-cancelar-retiro], [data-preparar-cancelacion], [data-confirmar-cancelacion], [data-descartar-cancelacion]');
  if (!boton) return;
  if (boton.dataset.hora !== undefined) return seleccionarHora(boton.dataset.hora, Number(boton.dataset.cancha));
  if (boton.dataset.solicitar !== undefined) return solicitarReserva();
  if (boton.dataset.prepararCancelacion !== undefined) {
    portal.cancelacionReserva = Number(boton.dataset.prepararCancelacion);
    return pintar();
  }
  if (boton.dataset.descartarCancelacion !== undefined) {
    portal.cancelacionReserva = null;
    return pintar();
  }
  if (boton.dataset.confirmarCancelacion !== undefined) return cancelarMiReserva(Number(boton.dataset.confirmarCancelacion));
  if (boton.dataset.prepararInscripcion !== undefined) {
    const torneo = portal.torneos.find(item => item.id === Number(boton.dataset.prepararInscripcion));
    if (torneo) {
      portal.detalle = null;
      portal.plantilla = crearBorradorPlantilla(torneo);
    }
    return pintar();
  }
  if (boton.dataset.editarPlantilla !== undefined) {
    try {
      const detalle = await apiGet('/api/torneos.php', { accion: 'detalle', id: Number(boton.dataset.editarPlantilla) });
      const torneo = portal.torneos.find(item => item.id === detalle.torneo.id);
      if (!torneo) throw new Error('No se encontró el torneo de esta inscripción.');
      portal.detalle = detalle;
      portal.plantilla = crearBorradorPlantilla(torneo, detalle);
    } catch (error) { portal.error = error.message; }
    return pintar();
  }
  if (boton.dataset.cancelarPlantilla !== undefined) {
    portal.plantilla = null;
    return pintar();
  }
  if (boton.dataset.volverPlantilla !== undefined) {
    if (portal.plantilla) portal.plantilla.revisar = false;
    return pintar();
  }
  if (boton.dataset.confirmarInscripcion !== undefined) {
    const plantilla = portal.plantilla;
    if (!plantilla) return;
    try {
      if (plantilla.modo === 'crear') {
        const respuesta = await apiPost('/api/torneos.php', { accion: 'inscribir' }, {
          torneo: plantilla.torneo.id, equipo: plantilla.equipo, jugadores: plantilla.jugadores
        });
        portal.detalle = await apiGet('/api/torneos.php', { accion: 'detalle', id: respuesta.id });
        portal.aviso = 'Equipo inscrito con la plantilla completa.';
      } else {
        portal.detalle = await apiPost('/api/torneos.php', { accion: 'actualizar' }, {
          inscripcion: plantilla.inscripcion, equipo: plantilla.equipo, jugadores: plantilla.jugadores
        });
        portal.aviso = 'Plantilla actualizada.';
      }
      portal.plantilla = null;
      await cargarTorneos();
    } catch (error) { portal.error = error.message; }
    return pintar();
  }
  if (boton.dataset.detalle !== undefined) {
    try {
      portal.detalle = await apiGet('/api/torneos.php', { accion: 'detalle', id: Number(boton.dataset.detalle) });
      portal.confirmarRetiro = null;
    } catch (error) { portal.error = error.message; }
    return pintar();
  }
  if (boton.dataset.retirar !== undefined) { portal.confirmarRetiro = Number(boton.dataset.retirar); return pintar(); }
  if (boton.dataset.cancelarRetiro !== undefined) { portal.confirmarRetiro = null; return pintar(); }
  if (boton.dataset.confirmarRetiro !== undefined) {
    try {
      await apiPost('/api/torneos.php', { accion: 'retirar' }, { inscripcion: Number(boton.dataset.confirmarRetiro) });
      portal.aviso = 'Equipo retirado del torneo.';
      portal.confirmarRetiro = null;
      portal.detalle = null;
      await cargarTorneos();
    } catch (error) { portal.error = error.message; }
    return pintar();
  }
});

window.addEventListener('hashchange', () => cargarSeccion());

async function cargarSeccion() {
  const seccion = location.hash.slice(1) || 'reservar';
  portal.error = null;
  if (!autenticado && ['reservas', 'torneos', 'cuenta'].includes(seccion)) {
    window.location.assign(urlAcceso);
    return;
  }
  if (seccion === 'reservas') {
    $vista().innerHTML = cargando('Leyendo tus reservas…');
    try { await cargarMias(); } catch (error) { portal.error = error.message; }
  }
  if (seccion === 'torneos') {
    $vista().innerHTML = cargando('Leyendo los torneos…');
    try { await cargarTorneos(); } catch (error) { portal.error = error.message; portal.torneos = []; }
  }
  if (seccion === 'reservar' && !portal.catalogo) {
    $vista().innerHTML = cargando('Leyendo el catálogo del recinto…');
    try { portal.catalogo = await apiGet('/api/catalogo.php'); } catch (error) { portal.error = error.message; }
  }
  pintar();
}

(async function iniciar() {
  try {
    portal.catalogo = await apiGet('/api/catalogo.php');
  } catch (error) {
    portal.error = error.message;
  }
  await cargarSeccion();
})();
