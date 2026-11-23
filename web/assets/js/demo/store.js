// Adaptador temporal. Sustituir lecturas y mutaciones por operaciones de PHP.
const storageKey = 'sgcd-reservas-demo-v1';
const managementKey = 'sgcd-catalogos-demo-v1';
const courtMeta = {};
let nextClientId = 1;

function initManagement() {
  try {
    const saved = JSON.parse(localStorage.getItem(managementKey));
    if (saved) {
      demoClients.splice(0, demoClients.length, ...saved.clients);
      siteRecords.splice(0, siteRecords.length, ...saved.sites);
      Object.assign(courtMeta, saved.courtMeta);
      saved.courts.forEach((court, index) => { courts[index] = court; });
      if (Array.isArray(saved.tariffs)) demoTariffs.push(...saved.tariffs);
      nextClientId = saved.nextClientId || 1;
    }
  } catch { /* Use the demo catalog when storage is unavailable. */ }
  nextClientId = Math.max(nextClientId, ...demoClients.map(client => client.id + 1));
  initTariffs();
}

function saveManagement() {
  try {
    localStorage.setItem(managementKey, JSON.stringify({
      clients: demoClients, sites: siteRecords, courts, courtMeta, nextClientId, tariffs: demoTariffs
    }));
  } catch { storageUnavailable = true; }
}
const demoTariffs = [];
let nextTariffId = 1;
function initTariffs() {
  if (!demoTariffs.length) {
    courts.forEach((court, index) => {
      if (!court[3]) return;
      weekdays.forEach((_, day) => demoTariffs.push({
        id: nextTariffId++, court: index, mode: court[2], day, start: '08:00', end: '22:00',
        from: '2020-01-01', until: '', rate: court[3], status: 'ACTIVA'
      }));
    });
  }
  nextTariffId = Math.max(nextTariffId, ...demoTariffs.map(rate => rate.id + 1));
}
function loadReservations() {
  try {
    const stored = JSON.parse(localStorage.getItem(storageKey));
    if (Array.isArray(stored)) return stored;
  } catch {
    // Start with demo data when the browser cannot read the saved selection.
  }
  return demoRows.map(([court, client, start, end, status], index) => ({
    id: 10451 + index, court, client, start, end, status, date: initialDay,
    origin: status === 'pending' ? 'Web' : 'Mostrador',
    amount: status === 'maintenance' ? 0 : courts[court][3] * (minutes(end) - minutes(start)) / 60
  }));
}
const nextReservationId = () => Math.max(Number(localStorage.getItem('sgcd-demo-last-reservation')) || 10450,
  10450, ...reservations.map(row => row.id)) + 1;
function save(message) {
  try { localStorage.setItem(storageKey, JSON.stringify(reservations)); }
  catch { storageUnavailable = true; }
  dialog.hide();
  render();
  feedback(storageUnavailable ? `${message} El navegador solo guardó el cambio para esta sesión.` : message);
}

let reservations = [];
const deadlines = new Map();
const allBookings = () => [...reservations, ...tournamentBookings];
let storageUnavailable = false;

function initDemoStore() {
  initManagement();
  reservations = loadReservations();
  reservations.forEach(row => {
    row.clientId ??= demoClients.find(client => client.name === row.client)?.id;
    if (row.status === 'completed' && !row.payments?.length) row.payments = [{ amount: row.amount, method: 'Débito' }];
    if (row.status === 'pending') {
      const index = deadlines.size;
      row.expiresAt ??= Date.now() + (7 + index * 9) * 60000;
      deadlines.set(row.id, row.expiresAt);
    }
  });
  try { localStorage.setItem(storageKey, JSON.stringify(reservations)); }
  catch { /* The demo remains available in memory. */ }
}
