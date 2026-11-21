# Cómo probar la demo de administración

## Levantar el entorno

Ejecuta estos pasos desde la raíz del repositorio con Docker y Docker Compose.

1. Crea `.env` a partir de `.env.example`. Define contraseñas locales para Oracle y para el usuario del esquema `SGCD`. Conserva tu `.env` si ya existe.
2. Ejecuta `docker compose up -d` y comprueba con `docker compose ps` que Oracle esté saludable.
3. Si el volumen Oracle es nuevo, copia y carga el esquema v3, sus paquetes y los catálogos. El DDL reconstruye tablas SGCD. Ejecútalo sólo sobre una base de desarrollo recién creada. Si ya tienes v3 inicializada, continúa directamente al login.

```sh
docker compose cp sql/oracle/04_ddl_v3.sql oracle:/tmp/04_ddl_v3.sql
docker compose cp sql/oracle/05_paquetes_plsql.sql oracle:/tmp/05_paquetes_plsql.sql
docker compose cp sql/oracle/06_catalogos_v3.sql oracle:/tmp/06_catalogos_v3.sql
docker compose exec oracle sqlplus SGCD@localhost/FREEPDB1
```

SQL*Plus pide la contraseña `SGCD_DB_PASSWORD` del `.env`. En el prompt de SQL*Plus, ejecuta:

```sql
@/tmp/04_ddl_v3.sql
@/tmp/05_paquetes_plsql.sql
@/tmp/06_catalogos_v3.sql
EXIT
```

## Iniciar sesión

Abre [el panel local](http://localhost:8080/).

| Usuario de prueba | Clave inicial | Permite probar |
| --- | --- | --- |
| `ADMIN` | `Demo1234` | Perfil, gestión de personal y edición o anulación de pagos en la maqueta. |
| `OPERADOR` | `Demo1234` | Perfil y pantallas operativas con las restricciones del rol. |

Son credenciales de desarrollo sembradas por los catálogos v3. Si alguien cambió la clave en ese mismo Oracle, usa la clave vigente. Un administrador puede restablecer la de otro usuario desde **Usuarios del personal**. La recuperación con preguntas es tarea de backend y en la demo aparece como pendiente.

En el avatar están **Mi perfil**, **Configuración y seguridad** y **Cerrar sesión**. El login, la gestión de personal y la consulta Oracle de catálogos requieren la base. Agenda, reservas, clientes, pagos, recintos editables, tarifas y torneos usan ejemplos locales guardados en el navegador. Si quieres una demostración limpia, usa un perfil de navegador separado. Usa sólo datos ficticios.

## Recorrido sugerido

1. Agenda y buscador global por nombre, RUT o número de reserva.
2. Reservas y Clientes con filtros, selección, formularios y paginación.
3. Recintos → Administrar canchas → Tarifas. Prueba un horario semanal y una franja nocturna.
4. Torneos → Ver equipos. Abre un plantel y revisa el nombre, capitán e integrantes.
5. Entra como Operador y comprueba que la edición y anulación de pagos queden fuera de sus acciones.
