'use strict';

const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');

const source = fs.readFileSync('web/assets/js/data/panel-store.js', 'utf8');
let consultasAgenda = 0;
const contexto = {
  apiGet: async (ruta) => {
    if (ruta.includes('/reservas.php')) consultasAgenda++;
    return [];
  },
  console
};

vm.runInNewContext(`${source}\nglobalThis.prueba = { asegurarAgenda };`, contexto);

(async () => {
  await contexto.prueba.asegurarAgenda('2026-11-26');
  await contexto.prueba.asegurarAgenda('2026-11-26');
  assert.equal(consultasAgenda, 2,
    'Cada entrada a Agenda o Reservas debe releer Oracle para incluir solicitudes web nuevas.');
  console.log('Refresco de agenda: OK');
})().catch(error => {
  console.error(error.message);
  process.exit(1);
});
