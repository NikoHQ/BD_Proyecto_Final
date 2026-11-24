const clientActive = client => client.status !== 'INACTIVO';
const clientBookings = client => normalRows().filter(row => clientForReservation(row)?.id === client.id);
function clientsDefinition(f, action) {
  return {
    title: 'Clientes', placeholder: 'Nombre, RUT, teléfono o correo', headers: ['Cliente', 'RUT', 'Correo', 'Estado'],
    rows: demoClients.filter(client => managementSearch(f.query, [client.name, client.email, client.phone], client.rut) &&
      (!f.status || (client.status || 'ACTIVO') === f.status)),
    filters: managementSelect('status', 'Todos los estados', Object.entries(activeStates), f.status),
    toolbar: button('manage-new', 'Nuevo cliente', 'btn-accent'),
    name: client => client.name,
    cells: client => [client.rut, client.email || '—', activeStates[client.status || 'ACTIVO']],
    actions: client => [action('edit', client.id, 'Editar'),
      action('history', client.id, 'Ver reservas'), action('toggle', client.id, clientActive(client) ? 'Desactivar' : 'Activar'),
      action('ask-delete', client.id, 'Eliminar de la maqueta', true)],
    details: client => managementDetails('Ficha del cliente', [
      ['Nombre', client.name], ['RUT', client.rut], ['Teléfono', client.phone], ['Correo', client.email],
      ['Estado', activeStates[client.status || 'ACTIVO']], ['Reservas', String(clientBookings(client).length)],
      ['Pagos registrados', money.format(clientBookings(client).reduce((sum, row) => sum + paymentSummary(row).paid, 0))]
    ], button('manage-edit-' + client.id, 'Editar cliente'))
  };
}

function editClient(item) {
  const client = item || {};
  return managementForm(item ? 'Editar cliente' : 'Nuevo cliente', 'clientes', client.id || 0,
    field('name', 'Nombre', client.name, 'required maxlength="100"') +
    field('rut', 'RUT con DV', client.rut, 'required maxlength="12"') +
    field('phone', 'Teléfono', client.phone, 'type="tel" maxlength="20"') +
    field('email', 'Correo', client.email, 'type="email" maxlength="150"') +
    editSelect('status', 'Estado', Object.entries(activeStates), client.status || 'ACTIVO'));
}

function saveClient(id, data, error) {
  const existing = demoClients.find(client => client.id === id);
  const rut = parseRut(data.rut) || (data.rut === existing?.rut ? existing.rut : null);
  if (!data.name || !rut) return error('Escribe un nombre y un RUT válido.');
  data.email = data.email.toLowerCase();
  if (demoClients.some(client => client.id !== id && (client.rut === rut || (data.email && client.email === data.email)))) {
    return error('Ya existe una ficha con ese RUT o correo.');
  }
  if (existing) {
    const bookings = clientBookings(existing);
    Object.assign(existing, data, { rut });
    bookings.forEach(row => Object.assign(row, { clientId: id, client: data.name }));
  } else {
    demoClients.push({ ...data, rut, id: nextClientId++ });
  }
}
