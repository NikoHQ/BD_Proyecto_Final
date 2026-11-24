# Pendiente — fase 4, unidad 5: pantallas conectadas

**Fecha:** 2026-11-24 · **Estado:** backend terminado y probado; el navegador todavía usa datos
falsos. Este documento es el punto de retomada.

## Lo que ya está listo

| Capa | Qué existe |
|---|---|
| Base de datos | `SGCD` con las 19 tablas, catálogos y 7 paquetes `VALID` |
| Lógica | Reservas, pagos, torneos y reportes en PL/SQL, con 239 pruebas de contrato y 17 de concurrencia |
| Sesión | `web/includes/auth.php` sobre `SGCD_USUARIOS`; `requireStaff()` para el panel |
| API del panel | `dashboardadmin/api/reservas.php`, `pagos.php`, `reportes.php`, `torneos.php` |
| API del portal | `api/reservas.php`, `api/torneos.php` |
| Despliegue | `bash infra/desplegar-web.sh` (sin `sudo`, con ACL sobre `/srv/http`) |

Endpoints y parámetros exactos están en la cabecera de cada archivo de `web/*/api/`.

## Lo que falta, por pantalla

### 1. Agenda del panel

- **Archivos:** `web/assets/js/pages/agenda.js`, `web/assets/js/pages/reservas.js`, `web/index.php`
  (orden de scripts).
- **Endpoint:** `GET /dashboardadmin/api/reservas.php?accion=agenda&desde&hasta[&cancha]` y las
  mutaciones `crear`, `confirmar`, `cancelar`, `reprogramar`.
- **Aceptación:** la semana se dibuja desde Oracle; crear una reserva la muestra sin recargar; una
  reserva cancelada se ve como cancelada; desaparece el cartel de modo demostración.
- **Ojo:** las mutaciones son `POST` con `X-CSRF-Token`; el token está en la página (formulario de
  logout).

### 2. Pagos

- **Archivo:** `web/assets/js/pages/pagos.js`.
- **Endpoint:** `GET /dashboardadmin/api/pagos.php?accion=ver|saldo&reserva=ID` y `POST registrar`,
  `diferencia`, `anular` con `medio`.
- **Aceptación:** una reserva confirmada muestra su saldo; cobrar deja saldo 0; anular lo devuelve;
  el doble cobro muestra el mensaje de `20053`; una reserva pendiente no se puede cobrar (`20052`).

### 3. Torneos del panel

- **Archivo:** `web/assets/js/pages/torneos.js` (y retirar `web/assets/js/demo/tournaments.js` de
  `index.php`).
- **Endpoint:** `GET /dashboardadmin/api/torneos.php?accion=torneos|inscripciones|inscripcion` y
  `POST crear`, `inscribir`, `agregar`, `retirar`, `maximo`, `programar`.
- **Aceptación:** crear un torneo; inscribir un equipo; agregar un jugador y ver la plantilla;
  programar un rango y encontrarlo en la agenda; que el último cupo rechace con su mensaje.

### 4. Página Reportes (nueva)

- **Archivos:** `web/assets/js/pages/reportes.js` y una sección nueva en `web/dashboardadmin/index.php`
  con su enlace en el menú.
- **Endpoint:** `GET /dashboardadmin/api/reportes.php?accion=ingresos|canchas|clientes&desde&hasta`.
- **Aceptación:** rango por defecto el mes en curso; tres tablas con totales; un rango sin
  movimientos se muestra vacío, no con error; sin rango válido muestra el mensaje de `20080`.

### 5. Portal del cliente

- **Archivos:** `web/cliente/portal.php`, `reservas.php`, `torneos.php`, `vistas/*`,
  `web/cliente/http.php`, `web/includes/portal-inbox.php`.
- **Login real:** reemplazar `web/cliente/demo.php` por la sesión de `auth.php` con rol `CLIENTE`
  (mismo formulario, contra `SGCD_USUARIOS`). `demo` / `SGCDdemo2026` sirve para probar.
- **Endpoints:** `api/reservas.php?accion=disponible|solicitar|mias` y
  `api/torneos.php?accion=torneos|mias|detalle|inscribir|agregar|retirar`.
- **Aceptación:** un cliente ve solo sus reservas e inscripciones; solicitar una hora crea una
  reserva `PENDIENTE` que el panel confirma; no aparece ninguna acción de administración.

### 6. Limpieza

- Quitar `demo/store.js`, `demo/fixtures.js` y `demo/tournaments.js` del `index.php` a medida que
  cada sección quede conectada, y el cartel de **Modo demostración** de cada vista.
- `catalogo-oracle.php`, `duraciones.php`, `solicitudes-web.php` y `account.php` ya leen de Oracle;
  solo revisar que no queden referencias al demo.

## Orden sugerido

1. Agenda (es lo que más se verá en el video).
2. Reportes (página nueva, contrato simple).
3. Pagos.
4. Torneos del panel.
5. Portal completo, con el login real.

## Pruebas de aceptación al cerrar

- `bash tests/integracion_dos_sesiones.sh` sigue en verde.
- `14_pruebas_paquetes_sgcd_19.sql` sigue en 239 comprobaciones.
- Las cinco pantallas funcionan en `/srv/http` con `admin/admin` y el portal con `demo/SGCDdemo2026`.
- El panel rechaza a un cliente (`/cliente/`) y la API sin sesión responde `401`.

## Después de la unidad 5

- Datos operativos para el video (`07_datos_operativos.sql` de la v3, adaptado a 19 tablas).
- Capturas, video y láminas.
- Ensayo de la defensa: una instalación limpia, dos sesiones y un operador sin permiso de pago
  llamando el endpoint directo.
