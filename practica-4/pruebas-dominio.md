# Pruebas de restricciones de dominio — Proyecto Propio (RedHuella)

Ejercicio 1.5 · Prácticas 4 y 5 · Gestor: PostgreSQL

Diez casos que intentan violar las restricciones declaradas en `esquema.sql` (Práctica 3) y en `migraciones/001-dominios.sql` (ejercicios 1.1 y 1.2). Cubren NOT NULL, DEFAULT, UNIQUE simple, compuesta y parcial, y CHECK de rango, de formato, de lista de valores y entre columnas.

## Cómo se ejecutan

Todas las sentencias están en `pruebas-dominio.sql`, junto a este archivo:

```bash
psql -U postgres -d postgres -f esquema.sql
psql -U postgres -d postgres -f migraciones/001-dominios.sql
psql -U postgres -d postgres -f pruebas-dominio.sql
```

El script trabaja dentro de **una sola transacción que termina en `ROLLBACK`**, así que la base queda igual que antes y se puede ejecutar las veces que haga falta. Con `\set ON_ERROR_ROLLBACK on`, psql deshace solo la sentencia que falla y continúa con el caso siguiente.

Antes de los casos se insertan unos datos base válidos, con ids desde 9001 para no chocar con la carga:

```sql
INSERT INTO zona (id_zona, colonia, municipio, entidad)
VALUES (9001, 'Centro', 'Cuauhtémoc', 'Ciudad de México');

INSERT INTO persona (id_persona, nombres, ap_paterno, ap_materno, telefono, correo)
VALUES (9001, 'Ana', 'López', 'Ruiz', '5512345678', 'ana.lopez@ejemplo.com'),
       (9002, 'Luis', 'Pérez', NULL, '5587654321', 'luis.perez@ejemplo.com');

INSERT INTO adoptante (id_persona, tipo_vivienda, tiene_patio, otras_mascotas)
VALUES (9001, 'casa', TRUE, FALSE),
       (9002, 'departamento', FALSE, TRUE);

INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9001, 'Bajo el puente de Eje Central', '2026-09-10 08:30', 'Deshidratado', 'rescate_en_calle', 9001);

INSERT INTO animal (id_animal, nombre, especie, sexo, id_rescate)
VALUES (9001, 'Canela', 'perro', 'hembra', 9001);

INSERT INTO adopcion (id_animal, id_persona, fecha_adopcion)
VALUES (9001, 9001, '2026-10-01');
```

## Resumen

| # | Tipo de restricción | Restricción | Resultado esperado | Resultado obtenido |
|---|---|---|---|---|
| 1 | NOT NULL | `persona.ap_paterno` | Rechazo | Rechazo ✔ |
| 2 | DEFAULT | `animal.estado_actual`, `persona.fecha_registro` | Se acepta con el valor por omisión | Aceptado ✔ |
| 3 | UNIQUE simple | `uq_persona_correo` | Rechazo | Rechazo ✔ |
| 4 | UNIQUE compuesta | `uq_zona_ubicacion` | Rechazo | Rechazo ✔ |
| 5 | UNIQUE parcial | `ux_adopcion_vigente` | Rechazo | Rechazo ✔ |
| 6 | CHECK de rango | `ck_rescate_fecha_hora` | Rechazo | Rechazo ✔ |
| 7 | CHECK de formato (dominio) | `ck_d_telefono_formato` | Rechazo | Rechazo ✔ |
| 8 | CHECK de formato | `ck_persona_correo_formato` | Rechazo | Rechazo ✔ |
| 9 | CHECK de lista de valores | `ck_rescate_tipo_ingreso` | Rechazo | Rechazo ✔ |
| 10 | CHECK entre columnas | `ck_seguimiento_fecha` | Rechazo | Rechazo ✔ |

---

## Caso 1. NOT NULL — persona sin apellido paterno

**Operación intentada:** registrar a una persona sin apellido paterno.

```sql
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9003, 'María', NULL, '5511112222');
```

**Resultado esperado:** rechazo; `ap_paterno` es `NOT NULL`.

**Mensaje del gestor:**

```text
ERROR:  null value in column "ap_paterno" of relation "persona" violates not-null constraint
DETAIL:  Failing row contains (9003, María, null, null, 5511112222, null, 2026-11-05).
```

**Regla protegida:** todo registro de persona necesita al menos un apellido para poder identificarla.

---

## Caso 2. DEFAULT — animal y persona sin estado ni fecha de registro

**Operación intentada:** registrar un animal sin indicar `estado_actual` y una persona sin indicar `fecha_registro`.

```sql
INSERT INTO animal (id_animal, nombre, especie, sexo, id_rescate)
VALUES (9002, 'Tizón', 'gato', 'macho', 9001);

INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9004, 'Jorge', 'Díaz', '5533334444');

SELECT id_animal, nombre, estado_actual FROM animal WHERE id_animal = 9002;
SELECT id_persona, nombres, fecha_registro = CURRENT_DATE AS registrado_hoy
FROM persona WHERE id_persona = 9004;
```

**Resultado esperado:** se aceptan. Las dos columnas son `NOT NULL`, pero el gestor llena el valor por omisión: `'rescatado'` y la fecha del día.

**Mensaje del gestor:**

```text
INSERT 0 1
INSERT 0 1
 id_animal | nombre | estado_actual
-----------+--------+---------------
      9002 | Tizón  | rescatado

 id_persona | nombres | registrado_hoy
------------+---------+----------------
       9004 | Jorge   | t
```

**Regla protegida:** un animal recién ingresado queda como "rescatado", y una persona se registra el día en que se da de alta.

---

## Caso 3. UNIQUE simple — dos personas con el mismo correo

**Operación intentada:** registrar a una segunda persona con el correo de Ana López.

```sql
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono, correo)
VALUES (9005, 'Ana María', 'Soto', '5599990000', 'ana.lopez@ejemplo.com');
```

**Resultado esperado:** rechazo por `uq_persona_correo`.

**Mensaje del gestor:**

```text
ERROR:  duplicate key value violates unique constraint "uq_persona_correo"
DETAIL:  Key (correo)=(ana.lopez@ejemplo.com) already exists.
```

**Regla protegida:** un correo identifica a una sola persona; si dos personas lo compartieran, los avisos de adopción y seguimiento llegarían a quien no corresponde.

---

## Caso 4. UNIQUE compuesta — la misma colonia dos veces

**Operación intentada:** registrar de nuevo la colonia Centro de la alcaldía Cuauhtémoc.

```sql
INSERT INTO zona (id_zona, colonia, municipio, entidad)
VALUES (9002, 'Centro', 'Cuauhtémoc', 'Ciudad de México');
```

**Resultado esperado:** rechazo por `uq_zona_ubicacion` sobre `(colonia, municipio, entidad)`. Por separado, cada valor sí puede repetirse (hay colonias Centro en muchos municipios); lo que no se repite es la combinación.

**Mensaje del gestor:**

```text
ERROR:  duplicate key value violates unique constraint "uq_zona_ubicacion"
DETAIL:  Key (colonia, municipio, entidad)=(Centro, Cuauhtémoc, Ciudad de México) already exists.
```

**Regla protegida:** una colonia de un municipio y entidad se registra una sola vez; si no, los rescates de la misma zona quedarían repartidos en dos ids y los conteos por zona saldrían mal.

---

## Caso 5. UNIQUE parcial — un animal adoptado por dos personas a la vez

**Operación intentada:** registrar que Luis Pérez adopta a Canela mientras la adopción de Ana López sigue vigente.

```sql
INSERT INTO adopcion (id_animal, id_persona, fecha_adopcion)
VALUES (9001, 9002, '2026-10-15');
```

**Resultado esperado:** rechazo por el índice único parcial `ux_adopcion_vigente`, que solo permite una adopción con `fecha_devolucion IS NULL` por animal. La clave primaria no lo impide, porque cambia `id_persona`.

**Mensaje del gestor:**

```text
ERROR:  duplicate key value violates unique constraint "ux_adopcion_vigente"
DETAIL:  Key (id_animal)=(9001) already exists.
```

**Regla protegida:** un animal no puede estar adoptado por dos personas al mismo tiempo; para volver a adoptarlo, primero se registra la devolución.

---

## Caso 6. CHECK de rango — rescate con fecha en el futuro

**Operación intentada:** registrar un rescate con fecha de dentro de tres días.

```sql
INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9002, 'Parque Alameda', LOCALTIMESTAMP + INTERVAL '3 days', 'Herido', 'reporte_ciudadano', 9001);
```

**Resultado esperado:** rechazo por `ck_rescate_fecha_hora` (`fecha_hora <= LOCALTIMESTAMP`).

**Mensaje del gestor:**

```text
ERROR:  new row for relation "rescate" violates check constraint "ck_rescate_fecha_hora"
DETAIL:  Failing row contains (9002, Parque Alameda, 2026-11-08 02:23:54.66625, Herido, reporte_ciudadano, 9001).
```

**Regla protegida:** un rescate no puede haber ocurrido en el futuro; una fecha así es un error de captura.

---

## Caso 7. CHECK de formato (dominio) — teléfono con letras

**Operación intentada:** registrar a una persona con un teléfono que contiene letras.

```sql
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9006, 'Carla', 'Vega', '55ABC12345');
```

**Resultado esperado:** rechazo por el dominio `d_telefono`, cuyo CHECK exige exactamente 10 dígitos. El valor mide 10 caracteres, así que lo que falla es el formato, no la longitud.

**Mensaje del gestor:**

```text
ERROR:  value for domain d_telefono violates check constraint "ck_d_telefono_formato"
```

**Regla protegida:** un teléfono es de 10 dígitos, sin lada internacional ni símbolos. La misma regla protege `clinica.telefono`, porque usa el mismo dominio.

---

## Caso 8. CHECK de formato — correo sin arroba

**Operación intentada:** cambiar el correo de Luis Pérez por uno sin `@`.

```sql
UPDATE persona SET correo = 'luis.perez.ejemplo.com' WHERE id_persona = 9002;
```

**Resultado esperado:** rechazo por `ck_persona_correo_formato`. La restricción se revisa también en un `UPDATE`, no solo al insertar.

**Mensaje del gestor:**

```text
ERROR:  new row for relation "persona" violates check constraint "ck_persona_correo_formato"
DETAIL:  Failing row contains (9002, Luis, Pérez, null, 5587654321, luis.perez.ejemplo.com, 2026-11-05).
```

**Regla protegida:** el correo, si existe, tiene la forma `usuario@dominio.ext`.

---

## Caso 9. CHECK de lista de valores — tipo de ingreso inexistente

**Operación intentada:** registrar un rescate con tipo de ingreso `'abandono'`, que no está en la lista.

```sql
INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9003, 'Mercado de Sonora', '2026-10-20 17:00', 'Desnutrido', 'abandono', 9001);
```

**Resultado esperado:** rechazo por `ck_rescate_tipo_ingreso`, que solo admite `rescate_en_calle`, `reporte_ciudadano` y `entrega_voluntaria`.

**Mensaje del gestor:**

```text
ERROR:  new row for relation "rescate" violates check constraint "ck_rescate_tipo_ingreso"
DETAIL:  Failing row contains (9003, Mercado de Sonora, 2026-10-20 17:00:00, Desnutrido, abandono, 9001).
```

**Regla protegida:** un rescate ingresa por una de tres vías; con texto libre, la misma vía se escribiría de varias formas y no se podría contar por tipo.

---

## Caso 10. CHECK entre columnas — seguimiento anterior a la adopción

**Operación intentada:** registrar un seguimiento del 25 de septiembre para una adopción del 1 de octubre.

```sql
INSERT INTO seguimiento (id_animal, id_persona, fecha_adopcion, num_seguimiento, fecha, medio, estado_del_animal)
VALUES (9001, 9001, '2026-10-01', 1, '2026-09-25', 'llamada', 'Se adapta bien');
```

**Resultado esperado:** rechazo por `ck_seguimiento_fecha` (`fecha >= fecha_adopcion`). La clave foránea sí se cumple, porque la adopción existe; lo que falla es la comparación entre dos columnas del mismo renglón.

**Mensaje del gestor:**

```text
ERROR:  new row for relation "seguimiento" violates check constraint "ck_seguimiento_fecha"
DETAIL:  Failing row contains (9001, 9001, 2026-10-01, 1, 2026-09-25, llamada, Se adapta bien, null).
```

**Regla protegida:** un seguimiento no puede ser anterior a la adopción que revisa.

---

## Comprobación final

Antes del `ROLLBACK`, el script cuenta los renglones de prueba. Solo existen los válidos: los datos base y los dos del caso 2. Ningún renglón rechazado quedó guardado.

```text
    tabla    | count
-------------+-------
 persona     |     3
 zona        |     1
 rescate     |     1
 adopcion    |     1
 seguimiento |     0
```

Las 3 personas son las dos de los datos base más la del caso 2. Después, el `ROLLBACK` deja la base sin ninguno de estos renglones.
