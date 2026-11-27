#!/usr/bin/env node
'use strict';

const fs = require('node:fs');
const assert = require('node:assert/strict');

const pagos = fs.readFileSync('web/assets/js/pages/pagos.js', 'utf8');
const estilos = fs.readFileSync('web/assets/css/listas.css', 'utf8');

assert.match(pagos, /class="payment-reservation-link"/, 'Las reservas de Pagos deben usar un enlace visual específico.');
assert.match(estilos, /\.payment-reservation-link\s*\{[^}]*text-decoration:underline/, 'El enlace de reserva debe verse subrayado.');
assert.match(estilos, /\.payment-reservation-link\s*\{[^}]*color:#075fca/, 'El enlace de reserva debe mantener el color azul del panel.');

console.log('OK pagos: reservas como enlaces visuales');
