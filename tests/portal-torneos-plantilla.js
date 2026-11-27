#!/usr/bin/env node
'use strict';

/*
 * Contrato visible del portal: una inscripción no se envía desde la tarjeta
 * del torneo. Antes debe pedir la nómina completa y una confirmación final.
 */
const fs = require('fs');
const assert = require('assert');

const source = fs.readFileSync('web/cliente/portal.js', 'utf8');

assert.match(source, /data-preparar-inscripcion/, 'La tarjeta debe abrir el formulario de plantilla.');
assert.match(source, /data-confirmar-inscripcion/, 'La revisión debe requerir una confirmación explícita.');
assert.match(source, /data-editar-plantilla/, 'Una inscripción vigente debe permitir editar su plantilla.');
assert.doesNotMatch(source, /data-jugador=/, 'No debe existir el alta incremental de jugadores.');
assert.match(source, /minimo/, 'El portal debe distinguir el mínimo del máximo de jugadores.');

console.log('OK portal: inscripción completa, confirmación y edición de plantilla');
