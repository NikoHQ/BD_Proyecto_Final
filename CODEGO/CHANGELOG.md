# CODEGO — registro de entregables actualizados

Carpeta aparte con **todo lo que vamos actualizando** del proyecto. No es fuente de verdad:
lo canónico vive en su ruta normal del repo (`sql/oracle/`, `sql/sqlite/`, `infra/`…).
Aquí se guarda una copia **en la misma ruta relativa**, para que se pueda entregar o revisar
sin tocar los originales.

## Reglas

1. Un archivo por ruta canónica. Ruta espejo: `CODEGO/<misma ruta que en el repo>`.
2. Cada actualización **sobrescribe** el espejo y **agrega una entrada** abajo con fecha.
3. Los espejos no se editan a mano: si algo cambia, se cambia en la ruta canónica y se vuelve a copiar.
4. Lo recibido de terceros (`17-11-26/`) no se copia aquí; solo lo que producimos nosotros.
5. El historial real es git; este archivo es el índice legible.

---

## 2026-11-17 — Corrección del modelo 17 tablas contra `17-11-26/`

**Contexto.** El archivo recibido (`tablas.sql` + `correccion_gpt.mdj`) resultó ser el mismo
modelo 3FN de 17 tablas que nuestro `UML.mdj`, renombrado `SGCD_*`, más un DDL Oracle que
nuestro repo no tenía. Se absorben 3 atributos que nos faltaban (`clave_hash`/`perfil`,
`estado_reserva`, `descuento_porcentaje`) y se corrige el DDL.

**Archivos**

| Ruta | Qué es |
|---|---|
| `sql/oracle/01_ddl_sgcd_corregido.sql` | DDL Oracle 23ai, 17 tablas + 15 índices. `IDENTITY`, `NOT NULL` completo, `NUMBER(12,2)`, `CHAR(5)`+`REGEXP_LIKE`, `TIMESTAMP`, 7 `UNIQUE`, 8 `CHECK` de rango, XOR de 3 ramas en `PAGOS`, `TIPO_CANCHA`, índice único por función para el bloque de reserva ignorando `CANCELADA`. |
| `sql/oracle/ANALISIS_17-11-26_vs_nuestro.md` | Diferencias, defectos C-01…C-20 con evidencia, contradicciones internas (D-2…D-5) y decisiones abiertas (D-1…D-4). |

**Validación.** 32/32 sentencias parseadas con `sqlglot` dialecto `oracle`
(`PYTHONPATH=/tmp/opencode/pylibs`). Sin compilar en Oracle real: el contenedor `oracle-free`
está apagado.

**Pendiente de Naiko.** D-1 `IDENTITY` vs secuencia+trigger · D-2 `CANCHA` vs `INSTALACION` ·
D-3 horario por recinto vs por instalación · D-4 agregar `BLOQUEO_CANCHA` (18ª tabla).
