# Ejercicio 2.6. Acción referencial al borrar un veterinario

**Nombre:** Jose Luis Espinosa Ramirez  
**Proyecto:** Modelo Entidad Relación de un refugio de animales  
**Relación elegida:** `veterinario` – `atencion_medica`  
**Llave foránea:** `fk_atencion_veterinario`  
**Motor:** PostgreSQL

## Objetivo

Comparar qué ocurre al borrar un veterinario cuando la llave foránea desde `atencion_medica.id_persona` usa `ON DELETE SET NULL` (regla actual del modelo) y cuando se cambia temporalmente a `ON DELETE CASCADE`.

## Datos y procedimiento

La prueba se realizó en una copia de la base. Se eligió un veterinario que tenía atenciones médicas asociadas y se guardaron las llaves de esas atenciones para poder contarlas después del borrado.

Primero se borró al veterinario con la regla actual `SET NULL`. Después se revirtió ese escenario y se volvió a probar el borrado con la llave foránea cambiada a `CASCADE`. El SQL ejecuta ambos escenarios dentro de una transacción y termina con `ROLLBACK`, por lo que la copia queda sin cambios al finalizar.

## Resultados

El veterinario elegido fue `id_persona = [resultado del SQL]` y tenía **[N] atenciones médicas** asociadas antes de la prueba.

| Acción al borrar al veterinario | Atenciones conservadas | Atenciones perdidas | Efecto observado |
|---|---:|---:|---|
| `SET NULL` | [N] | 0 | Las atenciones permanecen; `id_persona` queda en `NULL`. |
| `CASCADE` | 0 | [N] | Se eliminan las atenciones asociadas y también sus detalles dependientes. |

Con `CASCADE`, el SQL también reportó **[N] vacunaciones**, **[N] cirugías** y **[N] tratamientos** restantes entre los detalles vinculados a las atenciones seleccionadas. Anota aquí los valores que muestre tu ejecución.

## Análisis y decisión

`SET NULL` conserva el historial clínico de los animales aunque se elimine el registro del veterinario. Se pierde únicamente la asociación con esa persona. En cambio, `CASCADE` elimina las atenciones que estaban asociadas al veterinario y, por las llaves foráneas en cascada de `vacunacion`, `cirugia` y `tratamiento`, puede borrar también esos detalles médicos.

Para el dominio del refugio, la opción más adecuada es **`ON DELETE SET NULL`**. El registro de una atención médica sigue siendo relevante para el historial del animal aunque el veterinario deje de estar registrado. `CASCADE` permitiría borrar esa información clínica al eliminar al profesional.

## Conclusión

La prueba mostró que la acción referencial determina cuánto historial se conserva al borrar un registro padre. `SET NULL` desvincula al veterinario y conserva las atenciones; `CASCADE` elimina las atenciones y sus detalles. Por la importancia del historial médico, se recomienda mantener `SET NULL` para esta relación.

**Nota:** sustituye los campos entre corchetes por el `id` y los conteos reales que arroje la ejecución del SQL. No reportes cantidades supuestas.
