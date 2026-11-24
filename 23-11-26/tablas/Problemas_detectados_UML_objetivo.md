# Revisión del UML objetivo — problemas y correcciones recomendadas

**Proyecto:** Sistema de gestión de un recinto deportivo  
**Documentos revisados:** `UML_objetivo.mdj` y `README.md` entregados por el equipo.  
**Alcance de la revisión:** modelo conceptual y coherencia funcional; **no** se ha compilado ni probado SQL en Oracle.

## Prioridad alta — resolver antes de implementar

| N.º | Hallazgo | Por qué importa | Recomendación |
|---|---|---|---|
| **1** | **El módulo de torneos desapareció del modelo.** No hay entidades para torneos, jugadores, equipos, inscripciones o partidos. El README excluye el *fixture y torneos complejos*. | Anteriormente se acordó incorporar la organización de torneos por indicación del profesor. El UML actual no permite demostrarla. | Confirmar si el profesor aprobó reducir el alcance. Si no, reintroducir al menos las entidades y operaciones mínimas para organizar torneos. |
| **2** | **Se separaron nuevamente `USUARIO`, `CLIENTE` y `ADMINISTRADOR`.** | Contradice la decisión previa de usar un solo `USUARIO` con rol. Además, `ID_USUARIO` en `CLIENTE` y `ADMINISTRADOR` no tiene restricción `UNIQUE` declarada en el MDJ: el modelo permite más de una ficha asociada a una cuenta. | Preferir una sola entidad `USUARIO` con roles y credenciales opcionales para clientes presenciales, **o** documentar por qué se requieren subentidades y definir cardinalidades y unicidad explícitas. |
| **3** | **La relación `RECINTO` → `HORARIO` no coincide con los atributos.** | La relación documenta la FK `ID_RECINTO`, pero `HORARIO` no contiene ese atributo. | Añadir `ID_RECINTO` a `HORARIO` o quitar esa relación y explicar que el horario es una configuración global de un solo recinto. |
| **4** | **La disponibilidad de las canchas combinadas no está garantizada por el modelo.** | `CANCHA_COMPONENTE` representa que la cancha grande se forma con las canchas 1, 2 y 3, pero no impide reservar una componente mientras está reservada la cancha grande, ni a la inversa. | Definir una única validación transaccional de solapes considerando todas las canchas físicas implicadas. Probar reservas simultáneas y bloqueos cruzados. |

## Prioridad media — ajustar reglas y restricciones

| N.º | Hallazgo | Por qué importa | Recomendación |
|---|---|---|---|
| **5** | **`BLOQUE_HORARIO` tiene `ESTADO_BLOQUE`, pero no fecha ni cancha.** | El mismo bloque puede estar ocupado un día y disponible al siguiente; un estado fijo en la plantilla no representa esa realidad. | Usar los bloques como plantilla de horas y calcular la disponibilidad real a partir de reservas vigentes; no guardar `OCUPADO` como estado global. |
| **6** | **Las tarifas mezclan cancha y modalidad.** `TARIFA` incluye `ID_CANCHA`, `ID_MODALIDAD`, día y franja. | Puede ser más complejo de lo necesario si los precios solo dependen de cancha, día y hora; también podría permitir combinaciones de cancha/modalidad no habilitadas. | Definir explícitamente si la modalidad afecta el precio. Si no, retirar `ID_MODALIDAD`; si sí, validar que la pareja cancha-modalidad exista. Prevenir tarifas superpuestas en vigencia y horario. |
| **7** | **`RESERVA` referencia por separado `CANCHA` y `MODALIDAD`.** | Dos claves foráneas independientes no garantizan que esa modalidad esté habilitada para esa cancha. | Validar la pareja contra `CANCHA_MODALIDAD` (mediante relación/restricción o lógica del servicio). |
| **8** | **Faltan restricciones de identidad explícitas.** | En el MDJ, `RUT_CLIENTE` e `ID_USUARIO` en `CLIENTE` no están marcados como `UNIQUE`; `ID_USUARIO` en `ADMINISTRADOR` tampoco. | Definir unicidad de RUT y, si se mantienen fichas separadas, unicidad de su relación con `USUARIO`. Validar el dígito verificador del RUT. |
| **9** | **Los pagos necesitan reglas financieras claras.** | `PAGO` tiene importe, estado y medio, pero el modelo por sí solo no establece cómo controlar pagos parciales, anulaciones o saldos. | Mantener `PAGO` como movimientos asociados a `RESERVA`; calcular el saldo desde el importe acordado y pagos aplicables, sin duplicarlo. Precisar estados y devoluciones. |
| **10** | **El sistema usa bloques fijos de una hora.** | El README lo establece, pero anteriormente se habían acordado intervalos configurables y selección manual. | Si el equipo decidió simplificar deliberadamente, documentarlo como cambio de alcance; si no, revisar la compatibilidad con reservas de duración variable. |

## Prioridad académica — presentación y normalización

| N.º | Hallazgo | Recomendación |
|---|---|---|
| **11** | **La transición de 2FN a 3FN no está suficientemente demostrada.** El modelo de 2FN tiene 14 entidades y el de 3FN tiene 15: la principal incorporación es `AUDITORIA_CLIENTE`. | Documentar dependencias funcionales y explicar por qué las entidades satisfacen 1FN, 2FN y 3FN. Añadir auditoría no demuestra por sí mismo una normalización de 2FN a 3FN. |
| **12** | **El UML objetivo no equivale todavía a la implementación actual.** El README indica que el siguiente paso es adaptar DDL, paquetes PL/SQL y pantallas PHP. | No afirmar que el modelo ya está implementado. Planificar la adecuación y probarlo sobre una base de laboratorio antes de sustituir código existente. |

## Aspectos que conviene conservar

- **Un único recinto**, con fútbol, tenis y pádel.
- **Clientes web y presenciales**: `CLIENTE.ID_USUARIO` es opcional en el MDJ, lo cual permite fichas sin cuenta. El problema no es esa opcionalidad, sino la duplicación potencial y la falta de restricciones de relación.
- **`CANCHA_COMPONENTE`**, porque representa una necesidad concreta del establecimiento.
- **Separación entre `RESERVA` y `PAGO`**, útil para abonos parciales y para conservar el precio histórico.
- **Auditoría de clientes**, si se adapta correctamente al modelo de usuarios finalmente elegido.

## Orden recomendado de corrección

1. Cerrar formalmente si **torneos** sigue siendo requisito de la entrega.
2. Elegir de forma consistente el modelo de **usuarios** y fijar sus restricciones de identidad.
3. Arreglar la relación **`HORARIO`–`RECINTO`**.
4. Diseñar la validación de **reservas simultáneas de canchas individuales y combinadas**.
5. Ajustar **bloques, tarifas, modalidad y pagos**.
6. Justificar **3FN** y recién después traducir el modelo a SQL y PL/SQL.

---

**Datos verificados del archivo:** el modelo objetivo final contiene **15 entidades, 79 atributos y 18 relaciones**. Las observaciones marcadas como «recomendación» son decisiones de diseño propuestas; no deben confundirse con errores de compilación ya constatados.
