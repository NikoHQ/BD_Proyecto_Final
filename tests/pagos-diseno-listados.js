#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const assert = require('node:assert/strict');

const pagos = fs.readFileSync('web/assets/js/pages/pagos.js', 'utf8');
const app = fs.readFileSync('web/assets/js/app.js', 'utf8');

assert.match(pagos, /Periodo de consulta/, 'Pagos debe presentar el rango de fechas como un control propio y comprensible.');
assert.match(pagos, /paymentPagination\('pendientes'/, 'Reservas por cobrar debe permitir elegir cuántas filas mostrar.');
assert.match(pagos, /paymentPagination\('registrados'/, 'Pagos registrados debe permitir elegir cuántas filas mostrar.');
assert.match(pagos, /payment-pagination/, 'Ambos listados deben incluir controles de paginación.');
assert.match(pagos, /col-12 col-xxl-6/, 'Los dos listados deben ocupar columnas equilibradas.');
assert.doesNotMatch(pagos, /data-action="pagos-reload"/, 'El periodo no debe depender de un botón manual para actualizar.');
assert.match(app, /refreshPayments/, 'Al cambiar el periodo, la pantalla debe actualizar sus datos automáticamente.');

console.log('OK pagos: periodo integrado y listados paginados');
