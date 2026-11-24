// Puente entre el panel y los torneos de demostración compartidos por el servidor.
const tournaments = [];
const tournamentBookings = [];
const tournamentStates = {
  PLANIFICADO: { name: 'Planificado', className: 'upcoming', symbol: 'calendar-event' },
  EN_CURSO: { name: 'En curso', className: 'in-progress', symbol: 'play-circle-fill' },
  FINALIZADO: { name: 'Finalizado', className: 'finished', symbol: 'check2-circle' },
  CANCELADO: { name: 'Cancelado', className: 'finished', symbol: 'x-circle' }
};
const isTournament = row => row.tournamentId !== undefined;
const isActiveTournamentBlock = row => isTournament(row) && row.status !== 'cancelled';
let nextTournamentBookingId = 91000;

function legacyTournamentSnapshot() {
  try {
    const saved = JSON.parse(localStorage.getItem('sgcd-torneos-demo-v1'));
    return saved?.tournaments?.length && Array.isArray(saved.tournamentBookings) ? saved : null;
  } catch {
    return null;
  }
}

let tournamentSnapshot = null;
let tournamentSaving = false;

async function requestTournamentSnapshot(payload) {
  const options = payload ? {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'X-CSRF-Token': document.querySelector('input[name="csrf"]').value
    },
    body: JSON.stringify(payload)
  } : {};
  const response = await fetch('/dashboardadmin/tournaments-data.php', options);
  if (response.redirected) throw new Error('Tu sesión venció. Vuelve a iniciar sesión.');
  const data = await response.json();
  if (!response.ok) throw new Error(data.message || 'No se pudo acceder a los torneos.');
  return data;
}

function applyTournamentSnapshot(snapshot) {
  tournamentSnapshot = snapshot;
  const currentId = tournaments[selectedTournament]?.id;
  const { tournaments: entries, tournamentBookings: blocks } = structuredClone(snapshot);
  entries.forEach(entry => {
    if (!siteRecords.some(site => site.key === entry.site)) {
      const id = Math.max(0, ...siteRecords.map(site => site.id)) + 1;
      siteRecords.push({ id, key: entry.site, name: entry.siteName || entry.site, status: 'ACTIVO' });
    }
  });
  blocks.forEach(block => {
    const entry = entries[block.tournamentId];
    let index = courts.findIndex(court => court[0] === block.courtName && court[1] === entry.site);
    if (index < 0) index = courts.push([block.courtName, entry.site, entry.sport, 0]) - 1;
    block.court = index;
  });
  entries.forEach(entry => entry.roster.forEach(team => {
    const captain = team.players[0];
    let client = demoClients.find(item => item.rut === captain.rut);
    if (!client) {
      client = { ...captain, id: nextClientId++, phone: '', email: '', type: 'Persona' };
      demoClients.push(client);
    }
    team.captainId = client.id;
  }));
  tournaments.splice(0, tournaments.length, ...entries);
  tournamentBookings.splice(0, tournamentBookings.length, ...blocks);
  nextTournamentBookingId = Math.max(90999, ...blocks.map(row => row.id)) + 1;
  selectedTournament = Math.max(0, entries.findIndex(entry => entry.id === currentId));
  if (!currentId && entries.length) selectedTournament = 0;
  if (!entries[selectedTournament].days.includes(selectedTournamentDay)) {
    selectedTournamentDay = entries[selectedTournament].days[0];
  }
}

async function refreshDemoTournaments() {
  if (tournamentSaving) return false;
  try {
    const data = await requestTournamentSnapshot();
    if (tournamentSaving || document.getElementById('dialog').classList.contains('show')
        || data.version < tournamentSnapshot?.version) return false;
    const changed = !tournamentSnapshot || tournamentSnapshot.version !== data.version ||
      data.tournaments.some((entry, index) => tournaments[index]?.registration !== entry.registration);
    if (changed) applyTournamentSnapshot(data);
    return changed;
  } catch {
    return false;
  }
}

async function importDemoTournaments() {
  const legacy = legacyTournamentSnapshot();
  if (!legacy || tournamentSnapshot?.version !== 1 || tournamentSaving) return;
  tournamentSaving = true;
  try {
    const data = await requestTournamentSnapshot({
      importLegacy: true, version: 1,
      tournaments: legacy.tournaments.map(entry => ({ ...entry, siteName: siteName(entry.site) })),
      tournamentBookings: legacy.tournamentBookings.map(row => ({ ...row, courtName: courts[row.court]?.[0] || row.courtName }))
    });
    applyTournamentSnapshot(data);
    dialog.hide();
    render();
    feedback('Torneos del navegador recuperados.');
  } catch (error) {
    dialog.hide();
    feedback(error.message || 'No se pudieron recuperar los torneos.');
  } finally {
    tournamentSaving = false;
  }
}

async function saveDemoTournaments() {
  if (!tournamentSnapshot || tournamentSaving) return false;
  tournamentSaving = true;
  try {
    const prevIndex = selectedTournament;
    const data = await requestTournamentSnapshot({
      version: tournamentSnapshot.version,
      tournaments: tournaments.map(entry => ({ ...entry, siteName: siteName(entry.site) })),
      tournamentBookings: tournamentBookings.map(row => ({ ...row, courtName: courts[row.court]?.[0] || row.courtName }))
    });
    applyTournamentSnapshot(data);
    selectedTournament = prevIndex;
    if (!tournaments[prevIndex].days.includes(selectedTournamentDay)) selectedTournamentDay = tournaments[prevIndex].days[0];
    return true;
  } catch (error) {
    applyTournamentSnapshot(tournamentSnapshot);
    try { applyTournamentSnapshot(await requestTournamentSnapshot()); }
    catch { /* Keep the last confirmed snapshot while the server is unavailable. */ }
    dialog.hide();
    render();
    feedback(error.message || 'No se guardó el cambio.');
    return false;
  } finally {
    tournamentSaving = false;
  }
}
