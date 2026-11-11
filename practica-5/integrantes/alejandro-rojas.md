# Ejercicio 2.6. Trabajo individual — Acción referencial

**Integrante:** Alejandro Rojas (Zona A: personas y hogares)
**Prácticas 4 y 5 · Proyecto propio (RedHuella) · Gestor: PostgreSQL**
**Script:** `alejandro-rojas.sql`, en esta misma carpeta

## 1. Relación elegida

| | |
|---|---|
| **Relación (modelo EER, Práctica 3)** | **es responsable de** (Persona — Hogar temporal) |
| **Tabla hija** | `hogar_temporal` |
| **Tabla padre** | `persona` |
| **Restricción** | `fk_hogar_persona` (`hogar_temporal.id_persona` → `persona.id_persona`) |
| **Acción original** | `ON DELETE RESTRICT` (definida en `esquema.sql`) |
| **Acción de prueba** | `ON DELETE CASCADE` |

Elegí **es responsable de** porque es una de las relaciones que modelé en la zona A (Práctica 3) y porque cada hogar arrastra otras tablas: `hogar_especie` (las especies que acepta) y `estancia` (los animales que ha recibido). Por eso, la acción referencial no afecta solo a una tabla.

## 2. Cómo se probó

La prueba se hizo **en una copia de la base**, nunca en la del equipo:

```bash
createdb -T <base_del_equipo> copia_26_alejandro
psql -d copia_26_alejandro -f alejandro-rojas.sql
```

La base parte de `esquema.sql` + `migraciones/001-dominios.sql`. Además, el script corre dentro de una transacción que termina en `ROLLBACK`, así que ni siquiera la copia queda modificada.

**Datos de prueba:**

| Persona | Rol | Hogar a su cargo | ¿El hogar tiene estancias? |
|---|---|---|---|
| 9101 Marta Ríos | rescatista, responsable | 9101 "Casa Marta" (acepta perro y gato) | **Sí**: la perrita Pimienta, colocada por Sofía |
| 9102 Raúl Mendoza | rescatista, responsable | 9102 "Casa Raúl" (acepta perro y gato) | No |
| 9103 Sofía Navarro | rescatista | — | — |

El cambio de acción en la copia se hizo así:

```sql
ALTER TABLE hogar_temporal DROP CONSTRAINT fk_hogar_persona;
ALTER TABLE hogar_temporal ADD CONSTRAINT fk_hogar_persona
    FOREIGN KEY (id_persona) REFERENCES persona (id_persona)
    ON DELETE CASCADE ON UPDATE CASCADE;
```

Para confirmarlo se consultó `pg_constraint`, que devolvió `confdeltype = 'c'` (cascade).

## 3. Resultados con datos

Renglones de prueba en cada tabla:

| Tabla | Inicial | A. RESTRICT, borrar a Raúl | B. CASCADE, borrar a Raúl | C. CASCADE, borrar a Marta |
|---|---|---|---|---|
| persona | 3 | 3 | **2** | 2 |
| rescatista | 3 | 3 | **2** | 2 |
| hogar_temporal | 2 | 2 | **1** | 1 |
| hogar_especie | 4 | 4 | **2** | 2 |
| estancia | 1 | 1 | 1 | 1 |
| **Resultado** | | **Rechazado** | **Borrado en cascada** | **Rechazado** |

### A. Con `RESTRICT` (acción original): borrar a Raúl

```sql
DELETE FROM persona WHERE id_persona = 9102;
```

```text
ERROR:  update or delete on table "persona" violates foreign key constraint "fk_hogar_persona" on table "hogar_temporal"
DETAIL:  Key (id_persona)=(9102) is still referenced from table "hogar_temporal".
```

- **Qué se pierde:** nada.
- **Qué se conserva:** todo. El gestor obliga a decidir primero qué pasa con el hogar.

### B. Con `CASCADE`: borrar a Raúl (su hogar no tiene estancias)

```sql
DELETE FROM persona WHERE id_persona = 9102;   -- DELETE 1
```

Un solo `DELETE` sobre `persona` quitó **6 renglones en 4 tablas**:

- **Qué se pierde:** Raúl (`persona`), su registro de rescatista (`rescatista`, que ya tenía CASCADE desde la Práctica 3), su hogar "Casa Raúl" (`hogar_temporal`) y las 2 especies que aceptaba (`hogar_especie`, CASCADE hacia el hogar). El gestor no muestra ningún aviso: la salida solo dice `DELETE 1`.
- **Qué se conserva:** Marta, Sofía, el hogar de Marta y la estancia de Pimienta.

### C. Con `CASCADE`: borrar a Marta (su hogar sí tiene una estancia)

```sql
DELETE FROM persona WHERE id_persona = 9101;
```

```text
ERROR:  update or delete on table "hogar_temporal" violates foreign key constraint "fk_estancia_hogar" on table "estancia"
DETAIL:  Key (id_hogar)=(9101) is still referenced from table "estancia".
```

- **Qué se pierde:** nada. La cascada intenta borrar el hogar de Marta, pero choca con `fk_estancia_hogar`, que es `RESTRICT`, y el gestor deshace la operación completa.
- **Qué se conserva:** todo, incluida la estancia de Pimienta.

Esto muestra que la acción de una llave foránea no actúa sola: la cascada avanza hasta que encuentra la primera restricción que la detiene. Con `CASCADE`, borrar al responsable depende de si su hogar ya se usó o no, algo que quien hace el borrado no ve.

## 4. ¿Cuál es la correcta para el dominio?

**`ON DELETE RESTRICT`, la acción original.**

1. **Un hogar temporal no le pertenece solo a su responsable.** Tiene dirección, capacidad y especies aceptadas, y puede volver a usarse con otro responsable. Si se borra junto con la persona, se pierde información de la red de rescate que nadie pidió borrar.
2. **El borrado en cascada es silencioso.** En el caso B, un `DELETE 1` quitó 6 renglones en 4 tablas sin ningún aviso. Si se equivoca el id, se pierde un hogar completo.
3. **CASCADE se comporta distinto según el hogar.** Como muestra el caso C, si el hogar ya recibió animales, la operación falla igual, por `fk_estancia_hogar`. Es decir, CASCADE no protege el historial: solo borra los hogares que todavía no se han usado, y lo hace sin avisar.
4. **El dominio ya tiene una alternativa sin borrar:** `hogar_temporal.activo`. Cuando un responsable se va, se reasigna el hogar a otra persona (`UPDATE hogar_temporal SET id_persona = ...`) o se marca `activo = FALSE`. Después ya se puede borrar a la persona.

`CASCADE` sí sería correcto en una relación de dependencia total, como `hogar_especie → hogar_temporal`, donde las especies aceptadas no tienen sentido sin su hogar. Por eso esa relación ya tiene `CASCADE` en el esquema.

## 5. Pregunta probable en clase

**¿Por qué no `SET NULL`?** Porque `hogar_temporal.id_persona` es `NOT NULL`: la cardinalidad mínima es 1 y todo hogar necesita un responsable. Con `SET NULL`, borrar a la persona fallaría con un error de NOT NULL. Ese error sería el mismo freno que RESTRICT, pero con un mensaje menos claro.
