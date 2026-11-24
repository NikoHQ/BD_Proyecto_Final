'use strict';

let rangoReportes = null;
let reportesCargados = false;
let reporteIngresos = [];
let reporteCanchas = [];
let reporteClientes = [];
let reporteError = '';

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

function reportesView() {
  const rango = `<div class="toolbar">
    <label class="small">Desde <input type="date" id="reportes-desde" class="form-control form-control-sm" value="${rangoReportes.desde}"></label>
    <label class="small">Hasta <input type="date" id="reportes-hasta" class="form-control form-control-sm" value="${rangoReportes.hasta}"></label>
    <button class="btn btn-outline-secondary btn-sm" data-action="reportes-reload">Actualizar</button></div>`;
  const ingresos = table(['Día', 'Pagos', 'Total'], reporteIngresos.map(fila => [
    fila.dia, String(fila.pagos), money.format(fila.total)
  ]), 'Sin pagos en el rango.');
  const canchas = table(['Cancha', 'Modalidad', 'Reservas', 'Horas', 'Importe'], reporteCanchas.map(fila => [
    escapeHtml(fila.cancha), escapeHtml(fila.modalidad), String(fila.reservas),
    fila.horas.toFixed(1), money.format(fila.importe)
  ]), 'Sin reservas en el rango.');
  const clientes = table(['Cliente', 'RUT', 'Reservas', 'Horas', 'Importe'], reporteClientes.map(fila => [
    escapeHtml(fila.cliente), escapeHtml(fila.rut), String(fila.reservas),
    fila.horas.toFixed(1), money.format(fila.importe)
  ]), 'Sin clientes con reservas en el rango.');
  return `${heading('Reportes', 'Ingresos, uso de canchas y clientes por rango de fechas.', rango)}
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
