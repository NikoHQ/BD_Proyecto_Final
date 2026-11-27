#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const assert = require('node:assert/strict');

const reportes = fs.readFileSync('web/assets/js/pages/reportes.js', 'utf8');
const app = fs.readFileSync('web/assets/js/app.js', 'utf8');

assert.match(reportes, /class="card payment-period mb-3"/, 'Reportes debe usar la misma tarjeta de periodo que Pagos.');
assert.match(reportes, /Periodo de consulta/, 'Reportes debe identificar claramente el rango que consulta.');
assert.match(reportes, /reportes-period-30/, 'Reportes debe ofrecer el acceso rápido a los últimos 30 días.');
assert.match(reportes, /reportes-period-month/, 'Reportes debe ofrecer el acceso rápido al mes actual.');
assert.doesNotMatch(reportes, /reportes-reload/, 'El periodo de Reportes no debe depender de un botón manual para actualizar.');
assert.match(app, /aplicarPeriodoReportes\('30'\)/, 'El atajo de 30 días debe actualizar los datos de Reportes.');
assert.match(app, /aplicarPeriodoReportes\('month'\)/, 'El atajo del mes debe actualizar los datos de Reportes.');
assert.match(reportes, /reportePagination/, 'Reportes debe incluir controles reutilizables de paginación.');
assert.match(reportes, /'ingresos'/, 'Ingresos por día debe tener paginación propia.');
assert.match(reportes, /'canchas'/, 'Reservas por cancha debe tener paginación propia.');
assert.match(reportes, /'clientes'/, 'Clientes por reservas debe tener paginación propia.');
assert.match(reportes, /reportePagination\('ingresos'/, 'Ingresos debe permitir definir el límite de filas.');
assert.match(reportes, /reportePagination\('canchas'/, 'Canchas debe permitir definir el límite de filas.');
assert.match(reportes, /reportePagination\('clientes'/, 'Clientes debe permitir definir el límite de filas.');
assert.match(app, /reportes-\(ingresos\|canchas\|clientes\)-\(previous\|next\)/, 'La navegación de las páginas de reportes debe estar conectada.');

console.log('OK reportes: límites y paginación por tabla');
