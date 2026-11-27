# Portada pública de reservas — Plan de implementación

**Objetivo:** Reestructurar la portada del cliente con la referencia visual entregada, sin alterar la lógica ni las restricciones reales de reserva.

**Decisión:** Se usará una portada pública con foto optimizada y velo verde oscuro. El catálogo será de lectura pública para poblar el formulario, mientras que la consulta de disponibilidad, las reservas y los torneos seguirán exigiendo sesión. La duración no se mostrará ni será elegible: se determina exclusivamente con los bloques configurados en Oracle.

## Alcance

1. Permitir entrar a `/cliente/` sin sesión y mostrar un botón/ícono para iniciar sesión.
2. Mantener la navegación de **Mis reservas** y **Torneos**, junto con el botón de disponibilidad, protegida mediante redirección a inicio de sesión.
3. Convertir el catálogo en una consulta pública de solo lectura; no se harán públicas las reglas de disponibilidad, cotización o creación de reservas.
4. Reordenar el formulario a: recinto, qué quieres jugar, cuándo y hora.
5. Incorporar la foto entregada, reducida para web, con superposición verde oscuro; eliminar estrellas y conservar sólo el indicador de estacionamiento.
6. Aplicar esquinas rectas en la portada y resultados sin reemplazar la línea visual actual de los recuadros de horario.

## Verificación

- `tests/portal-publico-http.sh` debe comprobar el acceso público y que la disponibilidad continúa protegida.
- Se revisará la portada y la ruta de acceso mediante navegador local.
