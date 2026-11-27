#!/usr/bin/env node
'use strict';

const fs = require('fs');
const assert = require('assert');

const source = fs.readFileSync('web/assets/js/pages/reservas.js', 'utf8');

assert.match(source, /Solicitudes web pendientes/, 'Reservas debe mostrar una bandeja principal de solicitudes web.');
assert.match(source, /Rechazar solicitud/, 'Las solicitudes web deben poder rechazarse desde la bandeja.');
assert.doesNotMatch(source, /href="\/dashboardadmin\/solicitudes-web\.php"/, 'La pantalla no debe enviar al usuario a una bandeja separada.');

console.log('OK reservas: solicitudes web visibles en la pantalla principal');
