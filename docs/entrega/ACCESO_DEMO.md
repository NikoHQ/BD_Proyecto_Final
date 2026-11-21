# Cómo probar la demo de administración

## Levantar el entorno

El panel se sirve con el Apache + PHP-FPM nativo ya instalado en la torre, sobre el contenedor
`oracle-free` de siempre. No hay un segundo Oracle.

1. Arranca la base: `docker start oracle-free` y espera a que `docker ps` diga `healthy`.
2. Comprueba los servicios: `systemctl is-active httpd php-fpm`.
3. Despliega el panel: copia `web/` en `/srv/http` y recarga `php-fpm`. Los comandos exactos están
   en [`infra/DESPLIEGUE_WEB.md`](../../infra/DESPLIEGUE_WEB.md).

Si la base está vacía, carga el esquema antes de entrar:

```sql
@sql/oracle/04_ddl_v3.sql
@sql/oracle/05_paquetes_plsql.sql
@sql/oracle/06_catalogos_v3.sql
```

`04_ddl_v3.sql` borra y recrea todas las tablas `SGCD_*`; ejecútalo sólo en una base de
desarrollo. En SQL*Plus, dentro del contenedor:

```sh
docker exec -i oracle-free sqlplus sgcd@localhost/FREEPDB1 < sql/oracle/04_ddl_v3.sql
```

## Iniciar sesión

Abre el panel en la URL del servidor de desarrollo. Mientras no esté desplegado en Apache, el
servidor embebido de PHP lo sirve en `http://127.0.0.1:8090/` con las variables `SGCD_DB_*` en el
entorno.

| Usuario de prueba | Clave inicial | Permite probar |
| --- | --- | --- |
| `ADMIN` | `admin` | Perfil, gestión de personal y edición o anulación de pagos en la maqueta. |
| `OPERADOR` | `Demo1234` | Perfil y pantallas operativas con las restricciones del rol. |

Son credenciales **de laboratorio** sembradas por los catálogos v3; no reutilizarlas fuera de este equipo. El cambio de contraseña desde la interfaz exige 12 caracteres, pero el login acepta la clave vigente sin ese mínimo. Si alguien cambió la clave en ese mismo Oracle, usa la que esté guardada. Un administrador puede restablecer la de otro usuario desde **Usuarios del personal**. La recuperación con preguntas es tarea de backend y en la demo aparece como pendiente.

En el avatar están **Mi perfil**, **Configuración y seguridad** y **Cerrar sesión**. El login, la gestión de personal y la consulta Oracle de catálogos requieren la base. Agenda, reservas, clientes, pagos, recintos editables, tarifas y torneos usan ejemplos locales guardados en el navegador. Si quieres una demostración limpia, usa un perfil de navegador separado. Usa sólo datos ficticios.

## Recorrido sugerido

1. Agenda y buscador global por nombre, RUT o número de reserva.
2. Reservas y Clientes con filtros, selección, formularios y paginación.
3. Recintos → Administrar canchas → Tarifas. Prueba un horario semanal y una franja nocturna.
4. Torneos → Ver equipos. Abre un plantel y revisa el nombre, capitán e integrantes.
5. Entra como Operador y comprueba que la edición y anulación de pagos queden fuera de sus acciones.
