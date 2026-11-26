# Recorridos del portal de clientes SGCD

Abre el [portal](http://127.0.0.1:8080/) y el [panel administrativo](http://127.0.0.1:8080/dashboardadmin/) en la misma instancia Docker. Ambos requieren PHP con OCI8 y el esquema Oracle de 19 tablas. Las credenciales y la instalación están en [ACCESO_DEMO.md](ACCESO_DEMO.md).

| Cliente de prueba | Clave | Caso |
| --- | --- | --- |
| `demo` | `SGCDdemo2026` | Cliente con datos de ejemplo en su historial. |
| `nuevo` | `SGCDdemo2026` | Cliente que puede solicitar varias reservas desde que inicia sesión. |

El registro acepta un nuevo usuario de prueba con un RUT válido, por ejemplo `12.345.678-5`. Usa sólo datos ficticios.

## Reservar uno o varios bloques

1. Selecciona una modalidad. El catálogo de Las Rastras muestra las seis canchas de Fútbol 6, la cancha grande y ejemplos provisionales de pádel y tenis.
2. En **Buscar disponibilidad**, elige fecha y cantidad de bloques consecutivos de una hora. El recinto aparece como dato del catálogo. El lunes está cerrado en la demo.
3. Elige el horario de inicio de una cancha disponible. Para comprobar una cotización con dos franjas, elige **Pádel 1** entre las 17:00 y las 19:00 en una fecha libre. El total de ejemplo es $34.000 por las franjas de $16.000 y $18.000.
4. Inicia sesión o crea una cuenta, revisa el total y envía. El portal entrega un código y marca la solicitud **Pendiente de confirmación**.
5. Envía una segunda solicitud en otro horario. Desde **Reservas → Solicitudes web**, un administrador puede confirmar una de ellas. En **Mis reservas**, la confirmada cambia de estado y la otra sigue pendiente.
6. Cancela una reserva futura desde su detalle y comprueba que el horario se puede volver a solicitar. Para revisar el reparto de canchas, reserva la grande y comprueba que las canchas 1, 2 y 3 queden bloqueadas. Las canchas 4, 5 y 6 mantienen disponibilidad propia.

Verifica los conflictos con una reserva existente en Oracle. Las inscripciones se administran desde **Mis inscripciones**.

## Inscribir un equipo

1. Abre [Torneos](http://127.0.0.1:8080/?vista=torneos) y elige un evento con inscripciones abiertas. Revisa sus horarios, cupos y máximo de jugadores.
2. Inicia sesión, si corresponde. El portal vuelve al torneo y asigna al titular de la cuenta como capitán.
3. Ingresa el nombre del equipo y añade sólo los compañeros que van a jugar. Para cada integrante adicional se pide nombre y RUT con DV. Por ejemplo, **Torneo Pádel Mixto** admite hasta dos personas en la demo, incluido el capitán. El formulario permite guardar al capitán solo o agregar un compañero.
4. Revisa y guarda. **Mis inscripciones** muestra el equipo y su plantilla. Editar o retirar depende del plazo y estado de la competencia.
5. Desde **Torneos → Ver equipos** del panel, recepción puede revisar la inscripción y el cupo consumido.

## Datos compartidos

Ambos paneles consultan el mismo Oracle. Una solicitud web queda disponible en la agenda administrativa. La programación de un torneo y las reservas de mostrador afectan la disponibilidad del portal. Las tarifas y horarios editados desde administración se aplican al volver a consultar.

Para conectar el sistema, sigue la [guía principal](INTEGRACION_BACKEND.md), el [contrato de reservas](RESERVAS_ORACLE.md) y el [contrato de torneos](TORNEOS_ORACLE.md).
