#!/usr/bin/env node
'use strict';

const fs = require('fs');
const assert = require('assert');

const reservas = fs.readFileSync('web/assets/js/pages/reservas.js', 'utf8');
const app = fs.readFileSync('web/assets/js/app.js', 'utf8');

assert.match(reservas, /row g-3 align-items-start reservation-layout/, 'Las columnas de Reservas deben alinearse arriba para que el detalle no estire el listado.');
assert.match(app, /document\.addEventListener\('input', async event =>/, 'La búsqueda de Reservas debe poder esperar el redibujado.');
assert.match(app, /await render\(\);\s*\n\s*\$\('reservation-query'\)\?\.focus\(\{ preventScroll: true \}\)/, 'La búsqueda debe recuperar el foco solo después de redibujar el campo.');
assert.match(app, /\$\('reservation-query'\)\?\.setSelectionRange\(caret, caret\)/, 'La búsqueda debe conservar el cursor tras filtrar.');

console.log('OK reservas: filtros mantienen foco y el listado no se estira');
