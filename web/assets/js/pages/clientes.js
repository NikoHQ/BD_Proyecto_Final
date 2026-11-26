const clientsEndpoint = '/api/clientes.php';
let clientList = { items: [], total: 0 };

async function cargarClientes(seq) {
  const state = managementState.clientes;
  const { page, size, filters, selected } = state;
  const params = { accion: 'listar', texto: filters.query, estado: filters.status, pagina: page, tamano: size };
  let list = await apiGet(clientsEndpoint, params);
  const currentPage = Math.min(page, Math.max(1, list.paginas));
  if (currentPage !== page) list = await apiGet(clientsEndpoint, { ...params, pagina: currentPage });
  const index = list.items.findIndex(client => client.id === selected);
  if (index !== -1) list.items[index] = await apiGet(clientsEndpoint, { accion: 'ver', id: selected });
  if (seq !== renderSeq) return;
  state.page = currentPage;
  clientList = list;
}

function clientsDefinition(f, action) {
  return {
    title: 'Clientes', placeholder: 'Nombre, RUT, teléfono o correo', headers: ['Cliente', 'RUT', 'Correo', 'Estado'],
    rows: clientList.items, total: clientList.total,
    filters: managementSelect('status', 'Todos los estados', Object.entries(activeStates), f.status),
    toolbar: button('manage-new', 'Nuevo cliente', 'btn-accent'),
    name: client => client.nombre,
    cells: client => [client.rut, client.correo || '—', activeStates[client.estado]],
    actions: client => [action('edit', client.id, 'Editar'),
      action('history', client.id, 'Ver reservas en agenda'),
      action('toggle', client.id, client.estado === 'ACTIVO' ? 'Desactivar' : 'Activar'),
      action('ask-delete', client.id, 'Eliminar cliente', true)],
    details: client => managementDetails('Ficha del cliente', [
      ['Nombre', client.nombre], ['RUT', client.rut], ['Teléfono', client.telefono], ['Correo', client.correo],
      ['Estado', activeStates[client.estado]], ['Cuenta web', client.cuenta_web ? 'Sí' : 'No'],
      ['Reservas', String(client.reservas)], ['Reservas vigentes', String(client.reservas_vigentes)],
      ['Total pagado', money.format(client.importe_pagado)], ['Eventos de auditoría', String(client.eventos_auditoria)]
    ], button('manage-edit-' + client.id, 'Editar cliente'))
  };
}

function editClient(item) {
  const client = item || {};
  return managementForm(item ? 'Editar cliente' : 'Nuevo cliente', 'clientes', client.id || 0,
    field('nombre', 'Nombre', client.nombre, 'required maxlength="100"') +
    field('rut', 'RUT con DV', client.rut, item ? 'readonly' : 'required maxlength="12"') +
    field('telefono', 'Teléfono', client.telefono, 'type="tel" maxlength="20"') +
    field('correo', 'Correo', client.correo, 'type="email" maxlength="150"'));
}

async function saveClient(id, data, error) {
  try {
    const client = await apiPost(clientsEndpoint, { accion: id ? 'actualizar' : 'crear' }, { ...data, id });
    if (client.creada === false) return error('Ya existe una ficha con ese RUT. Búscala en el listado para editarla.');
    const state = managementState.clientes;
    if (!id) {
      state.filters = { query: client.rut };
      state.page = 1;
    }
    state.selected = client.id;
    dialog.hide();
    feedback('Ficha guardada.');
    await render();
  } catch (failure) {
    error(failure.message);
  }
}

async function handleClientAction(kind, client) {
  const { id, nombre } = client;
  if (kind === 'edit') return editClient(client);
  if (kind === 'history') {
    try {
      await asegurarAgenda(date);
      const rows = reservasPanel().filter(row => row.clienteId === id);
      showDialog(nombre, reservationTable(rows, 'Sin reservas en el rango cargado de la agenda.'));
    } catch (error) {
      feedback(error.message);
    }
    return;
  }
  if (kind === 'ask-delete') {
    return showDialog('Eliminar cliente', '<p>¿Eliminar la ficha de <strong>' + escapeHtml(nombre) +
      '</strong>?</p>' + button('manage-delete-' + id, 'Confirmar eliminación', 'btn-danger'));
  }
  if (kind !== 'toggle' && kind !== 'delete') return;
  try {
    await apiPost(clientsEndpoint, { accion: kind === 'toggle' ? 'estado' : 'borrar' },
      { id, estado: client.estado === 'ACTIVO' ? 'INACTIVO' : 'ACTIVO' });
    dialog.hide();
    feedback(kind === 'toggle' ? 'Estado actualizado.' : 'Cliente eliminado.');
    await render();
  } catch (error) {
    feedback(error.message);
  }
}
