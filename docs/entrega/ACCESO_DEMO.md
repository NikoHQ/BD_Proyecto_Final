# Cómo probar la demo de SGCD

## Levantar el entorno

El panel se sirve con el Apache + PHP-FPM nativo ya instalado en la torre, sobre el contenedor
`oracle-free` de siempre. No hay un segundo Oracle.

1. Arranca la base: `docker start oracle-free` y espera a que `docker ps` diga `healthy`.
2. Comprueba los servicios: `systemctl is-active httpd php-fpm`.
3. Despliega la web: copia `web/` en `/srv/http` y recarga `php-fpm`. Los comandos exactos están
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

Para un entorno aislado con Docker, `docker compose up -d` levanta la aplicación y la base y publica
ambos paneles en el puerto **8080**. La alternativa PHP local del puerto **8091** (`php -S
127.0.0.1:8091 -t web`) sirve para probar el portal por separado.

## Entradas y cuentas de prueba

- [Portal de clientes](http://127.0.0.1:8080/)
- [Panel administrativo](http://127.0.0.1:8080/dashboardadmin/)

Usa el puerto **8080** para ver los mismos torneos e inscripciones en ambos paneles y para confirmar
solicitudes web. En la torre, Apache sirve el portal en `/` y el panel en `/dashboardadmin/`.

| Usuario de prueba | Clave inicial | Permite probar |
| --- | --- | --- |
| `ADMIN` | `admin` | Perfil, gestión de personal y edición o anulación de pagos en la maqueta. |
| `OPERADOR` | `Demo1234` | Perfil y pantallas operativas con las restricciones del rol. |
| `demo` | `SGCDdemo2026` | Cliente de prueba con historial y acceso a torneos. |
| `nuevo` | `SGCDdemo2026` | Cliente nuevo que puede enviar solicitudes. Cada reserva exige confirmación administrativa. |

Las cuentas de personal son credenciales **de laboratorio** sembradas por los catálogos v3; no
reutilizarlas fuera de este equipo. El cambio de contraseña desde la interfaz exige 12 caracteres,
pero el login acepta la clave vigente sin ese mínimo. Si alguien cambió la clave en ese mismo Oracle,
usa la que esté guardada. Un administrador puede restablecer la de otro usuario desde **Usuarios del
personal**. Las cuentas `demo` y `nuevo` pertenecen a la demo del portal. La recuperación con
preguntas es tarea de backend y en la demo aparece como pendiente.

En el avatar están **Mi perfil**, **Configuración y seguridad** y **Cerrar sesión**. El login, la
gestión de personal y la consulta Oracle de catálogos requieren la base. Agenda, reservas de
mostrador, clientes, pagos, recintos editables y tarifas usan datos locales del navegador. Torneos y
solicitudes web usan archivos temporales compartidos por la instancia PHP. Las cuentas y reservas del
portal usan sesiones PHP de demo. Usa sólo datos ficticios.

## Recorrido sugerido

1. Agenda y buscador global por nombre, RUT o número de reserva.
2. Reservas y Clientes con filtros, selección, formularios y paginación.
3. Recintos → Administrar canchas → Tarifas. Revisa el horario semanal, las seis canchas de Fútbol 6,
   la grande y una franja nocturna.
4. Torneos → Ver equipos. Abre un plantel y revisa el nombre, capitán e integrantes.
5. Registra un pago manual en una reserva disponible y comprueba que el detalle conserve un solo pago.
   La cuenta `OPERADOR` permite comprobar el rechazo de confirmación web y de edición o anulación de pagos.

Para probar reservas web de punta a punta e inscribir un equipo desde el portal, sigue el
[recorrido del cliente](PORTAL_CLIENTE.md).

El [mapa del UML de 19 tablas](MODELO_OBJETIVO.md) describe la base que se integrará. La demo arranca
con el DDL v3 de transición.
