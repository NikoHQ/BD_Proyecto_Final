'use strict';

const $vista = () => document.getElementById('vista');
const clienteId = Number(document.body.dataset.cliente);
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
  confirmarRetiro: null,
  aviso: null,
  error: null,
  seq: 0
};

const canchaPorId = id => portal.catalogo?.canchas.find(cancha => cancha.id === Number(id));
const recintoDe = cancha => portal.catalogo?.recintos.find(recinto => recinto.id === cancha.recinto);
const horarioDe = fecha => {
  const recinto = portal.catalogo?.recintos[0];
  return recinto?.horarios?.[diaSemana(fecha)] || null;
};
const nombreModalidad = id => portal.catalogo?.modalidades.find(modalidad => modalidad.id === Number(id))?.nombre || '';

function modalidadesDisponibles() {
  const usadas = new Set(portal.catalogo.canchas.filter(cancha => cancha.estado === 'DISPONIBLE')
    .flatMap(cancha => cancha.modalidades.map(modalidad => modalidad.id)));
  return portal.catalogo.modalidades.filter(modalidad => usadas.has(modalidad.id));
}

function canchasDeModalidad(modalidadId) {
  return portal.catalogo.canchas.filter(cancha => cancha.estado === 'DISPONIBLE' &&
    cancha.modalidades.some(modalidad => modalidad.id === Number(modalidadId)));
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
  const filtro = portal.filtro || (portal.filtro = {
    modalidad: modalidadesDisponibles()[0]?.id ?? '',
    fecha: hoyISO(),
    cancha: ''
  });
  const modalidades = modalidadesDisponibles().map(modalidad =>
    `<option value="${modalidad.id}" ${Number(filtro.modalidad) === modalidad.id ? 'selected' : ''}>${esc(modalidad.nombre)}</option>`).join('');
  const canchas = canchasDeModalidad(filtro.modalidad).map(cancha =>
    `<option value="${cancha.id}" ${Number(filtro.cancha) === cancha.id ? 'selected' : ''}>${esc(cancha.nombre)}</option>`).join('');
  return `<section class="hero">
      <div><span class="eyebrow">Recinto Las Rastras</span><h1>Reserva tu cancha</h1>
        <p>Elige modalidad, día y hora. La solicitud queda pendiente hasta que el recinto la confirme.</p></div>
      <img class="court-art" src="/cliente/centro-deportivo.svg" alt="">
    </section>
    <div class="split">
      <section class="surface">
        <h2>Buscar disponibilidad</h2>
        <form id="busqueda-form" class="row g-3">
          <div class="col-12 col-md-4"><label class="form-label">Modalidad<select class="form-select" name="modalidad">${modalidades}</select></label></div>
          <div class="col-12 col-md-4"><label class="form-label">Fecha<input class="form-control" type="date" name="fecha" min="${hoyISO()}" value="${esc(filtro.fecha)}" required></label></div>
          <div class="col-12 col-md-4"><label class="form-label">Cancha<select class="form-select" name="cancha">${canchas}</select></label></div>
          <div class="col-12"><button class="btn btn-success">Buscar horarios</button></div>
        </form>
        ${portal.horarios ? horariosHtml() : '<p class="notice mt-3 mb-0"><i class="bi bi-info-circle" aria-hidden="true"></i> La búsqueda muestra solo los bloques libres del día elegido.</p>'}
      </section>
      <aside class="surface side">${portal.seleccion ? resumenHtml() : `<h2>Tu selección</h2><p class="mb-0">Elige un bloque libre para ver el precio y solicitar la reserva.</p>`}</aside>
    </div>`;
}

function horariosHtml() {
  if (!portal.horarios.length) return '<p class="notice mt-3 mb-0">El recinto está cerrado ese día. Prueba otra fecha.</p>';
  return `<h3 class="fs-5 mt-4">Horarios del ${esc(fechaLarga(portal.filtro.fecha))}</h3>
    <div class="slot-list">${portal.horarios.map(bloque => bloque.libre
      ? `<button type="button" class="surface slot text-start" data-hora="${bloque.hora}">
          <span class="slot-icon"><i class="bi bi-clock" aria-hidden="true"></i></span>
          <strong>${bloque.hora}–${bloque.termino}</strong>
          <span class="small text-secondary">${esc(canchaPorId(portal.filtro.cancha)?.nombre || '')}</span>
          <span class="status confirmada">Libre</span></button>`
      : `<div class="surface slot opacity-75">
          <span class="slot-icon"><i class="bi bi-clock-history" aria-hidden="true"></i></span>
          <strong>${bloque.hora}–${bloque.termino}</strong>
          <span class="small text-secondary">${esc(canchaPorId(portal.filtro.cancha)?.nombre || '')}</span>
          <span class="status cancelada">Ocupado</span></div>`).join('')}</div>`;
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
      <div><i class="bi bi-clock" aria-hidden="true"></i><div><dt>Horario</dt><dd>${esc(seleccion.hora)} · ${seleccion.bloques} ${seleccion.bloques === 1 ? 'bloque' : 'bloques'}</dd></div></div>
    </dl>
    <label class="form-label mt-2">Bloques<input class="form-control" type="number" min="1" max="4" value="${seleccion.bloques}" data-bloques></label>
    <div class="summary-total"><span>Total</span><strong>${total}</strong></div>
    <p class="small text-secondary mt-2 mb-2">La reserva nace pendiente: el recinto la confirma en recepción.</p>
    <div class="actions"><button type="button" class="btn btn-success" data-solicitar>Solicitar reserva</button></div>`;
}

function cargando(mensaje) {
  return `<p class="notice" role="status"><span class="spinner-border spinner-border-sm" aria-hidden="true"></span> ${esc(mensaje)}</p>`;
}

async function buscarHorarios(form) {
  const datos = Object.fromEntries(new FormData(form));
  portal.filtro = { modalidad: Number(datos.modalidad), fecha: datos.fecha, cancha: Number(datos.cancha) };
  portal.seleccion = null;
  portal.cotizacion = null;
  portal.error = null;
  const ventana = horarioDe(portal.filtro.fecha);
  if (!ventana) { portal.horarios = []; return pintar(); }
  const [apertura, cierre] = ventana;
  const horas = [];
  for (let hora = Number(apertura.slice(0, 2)); hora < Number(cierre.slice(0, 2)); hora++) {
    horas.push(`${String(hora).padStart(2, '0')}:00`);
  }
  $vista().innerHTML = avisoHtml() + cargando('Consultando bloques libres…');
  try {
    portal.horarios = await Promise.all(horas.map(async hora => {
      const respuesta = await apiGet('/api/reservas.php', {
        accion: 'disponible', cancha: portal.filtro.cancha, modalidad: portal.filtro.modalidad,
        fecha: portal.filtro.fecha, hora, bloques: 1
      });
      return { hora, termino: `${String(Number(hora.slice(0, 2)) + 1).padStart(2, '0')}:00`, libre: Boolean(respuesta.disponible) };
    }));
  } catch (error) {
    portal.error = error.message;
    portal.horarios = [];
  }
  pintar();
}

async function seleccionarHora(hora) {
  portal.seleccion = { ...portal.filtro, hora, bloques: 1 };
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
  return portal.mias;
}

function vistaReservas() {
  if (!portal.mias.length) {
    return `<h1 class="h2">Mis reservas</h1><div class="surface empty"><span class="sport-symbol"><i class="bi bi-ticket-perforated" aria-hidden="true"></i></span>
      <p>Todavía no tienes reservas. <a href="#reservar">Busca un horario</a> para comenzar.</p></div>`;
  }
  const filas = portal.mias.map(reserva => {
    const inicio = String(reserva.inicio).split(' ');
    const termino = String(reserva.termino).split(' ');
    return `<tr>
      <td>${esc(inicio[0])}</td>
      <td>${esc(inicio[1]?.slice(0, 5))}–${esc(termino[1]?.slice(0, 5))}</td>
      <td>${esc(reserva.cancha.nombre)}</td>
      <td>${esc(reserva.modalidad.nombre)}</td>
      <td>${estadoReserva(reserva.estado)}</td>
      <td>${pesos.format(reserva.importe)}</td></tr>`;
  }).join('');
  return `<div class="page-heading"><div><h1 class="h2">Mis reservas</h1><p>Solo se muestran tus reservas en este recinto.</p></div>
      <a class="btn btn-outline-success" href="#reservar">Nueva reserva</a></div>
    <div class="surface table-responsive"><table class="table align-middle mb-0">
      <thead><tr><th>Fecha</th><th>Horario</th><th>Cancha</th><th>Modalidad</th><th>Estado</th><th>Importe</th></tr></thead>
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
  return `<div class="page-heading"><div><h1 class="h2">Torneos</h1><p>Inscribe tu equipo y completa la plantilla.</p></div></div>
    <div class="tournament-grid">${portal.torneos.map(torneo => {
      const [texto, clase] = etiquetaTorneo[torneo.estado] || [torneo.estado, 'pendiente'];
      const cupos = torneo.cupos - torneo.inscritos;
      const abierto = torneo.estado === 'PLANIFICADO' || torneo.estado === 'EN_CURSO';
      return `<article class="surface tournament-tile">
        <div class="d-flex justify-content-between gap-2"><h2 class="fs-5 mb-0">${esc(torneo.nombre)}</h2><span class="status ${clase}">${esc(texto)}</span></div>
        <p class="small mb-0">${esc(torneo.modalidad.nombre)} · ${esc(torneo.inicio)} al ${esc(torneo.termino)}</p>
        <p class="small mb-0">${torneo.inscritos} de ${torneo.cupos} equipos · máximo ${torneo.maximo} por equipo</p>
        ${torneo.mi_inscripcion
          ? `<div class="actions"><span class="status confirmada">Estás inscrito</span>
              <button type="button" class="btn btn-outline-success btn-sm" data-detalle="${torneo.mi_inscripcion}">Ver mi plantilla</button></div>`
          : abierto && cupos > 0
            ? `<form class="d-flex gap-2" data-inscribir="${torneo.id}">
                <input class="form-control form-control-sm" name="equipo" placeholder="Nombre del equipo" maxlength="100" required>
                <button class="btn btn-success btn-sm text-nowrap">Inscribir</button></form>`
            : `<p class="small mb-0">${cupos > 0 ? 'Inscripciones cerradas' : 'Cupos completos'}</p>`}
      </article>`;
    }).join('')}</div>
    ${portal.detalle ? detalleInscripcionHtml() : ''}`;
}

function detalleInscripcionHtml() {
  const detalle = portal.detalle;
  const jugadores = detalle.jugadores.length
    ? `<ul class="list-group tournament-roster">${detalle.jugadores.map(jugador =>
        `<li class="list-group-item d-flex justify-content-between"><span>${esc(jugador.nombre)}</span><small>${esc(jugador.rut)}</small></li>`).join('')}</ul>`
    : '<p class="small mb-0">La plantilla está vacía.</p>';
  const completo = detalle.cantidad >= detalle.maximo;
  return `<section class="surface mt-3" id="detalle-inscripcion">
    <div class="d-flex flex-wrap justify-content-between gap-2 mb-2">
      <div><h2 class="fs-5 mb-0">${esc(detalle.equipo)}</h2>
        <p class="small mb-0">${esc(detalle.torneo.nombre)} · capitán ${esc(detalle.capitan.nombre)} · ${detalle.cantidad} de ${detalle.maximo} jugadores</p></div>
      <div class="actions">
        ${detalle.estado === 'INSCRITO' ? `<button type="button" class="btn btn-outline-danger btn-sm withdraw-team" data-retirar="${detalle.id}">Retirar equipo</button>` : '<span class="status cancelada">Retirado</span>'}
      </div></div>
    ${jugadores}
    ${detalle.estado === 'INSCRITO' && !completo ? `<form class="row g-2 mt-2" data-jugador="${detalle.id}">
        <div class="col-12 col-md-5"><input class="form-control" name="nombre" placeholder="Nombre del jugador" maxlength="100" required></div>
        <div class="col-12 col-md-4"><input class="form-control" name="rut" placeholder="RUT con DV" maxlength="12" required></div>
        <div class="col-12 col-md-3"><button class="btn btn-success w-100">Agregar jugador</button></div></form>`
      : completo && detalle.estado === 'INSCRITO' ? '<p class="small text-secondary mt-2 mb-0">La plantilla llegó al máximo del torneo.</p>' : ''}
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
  if (event.target.closest('#busqueda-form') && event.target.name === 'modalidad') {
    const canchas = canchasDeModalidad(event.target.value);
    const select = event.target.form.elements.cancha;
    select.innerHTML = canchas.map(cancha => `<option value="${cancha.id}">${esc(cancha.nombre)}</option>`).join('');
    return;
  }
  if (event.target.matches('[data-bloques]') && portal.seleccion) {
    portal.seleccion.bloques = Math.max(1, Math.min(4, Number(event.target.value) || 1));
    return cotizar();
  }
});

document.addEventListener('submit', async event => {
  const form = event.target;
  if (form.id === 'busqueda-form') { event.preventDefault(); return buscarHorarios(form); }

  if (form.dataset.inscribir) {
    event.preventDefault();
    const torneo = Number(form.dataset.inscribir);
    try {
      await apiPost('/api/torneos.php', { accion: 'inscribir' }, { torneo, equipo: form.elements.equipo.value.trim() });
      portal.aviso = 'Equipo inscrito en el torneo.';
      await cargarTorneos();
    } catch (error) { portal.error = error.message; }
    return pintar();
  }

  if (form.dataset.jugador) {
    event.preventDefault();
    try {
      await apiPost('/api/torneos.php', { accion: 'agregar' }, {
        inscripcion: Number(form.dataset.jugador), rut: form.elements.rut.value.trim(), nombre: form.elements.nombre.value.trim()
      });
      portal.aviso = 'Jugador agregado a la plantilla.';
      portal.detalle = await apiGet('/api/torneos.php', { accion: 'detalle', id: Number(form.dataset.jugador) });
    } catch (error) { portal.error = error.message; }
    return pintar();
  }
});

document.addEventListener('click', async event => {
  const boton = event.target.closest('[data-hora], [data-solicitar], [data-detalle], [data-retirar], [data-confirmar-retiro], [data-cancelar-retiro]');
  if (!boton) return;
  if (boton.dataset.hora !== undefined) return seleccionarHora(boton.dataset.hora);
  if (boton.dataset.solicitar !== undefined) return solicitarReserva();
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
