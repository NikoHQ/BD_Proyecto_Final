# Fase 4, unidad 5: pantallas conectadas — cerrada

**Fecha:** 2026-11-24 · **Estado:** las cinco pantallas leen y escriben en Oracle; la
maqueta queda solo en las pantallas de catálogo que no eran parte de la unidad.

## Qué quedó conectado

| Pantalla | Fuente | Mutaciones |
|---|---|---|
| Agenda del panel | `reservas.php?accion=agenda` | crear, confirmar, cancelar, reprogramar |
| Reservas del panel | misma agenda + filtros en el navegador | confirmar, reprogramar, cancelar |
| Pagos | `pagos.php?accion=listar\|pendientes\|ver` | registrar, anular |
| Torneos del panel | `torneos.php?accion=torneos\|inscripciones\|inscripcion` | crear, inscribir, agregar, retirar, maximo, programar |
| Reportes (nueva) | `reportes.php?accion=ingresos\|canchas\|clientes` | — |
| Portal del cliente | `api/catalogo.php`, `api/reservas.php`, `api/torneos.php` | solicitar, inscribir, agregar, retirar |

El panel deja de usar `demo/fixtures`, `demo/store` y `demo/tournaments` para estas cinco
pantallas. Esos archivos siguen cargados porque Recintos, Tarifas y Clientes todavía son
maquetas: quedan fuera del alcance de la unidad 5.

## Archivos nuevos

- `web/includes/catalogo-dto.php` — recintos, horarios, canchas, modalidades y componentes.
- `web/dashboardadmin/api/catalogo.php` — catálogo para el panel.
- `web/api/catalogo.php` — catálogo para el portal (rol `CLIENTE`).
- `web/includes/pagos-dto.php` — cartera del día y reservas confirmadas sin pago.
- `web/assets/js/data/api.js` — `apiGet`/`apiPost` con `X-CSRF-Token` y `ApiError`.
- `web/assets/js/data/panel-store.js` — estado real del panel (catálogo, agenda, torneos).
- `web/assets/js/pages/reportes.js` — página de reportes.
- `web/cliente/login.php`, `web/cliente/logout.php` — sesión real de `SGCD_USUARIOS`.

## Endpoints ampliados

- `reservas.php?accion=cotizar` (panel y portal) usa `SGCD_PKG_TARIFAS.cotizar` para
  mostrar el total antes de reservar. La tarifa nunca se calcula en el navegador.
- `pagos.php?accion=listar|pendientes` lee `SGCD_PAGOS` y las confirmadas sin pago.
- `reportes.php` responde `20080` cuando falta el rango o no es `Y-m-d`, igual que el paquete.

## Decisiones de implementación

1. **Un solo estado real en el panel.** `panel.reservas` es un `Map` que se pide por rango
   (`fecha − 31` a `fecha + 95`) y se fusiona; las mutaciones recargan la ventana.
2. **Sin cálculo de tarifas en JS.** Se eliminó `automaticQuote`: el diálogo pide
   `cotizar` y muestra el total devuelto.
3. **Sin detección de cruces en JS.** El solape lo decide `SGCD_PKG_RESERVAS`; la agenda
   solo dibuja lo que Oracle devuelve. La cancha grande y sus componentes usan
   `SGCD_CANCHAS_COMPONENTES` desde el catálogo, no índices fijos.
4. **Búsqueda de clientes por RUT.** `listar_fichas` compara contra `TO_CHAR(RUT)||DV`,
   así que el navegador compacta el RUT (`11111111-1` → `111111111`) antes de buscar.
5. **Portal con la misma sesión del panel** (`sgcd_session`) pero rol `CLIENTE`; el panel
   manda al portal a quien no sea administrador y el portal manda al panel al personal.
6. **Solicitudes web.** La página `solicitudes-web.php` ya no usa la maqueta: lista las
   reservas `ORIGEN_RESERVA = 'WEB'` pendientes y confirma/cancela con los paquetes.

## Verificación hecha

- `14_pruebas_paquetes_sgcd_19.sql`: 239 comprobaciones en verde.
- `tests/integracion_dos_sesiones.sh`: 17 comprobaciones en verde.
- Navegador real (Brave headless + CDP): agenda, reservas, pagos, torneos y reportes
  renderizan sin errores de JavaScript; crear reserva, confirmar, reprogramar, cancelar,
  cobrar, anular, crear torneo, inscribir, agregar jugador y programar funcionan.
- Portal: login con `demo / SGCDdemo2026`, solicitar una hora crea `PENDIENTE`, el panel
  la confirma y el cliente solo ve sus propias reservas.
- API sin sesión: `401`. Un cliente en `/dashboardadmin/`: redirige a `/cliente/`.
  Un administrador en `/cliente/`: redirige al panel.

La base quedó sin datos operativos después de las pruebas (solo catálogos y las tres
cuentas de laboratorio). Los datos para el video son el paso siguiente.

## Pendiente después de la unidad 5

- Datos operativos para el video (`07_datos_operativos.sql` adaptado a 19 tablas).
- Conectar Recintos, Tarifas y Clientes (paquetes `12c`, `12d`, `12e`) o retirarlas del menú.
- Limpiar el código muerto del portal anterior: `web/cliente/demo.php`, `http.php`,
  `reservas.php`, `torneos.php`, `portal.php`, `vistas/`, `web/includes/portal-inbox.php`,
  `web/includes/tournament-store.php`, `web/dashboardadmin/tournaments-data.php` y
  `web/dashboardadmin/catalogo-oracle.php` (roto contra el modelo de 19 tablas).
- Capturas, video, láminas y ensayo de la defensa.
