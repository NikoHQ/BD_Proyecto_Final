'use strict';

let rangoReportes = null;
let reportesCargados = false;
let reporteIngresos = [];
let reporteCanchas = [];
let reporteClientes = [];
let reporteError = '';
const reportePaginas = { ingresos: 1, canchas: 1, clientes: 1 };
const reporteLimites = { ingresos: 10, canchas: 10, clientes: 10 };

function rangoMesActual() {
  const [hoy] = localClock();
  const [anio, mes] = hoy.split('-');
  const desde = `${anio}-${mes}-01`;
  const ultimo = new Date(Number(anio), Number(mes), 0).getDate();
  return { desde, hasta: `${anio}-${mes}-${String(ultimo).padStart(2, '0')}` };
}

async function cargarReportes() {
  if (!rangoReportes) rangoReportes = rangoMesActual();
  reporteError = '';
  try {
    const [ingresos, canchas, clientes] = await Promise.all([
      apiGet('/dashboardadmin/api/reportes.php', { accion: 'ingresos', ...rangoReportes }),
      apiGet('/dashboardadmin/api/reportes.php', { accion: 'canchas', ...rangoReportes }),
      apiGet('/dashboardadmin/api/reportes.php', { accion: 'clientes', ...rangoReportes })
    ]);
    reporteIngresos = ingresos;
    reporteCanchas = canchas;
    reporteClientes = clientes;
  } catch (error) {
    reporteIngresos = [];
    reporteCanchas = [];
    reporteClientes = [];
    reporteError = error.message;
  }
  reportesCargados = true;
}

const totalReporte = filas => filas.reduce((suma, fila) => suma + Number(fila.importe ?? fila.total ?? 0), 0);

function paginarReporte(filas, tipo) {
  const limite = reporteLimites[tipo];
  const paginas = Math.max(1, Math.ceil(filas.length / limite));
  const pagina = Math.min(Math.max(1, reportePaginas[tipo]), paginas);
  reportePaginas[tipo] = pagina;
  const inicio = (pagina - 1) * limite;
  return { filas: filas.slice(inicio, inicio + limite), pagina, paginas, inicio, limite };
}

function reportePagination(tipo, datos, total) {
  if (!total) return '';
  return `<div class="payment-pagination"><span>Mostrando ${datos.inicio + 1}–${Math.min(datos.inicio + datos.limite, total)} de ${total}</span>
    <div class="toolbar"><label>Filas <select id="reportes-${tipo}-page-size" class="form-select form-select-sm" aria-label="Filas por página">${[5, 10, 20, 50].map(limite => `<option value="${limite}" ${limite === datos.limite ? 'selected' : ''}>${limite}</option>`).join('')}</select></label>
      <button class="btn btn-sm btn-light border" data-action="reportes-${tipo}-previous" ${datos.pagina === 1 ? 'disabled' : ''}>${icon('chevron-left')}</button><span class="small">${datos.pagina} / ${datos.paginas}</span><button class="btn btn-sm btn-light border" data-action="reportes-${tipo}-next" ${datos.pagina === datos.paginas ? 'disabled' : ''}>${icon('chevron-right')}</button></div>
  </div>`;
}

function reportesView() {
  const periodo = `<section class="card payment-period mb-3"><div class="card-body"><div class="d-flex flex-wrap align-items-end justify-content-between gap-3"><div><h2 class="h6 mb-1">Periodo de consulta</h2><p class="small text-secondary mb-0">Los indicadores y reportes se actualizan al cambiar las fechas.</p></div><div class="toolbar"><label class="small mb-0">Desde <input type="date" id="reportes-desde" class="form-control" value="${rangoReportes.desde}" max="${rangoReportes.hasta}"></label><span class="payment-period-separator" aria-hidden="true">—</span><label class="small mb-0">Hasta <input type="date" id="reportes-hasta" class="form-control" value="${rangoReportes.hasta}" min="${rangoReportes.desde}"></label></div><div class="btn-group btn-group-sm" role="group" aria-label="Periodos rápidos"><button class="btn btn-light border" data-action="reportes-period-30">Últimos 30 días</button><button class="btn btn-light border" data-action="reportes-period-month">Este mes</button></div></div></div></section>`;
  const ingresosPagina = paginarReporte(reporteIngresos, 'ingresos');
  const canchasPagina = paginarReporte(reporteCanchas, 'canchas');
  const clientesPagina = paginarReporte(reporteClientes, 'clientes');
  const ingresos = `${table(['Día', 'Pagos', 'Total'], ingresosPagina.filas.map(fila => [
    fila.dia, String(fila.pagos), money.format(fila.total)
  ]), 'Sin pagos en el rango.')}${reportePagination('ingresos', ingresosPagina, reporteIngresos.length)}`;
  const canchas = `${table(['Cancha', 'Modalidad', 'Reservas', 'Horas', 'Importe'], canchasPagina.filas.map(fila => [
    escapeHtml(fila.cancha), escapeHtml(fila.modalidad), String(fila.reservas),
    fila.horas.toFixed(1), money.format(fila.importe)
  ]), 'Sin reservas en el rango.')}${reportePagination('canchas', canchasPagina, reporteCanchas.length)}`;
  const clientes = `${table(['Cliente', 'RUT', 'Reservas', 'Horas', 'Importe'], clientesPagina.filas.map(fila => [
    escapeHtml(fila.cliente), escapeHtml(fila.rut), String(fila.reservas),
    fila.horas.toFixed(1), money.format(fila.importe)
  ]), 'Sin clientes con reservas en el rango.')}${reportePagination('clientes', clientesPagina, reporteClientes.length)}`;
  return `${heading('Reportes', 'Ingresos, uso de canchas y clientes por rango de fechas.')}
    ${periodo}
    ${reporteError ? `<div class="alert alert-danger" role="alert">${escapeHtml(reporteError)}</div>` : ''}
    <div class="row g-2 mb-3">
      ${metric('cash-stack', 'Ingresos del rango', money.format(totalReporte(reporteIngresos)))}
      ${metric('calendar2-check', 'Reservas por cancha', String(reporteCanchas.reduce((suma, fila) => suma + fila.reservas, 0)))}
      ${metric('people', 'Clientes con reservas', String(reporteClientes.length))}
      ${metric('clock-history', 'Horas reservadas', reporteCanchas.reduce((suma, fila) => suma + fila.horas, 0).toFixed(1))}
    </div>
    <div class="row g-3">
      <div class="col-12 col-xxl-5">${card('Ingresos por día', `<div class="card-body p-0">${ingresos}</div>`)}</div>
      <div class="col-12 col-xxl-7">${card('Reservas por cancha', `<div class="card-body p-0">${canchas}</div>`)}</div>
      <div class="col-12">${card('Clientes por reservas', `<div class="card-body p-0">${clientes}</div>`)}</div>
    </div>`;
}

async function refreshReportes() {
  if (!rangoReportes.desde || !rangoReportes.hasta) return;
  if (rangoReportes.desde > rangoReportes.hasta) return feedback('La fecha inicial no puede ser posterior a la fecha final.');
  reportePaginas.ingresos = 1;
  reportePaginas.canchas = 1;
  reportePaginas.clientes = 1;
  reportesCargados = false;
  await render();
}

function aplicarPeriodoReportes(tipo) {
  const hoy = localClock()[0];
  const fecha = new Date(`${hoy}T12:00:00`);
  if (tipo === '30') {
    fecha.setDate(fecha.getDate() - 30);
  } else {
    fecha.setDate(1);
  }
  rangoReportes = { desde: fecha.toISOString().slice(0, 10), hasta: hoy };
  return refreshReportes();
}
