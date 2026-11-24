'use strict';

/**
 * Estado real del panel. El catalogo se lee una vez y la agenda se pide por
 * rango; todo lo demas (tarifas, solapes, estados) lo decide Oracle.
 */
const panel = {
  recintos: [],
  canchas: [],
  modalidades: [],
  componentes: [],
  reservas: new Map(),
  torneos: [],
  rango: null,
  catalogoCargado: false
};

const reservaEstado = {
  PENDIENTE: 'pending', CONFIRMADA: 'confirmed', COMPLETADA: 'completed', CANCELADA: 'cancelled'
};
const reservaOrigen = { MOSTRADOR: 'Mostrador', WEB: 'Web', TORNEO: 'Torneo' };
const estadoReservaApi = Object.fromEntries(Object.entries(reservaEstado).map(([api, ui]) => [ui, api]));
const origenReservaApi = Object.fromEntries(Object.entries(reservaOrigen).map(([api, ui]) => [ui, api]));

/** 'YYYY-MM-DD HH24:MI:SS' -> partes separadas. */
function partesFecha(valor) {
  const texto = String(valor || '');
  const [fecha = '', hora = ''] = texto.split(' ');
  return { fecha, hora: hora.slice(0, 5) };
}

function normalizarReserva(fila) {
  const inicio = partesFecha(fila.inicio);
  const termino = partesFecha(fila.termino);
  return {
    id: Number(fila.id),
    canchaId: Number(fila.cancha.id),
    cancha: fila.cancha.nombre,
    modalidadId: Number(fila.modalidad.id),
    modalidad: fila.modalidad.nombre,
    clienteId: fila.cliente.id === null ? null : Number(fila.cliente.id),
    cliente: fila.cliente.nombre || fila.torneo.nombre || 'Bloque de torneo',
    torneoId: fila.torneo.id === null ? null : Number(fila.torneo.id),
    torneo: fila.torneo.nombre,
    origen: reservaOrigen[fila.origen] || fila.origen,
    estadoApi: fila.estado,
    estado: reservaEstado[fila.estado] || 'pending',
    importe: Number(fila.importe),
    fecha: inicio.fecha,
    start: inicio.hora,
    end: termino.hora,
    finFecha: termino.fecha
  };
}

const canchaPorId = id => panel.canchas.find(cancha => cancha.id === Number(id));
const recintoPorId = id => panel.recintos.find(recinto => recinto.id === Number(id));
const modalidadPorId = id => panel.modalidades.find(modalidad => modalidad.id === Number(id));
const recintoDeCancha = cancha => recintoPorId(canchaPorId(cancha)?.recinto);
const horarioDe = (recintoId, dia) => recintoPorId(recintoId)?.horarios?.[dia] || null;
const nombreRecinto = id => recintoPorId(id)?.nombre || '';

/** La cancha grande ocupa sus componentes: sus bloques se cruzan. */
function compartenEspacio(a, b) {
  return a === b || panel.componentes.some(par =>
    (par.grande === a && par.pequena === b) || (par.grande === b && par.pequena === a));
}

function canchaDisponible(id) {
  const cancha = canchaPorId(id);
  if (!cancha || cancha.estado !== 'DISPONIBLE') return false;
  const recinto = recintoPorId(cancha.recinto);
  if (!recinto || recinto.estado !== 'ACTIVO') return false;
  return panel.componentes.every(par => par.grande !== cancha.id || canchaPorId(par.pequena)?.estado === 'DISPONIBLE');
}

const reservasPanel = () => [...panel.reservas.values()];
const reservaPorId = id => panel.reservas.get(Number(id));
const diaSemanaIso = fecha => (new Date(`${fecha}T12:00:00`).getDay() + 6) % 7 + 1;

async function cargarCatalogo() {
  if (panel.catalogoCargado) return;
  const datos = await apiGet('/dashboardadmin/api/catalogo.php');
  panel.recintos = datos.recintos;
  panel.canchas = datos.canchas;
  panel.modalidades = datos.modalidades;
  panel.componentes = datos.componentes;
  panel.catalogoCargado = true;
}

async function cargarAgenda(desde, hasta, { forzar = false } = {}) {
  const cubierto = panel.rango && panel.rango.desde <= desde && panel.rango.hasta >= hasta;
  if (!forzar && cubierto) return;
  const filas = await apiGet('/dashboardadmin/api/reservas.php', { accion: 'agenda', desde, hasta });
  for (const fila of filas) {
    const reserva = normalizarReserva(fila);
    panel.reservas.set(reserva.id, reserva);
  }
  panel.rango = panel.rango && !forzar
    ? { desde: minFecha(panel.rango.desde, desde), hasta: maxFecha(panel.rango.hasta, hasta) }
    : { desde, hasta };
}

const minFecha = (a, b) => (a < b ? a : b);
const maxFecha = (a, b) => (a > b ? a : b);

/** Ventana comoda alrededor del dia visible: un mes atras y el horizonte. */
function ventanaAgenda(fecha) {
  const centro = new Date(`${fecha}T12:00:00`);
  const desde = new Date(centro);
  desde.setDate(desde.getDate() - 31);
  const hasta = new Date(centro);
  hasta.setDate(hasta.getDate() + 95);
  return { desde: desde.toISOString().slice(0, 10), hasta: hasta.toISOString().slice(0, 10) };
}

async function asegurarAgenda(fecha) {
  const ventana = ventanaAgenda(fecha);
  await cargarAgenda(ventana.desde, ventana.hasta);
}

async function recargarAgenda(fecha) {
  const ventana = ventanaAgenda(fecha);
  panel.rango = null;
  await cargarAgenda(ventana.desde, ventana.hasta, { forzar: true });
}

async function cargarTorneos() {
  panel.torneos = await apiGet('/dashboardadmin/api/torneos.php', { accion: 'torneos' });
}

const reservasApi = {
  crear: datos => apiPost('/dashboardadmin/api/reservas.php', { accion: 'crear' }, datos),
  confirmar: id => apiPost('/dashboardadmin/api/reservas.php', { accion: 'confirmar' }, { id }),
  cancelar: id => apiPost('/dashboardadmin/api/reservas.php', { accion: 'cancelar' }, { id }),
  reprogramar: datos => apiPost('/dashboardadmin/api/reservas.php', { accion: 'reprogramar' }, datos),
  cotizar: datos => apiGet('/dashboardadmin/api/reservas.php', { accion: 'cotizar', ...datos }),
  disponible: datos => apiGet('/dashboardadmin/api/reservas.php', { accion: 'disponible', ...datos })
};

const pagosApi = {
  listar: (desde, hasta) => apiGet('/dashboardadmin/api/pagos.php', { accion: 'listar', desde, hasta }),
  pendientes: (desde, hasta) => apiGet('/dashboardadmin/api/pagos.php', { accion: 'pendientes', desde, hasta }),
  ver: reserva => apiGet('/dashboardadmin/api/pagos.php', { accion: 'ver', reserva }),
  registrar: (reserva, medio) => apiPost('/dashboardadmin/api/pagos.php', { accion: 'registrar' }, { reserva, medio }),
  diferencia: (reserva, medio) => apiPost('/dashboardadmin/api/pagos.php', { accion: 'diferencia' }, { reserva, medio }),
  anular: reserva => apiPost('/dashboardadmin/api/pagos.php', { accion: 'anular' }, { reserva })
};

const torneosApi = {
  inscripciones: torneo => apiGet('/dashboardadmin/api/torneos.php', { accion: 'inscripciones', torneo }),
  inscripcion: id => apiGet('/dashboardadmin/api/torneos.php', { accion: 'inscripcion', id }),
  crear: datos => apiPost('/dashboardadmin/api/torneos.php', { accion: 'crear' }, datos),
  inscribir: datos => apiPost('/dashboardadmin/api/torneos.php', { accion: 'inscribir' }, datos),
  agregar: datos => apiPost('/dashboardadmin/api/torneos.php', { accion: 'agregar' }, datos),
  retirar: id => apiPost('/dashboardadmin/api/torneos.php', { accion: 'retirar' }, { inscripcion: id }),
  maximo: (torneo, maximo) => apiPost('/dashboardadmin/api/torneos.php', { accion: 'maximo' }, { torneo, maximo }),
  programar: datos => apiPost('/dashboardadmin/api/torneos.php', { accion: 'programar' }, datos)
};

const clientesApi = {
  /** El paquete compara contra TO_CHAR(RUT)||DV, sin puntos ni guion. */
  buscar: texto => {
    const compacto = compactRut(texto);
    const pareceRut = /^[1-9]\d{0,7}[0-9K]$/.test(compacto) && /^[\d.\s-]+[kK]?$/.test(texto.trim());
    return apiGet('/api/clientes.php', {
      accion: 'listar', texto: pareceRut ? compacto : texto, estado: 'ACTIVO', tamano: 8
    });
  },
  crear: datos => apiPost('/api/clientes.php', { accion: 'crear' }, datos)
};
