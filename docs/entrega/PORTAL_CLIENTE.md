# Portal de clientes SGCD

La demo funciona con PHP 8.4 o superior y Bootstrap. En Docker, el portal de clientes se abre en [localhost:8080](http://localhost:8080/). También se puede ejecutar desde la raíz con `php -S 127.0.0.1:8091 -t web` y abrir [localhost:8091](http://127.0.0.1:8091/). Este segundo modo permite probar el portal sin Docker ni Oracle. El acceso del personal está en `/dashboardadmin`.

| Cuenta | Clave de demo | Permisos de ejemplo |
| --- | --- | --- |
| `demo` | `SGCDdemo2026` | Solicitar, consultar y cancelar sus reservas elegibles. |
| `nuevo` | `SGCDdemo2026` | Consultar sus reservas desde el inicio. Puede tener una solicitud pendiente hasta que recepción confirme la primera. |

El registro también admite un usuario ficticio nuevo con RUT válido de prueba, como `12.345.678-5`. Las cuentas y el historial de prueba quedan en la sesión PHP del navegador. La bandeja de solicitudes y su estado se guardan en un archivo temporal de la instancia. La disponibilidad de la maqueta combina los datos de cada sesión con los bloques de torneo compartidos para las canchas compatibles; la integración con Oracle debe compartir los bloqueos entre clientes y personal. Usa el puerto 8080 para probar cliente y personal en el mismo entorno Docker.

## Recorrido de prueba

1. Seleccionar Pádel dobles y buscar la fecha sugerida con la duración inicial de 60 minutos.
2. Elegir Pádel 1 a las 18:00 y comprobar el total de $18.000 CLP. A las 17:30 el bloque cruza dos franjas y cuesta $17.000.
3. Ingresar con `demo`, revisar y enviar. Se genera un código con estado pendiente de confirmación.
4. Abrir «Mis reservas», entrar al detalle y confirmar la cancelación. Buscar otra vez para comprobar que se liberó el horario.
5. Probar Las Rastras un lunes para ver el estado sin disponibilidad. En «Ayuda → Controles de la demo» se pueden simular un horario ocupado, un cambio de tarifa, una sesión vencida y un error temporal. El reinicio limpia esa sesión y sus solicitudes de reserva en la bandeja. Las inscripciones a torneos se gestionan desde Mis inscripciones.

Para probar una cuenta nueva, ingresa con `nuevo`, envía una solicitud y abre **Mis reservas**. Verás la primera solicitud y el aviso que limita nuevos envíos. En el panel de personal, abre **Reservas → Solicitudes web** y confirma esa reserva. Al volver a **Mis reservas**, se muestra como confirmada y se pueden enviar nuevas solicitudes. Si se cancela antes de confirmarla, el cliente puede enviar un reemplazo.

Las pruebas del servicio se ejecutan con `php tests/portal-cliente.php`.

## Inscripción a torneos

Abre [Torneos del portal](http://127.0.0.1:8080/?vista=torneos) y selecciona **Torneo Pádel Mixto**. Puedes entrar con `demo` y la clave de esta guía. Este torneo pide un compañero, con nombre completo y un RUT ficticio válido como `22.222.222-2`. Revisa la plantilla y confirma. Desde **Mis inscripciones** puedes ver, editar o retirar el equipo mientras siga abierta la edición.

En [el panel de torneos](http://127.0.0.1:8080/dashboardadmin/#torneos), abre el mismo torneo y pulsa **Ver equipos**. El equipo aparece en la plantilla y consume un cupo. La agenda del torneo también se publica en el portal. Usa el **puerto 8080 para ambos paneles** cuando pruebes la sincronización en Docker.

El almacenamiento de torneos de la demo vive temporalmente en el servidor PHP. En una instancia aún sin cambios compartidos, el personal puede recuperar datos previos con **Recuperar torneos de este navegador** cuando exista la copia local. Las cuentas registradas en la demo pertenecen a la sesión del navegador. Las inscripciones web de esas cuentas se identifican además con una identidad de sesión para distinguir registros ficticios del mismo RUT.

Las pruebas de reglas y cupos concurrentes se ejecutan con `php tests/torneos-cliente.php`. La migración y el contrato para conectar el flujo real están en [Inscripción a torneos con Oracle](TORNEOS_ORACLE.md).

## Duración de las reservas web

El Administrador configura una duración por modalidad en **Duración de reservas** dentro de `/dashboardadmin/`. La demo parte con 60 minutos y admite entre 30 y 180 en tramos de 30. El portal muestra esa duración en la búsqueda y calcula con ella el horario de término y el total. Cada reserva guardada conserva su duración original.

PHP comparte esta configuración entre panel y portal mediante un archivo temporal de la instancia. Para la integración, persistir la configuración en Oracle y resolver la duración en PHP al consultar, cotizar y crear reservas. Restringir los cambios al rol ADMINISTRADOR.

## Guías para conectar el backend

- [Reservas web y cuenta de cliente](RESERVAS_ORACLE.md)
- [Inscripciones a torneos](TORNEOS_ORACLE.md)
- [Mapa general e instrucciones para el agente de integración](INTEGRACION_BACKEND.md)
