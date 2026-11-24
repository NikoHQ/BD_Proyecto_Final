'use strict';

/**
 * Puente con las APIs PHP. Todo error de la capa de servicios llega con el
 * codigo de Oracle y un mensaje para el operador; aqui solo se propaga.
 */
class ApiError extends Error {
  constructor(message, codigo = null, estado = 0) {
    super(message);
    this.name = 'ApiError';
    this.codigo = codigo;
    this.estado = estado;
  }
}

const apiCsrf = () => document.querySelector('meta[name="csrf-token"]')?.content || '';

function apiUrl(ruta, parametros = {}) {
  const url = new URL(ruta, location.origin);
  for (const [clave, valor] of Object.entries(parametros)) {
    if (valor !== undefined && valor !== null && valor !== '') url.searchParams.set(clave, valor);
  }
  return url;
}

async function apiRespuesta(response) {
  let cuerpo = null;
  try { cuerpo = await response.json(); } catch { /* Respuesta sin JSON. */ }
  if (response.status === 401) throw new ApiError('La sesión venció. Vuelve a iniciar sesión.', 401, 401);
  if (!response.ok || !cuerpo?.ok) {
    throw new ApiError(cuerpo?.error?.mensaje || `No se pudo completar la operación (${response.status}).`,
      cuerpo?.error?.codigo ?? null, response.status);
  }
  return cuerpo.data;
}

async function apiGet(ruta, parametros = {}) {
  const response = await fetch(apiUrl(ruta, parametros), {
    headers: { Accept: 'application/json' },
    credentials: 'same-origin',
    cache: 'no-store'
  });
  return apiRespuesta(response);
}

async function apiPost(ruta, parametros = {}, cuerpo = {}) {
  const response = await fetch(apiUrl(ruta, parametros), {
    method: 'POST',
    headers: {
      Accept: 'application/json',
      'Content-Type': 'application/json',
      'X-CSRF-Token': apiCsrf()
    },
    credentials: 'same-origin',
    cache: 'no-store',
    body: JSON.stringify(cuerpo)
  });
  return apiRespuesta(response);
}
