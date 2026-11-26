# Guía de integración SGCD

La aplicación usa Oracle con el [UML oficial de 19 tablas](../modelo/uml-equipo-19/UML_objetivo.mdj), vista **03 Tercera forma normal**. Conserva el UML y adapta el DDL, el PL/SQL y la interfaz a este modelo. El [mapa del modelo](MODELO_OBJETIVO.md) explica las equivalencias con v3. Los scripts 01–09 corresponden a etapas históricas.

## Cómo orientarse

| Módulo | Entrada | Servicios Oracle |
| --- | --- | --- |
| Sesión y perfiles | `web/includes/auth.php`, accesos de `web/cliente/` y `web/dashboardadmin/` | `SGCD_PKG_AUTH`, `SGCD_USUARIOS` y vínculo a ficha |
| Clientes | `pages/clientes.js`, `web/api/clientes.php` | `SGCD_PKG_CLIENTES`, auditoría de cambios y bajas |
| Recintos y tarifas | `pages/recintos.js`, `pages/tarifas.js`, APIs bajo `web/dashboardadmin/api/` | Mantenedores 12c–12e, bloques semanales y compatibilidades |
| Reservas y agenda | `pages/agenda.js`, `pages/reservas.js`, `portal.js`, APIs de reservas | `SGCD_PKG_RESERVAS` y `SGCD_PKG_TARIFAS` |
| Pagos | `pages/pagos.js`, API administrativa de pagos | `SGCD_PKG_PAGOS` |
| Torneos | `pages/torneos.js`, `portal.js`, APIs de torneos | `SGCD_PKG_TORNEOS` |
| Reportes | `pages/reportes.js`, API administrativa de reportes | `SGCD_PKG_CONSULTAS` |

Las páginas JavaScript del panel están en `web/assets/js/pages/`. El portal se monta en `web/cliente/index.php`. La [guía de acceso](ACCESO_DEMO.md) describe la instalación local y las cuentas de laboratorio.

## Contratos que se deben preservar

- Usar IDs estables de Oracle. Los catálogos de cancha, recinto, bloque y modalidad se devuelven desde el esquema objetivo.
- Comprobar sesión, rol y propiedad en PHP y usar CSRF para mutaciones. Vincular parámetros en OCI8 y conservar una transacción para cada operación de negocio.
- Las reservas se calculan por bloques consecutivos de una hora. Oracle decide disponibilidad y tarifa, incluida la ocupación de la cancha grande y sus componentes. Cada solicitud web queda pendiente para confirmación individual.
- El pago se registra manualmente. El importe pactado de una reserva se conserva aunque cambie posteriormente la tarifa.
- Una inscripción ocupa un cupo. El capitán tiene ficha de cliente y cuenta para el portal. Para los demás integrantes se conserva nombre y RUT. El máximo del torneo incluye al capitán.
- Oracle valida las bajas con dependencias y audita los cambios y borrados de fichas. El panel muestra el error de Oracle cuando una operación debe rechazarse.
- Los datos de laboratorio se cargan en Oracle. Las pruebas antiguas de la maqueta se conservan en el historial de Git.

Consulta los [contratos de reservas](RESERVAS_ORACLE.md), los [contratos de torneos](TORNEOS_ORACLE.md) y el [orden de scripts y pruebas](../../sql/README.md) antes de ampliar un flujo.
