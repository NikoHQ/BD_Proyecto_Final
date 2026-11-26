# Cómo probar SGCD con Oracle

## Docker local

Desde la raíz del repositorio, conserva tu `.env` si ya existe. En una instalación nueva, copia
`.env.example` a `.env` y define `ORACLE_PASSWORD` y `SGCD_DB_PASSWORD`. Usa claves de laboratorio
y conserva el archivo fuera de Git.

Para crear o arrancar el contenedor Oracle en una instalación nueva:

```sh
docker compose up -d --wait oracle
```

Si `sgcd-oracle` ya está activo y saludable, pasa directo a la instalación del esquema. El script
requiere Bash y Python 3. Crea el usuario `SGCD19` en `FREEPDB1` si falta y carga los scripts
`10`, `11` y `12a`–`12j` si el esquema está vacío. Si el esquema ya contiene objetos, verifica
las tablas y los paquetes. El esquema legado `SGCD` y el volumen existente se conservan.

```sh
bash infra/inicializar-oracle-local.sh
docker compose up -d --no-deps app
docker compose ps
```

La conexión local desde el host es `127.0.0.1:1521/FREEPDB1`, usuario `SGCD19`. La aplicación
usa el servicio interno `oracle` y la clave definida en `SGCD_DB_PASSWORD`.

Para incorporar cambios de los paquetes y mantenedores en un `SGCD19` ya instalado, recompila
los scripts `12a`–`12j` con el siguiente comando. Las tablas y los catálogos se conservan.

```sh
bash infra/inicializar-oracle-local.sh --actualizar-paquetes
```

Si quieres el lote ficticio de clientes, reservas, pagos e inscripciones para la entrega, cárgalo
explícitamente en la instancia de demostración. El script `15` conserva los datos previos y reconoce
el lote si ya se cargó.

```sh
bash infra/inicializar-oracle-local.sh --datos-demo
```

## Entradas y cuentas de laboratorio

- [Portal de clientes](http://127.0.0.1:8080/cliente/)
- [Panel administrativo](http://127.0.0.1:8080/dashboardadmin/)

| Usuario | Clave inicial | Acceso |
| --- | --- | --- |
| `admin` | `admin` | Panel administrativo, confirmaciones, pagos y catálogos |
| `demo` | `SGCDdemo2026` | Portal de clientes |
| `nuevo` | `SGCDdemo2026` | Portal de clientes |

Las credenciales iniciales vienen del catálogo de pruebas. Si ya cambiaste una clave, usa la vigente.

## Recorrido

1. Ingresa al portal con una cuenta cliente. Selecciona una cancha y solicita uno o más bloques de una hora.
2. Ingresa al panel en otra sesión y confirma la solicitud. Comprueba allí la agenda y registra el pago cuando corresponda.
3. Vuelve al portal y abre el detalle de la reserva para ver la confirmación.
4. Consulta la programación de un torneo y prueba una inscripción si quedan cupos y el plazo está abierto.

Para el despliegue en la torre, consulta [la guía de Apache y PHP-FPM](../../infra/DESPLIEGUE_WEB.md).
Para el esquema y las pruebas, consulta [la guía de scripts Oracle](../../sql/README.md).
