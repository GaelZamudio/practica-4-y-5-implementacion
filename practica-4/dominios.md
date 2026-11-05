# Dominios y tipos de dato — Proyecto Propio (HuellaRed)

Ejercicio 1.1 · Prácticas 4 y 5 · Gestor: PostgreSQL 17

Este documento justifica el tipo de dato, la longitud y la nulabilidad de cada columna del esquema de la Práctica 3 (`esquema.sql`). Las restricciones que se agregan sobre estos tipos están en `migraciones/001-dominios.sql`, cada una con su regla del dominio en una línea.

## 1. Criterios que se aplicaron

- **Identificadores:** `INTEGER`, sin autoincremento. En el inventario común de la Práctica 3 se decidió que los ids se proporcionan al insertar, así que la carga controla los valores y las claves foráneas nunca dependen de una secuencia. Un entero de 4 bytes alcanza para más de 2 mil millones de registros, muy por encima de lo que registra una red de rescate.
- **Texto de longitud variable:** `VARCHAR(n)`, con el `n` pensado para el valor más largo razonable. En PostgreSQL no cambia el rendimiento frente a `TEXT`; el tope sirve para que la base haga cumplir el tamaño.
- **Texto de longitud fija:** `CHAR(n)` solo cuando el dato mide siempre lo mismo (código postal de 5 dígitos, teléfono de 10). Se guardan como texto y no como número porque no se suman ni se comparan por magnitud, y porque pueden empezar con cero (el código postal `06000` es del centro de la Ciudad de México).
- **Fechas:** `DATE` cuando solo importa el día; `TIMESTAMP` solo para el momento exacto de un rescate. No se usa `TIMESTAMPTZ` porque todos los eventos ocurren en una sola zona horaria local y se capturan en hora local. Ninguna fecha se guarda como texto: se perdería la validación, el orden y la aritmética de fechas.
- **Booleanos:** `BOOLEAN` para sí/no. En `gato.resultado_fiv` y `gato.resultado_felv` el `NULL` tiene significado propio: el animal no se ha hecho la prueba.
- **NULL:** una columna admite nulos solo si existe un caso real en el que el dato no se conoce o no aplica (un animal callejero sin nombre, una estancia que sigue en curso). Las claves foráneas son `NOT NULL` cuando la cardinalidad mínima de la relación es 1.

## 2. Tipo por columna

Las columnas marcadas con ⟶ cambian en `001-dominios.sql`. El resto se conserva tal como quedó en la Práctica 3.

### Zona A — personas y hogares

**zona**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_zona | INTEGER | No | Identificador asignado por la carga. PK. |
| colonia | VARCHAR(80) | No | Nombre de colonia; 80 cubre los nombres oficiales largos. |
| municipio | VARCHAR(80) | No | Alcaldía o municipio; texto variable. |
| entidad | VARCHAR(50) | No | Entidad federativa; los nombres oficiales de las 32 caben en 50. |

**persona**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_persona | INTEGER | No | Identificador asignado por la carga. PK. |
| nombres | VARCHAR(60) | No | Atributo compuesto `nombre` descompuesto (regla 2 de la P3); admite varios nombres de pila. |
| ap_paterno | VARCHAR(50) | No | Todo registro necesita al menos un apellido. |
| ap_materno | VARCHAR(50) | Sí | Hay personas con un solo apellido. |
| telefono ⟶ | `d_telefono` (CHAR(10)) | No | Antes VARCHAR(15). Los teléfonos mexicanos son de 10 dígitos; texto de longitud fija, porque no es una cantidad. |
| correo | VARCHAR(100) | Sí | Es opcional; 100 sobra para un correo personal. Lleva UNIQUE desde la P3. |
| fecha_registro | DATE | No | Solo importa el día. Se agrega DEFAULT `CURRENT_DATE`. |

**rescatista** (subtipo de persona, estrategia A: tabla por subtipo)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_persona | INTEGER | No | PK y FK a `persona`; mismo tipo que la clave que referencia. |
| vehiculo_propio | BOOLEAN | No | Sí o no. |
| disponibilidad | VARCHAR(50) | Sí | Texto breve libre ("fines de semana"); opcional. |

**adoptante** (subtipo de persona)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_persona | INTEGER | No | PK y FK a `persona`. |
| tipo_vivienda | VARCHAR(30) | No | Categoría de una lista cerrada (CHECK en 001); 30 sobra para el valor más largo. |
| tiene_patio | BOOLEAN | No | Sí o no. |
| otras_mascotas | BOOLEAN | No | Sí o no. |

**veterinario** (subtipo de persona)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_persona | INTEGER | No | PK y FK a `persona`. |
| cedula | VARCHAR(20) | No | La cédula profesional mide 7 u 8 dígitos, no siempre lo mismo, así que no es `CHAR`; el CHECK de formato en 001 es lo que realmente la limita. UNIQUE desde la P3. |
| especialidad | VARCHAR(50) | Sí | No todos declaran una. |

**hogar_temporal**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_hogar | INTEGER | No | Identificador asignado por la carga. PK. |
| alias | VARCHAR(50) | Sí | Apodo opcional del hogar. |
| calle | VARCHAR(100) | No | Atributo compuesto `dirección` descompuesto. |
| numero | VARCHAR(10) | No | Texto, no número: admite "S/N" y "12-B". |
| cp | CHAR(5) | No | Código postal: exactamente 5 dígitos; texto para conservar el cero inicial. |
| capacidad_max | INTEGER | No | Conteo de animales; el CHECK `> 0` viene de la P3. |
| activo | BOOLEAN | No | Sí o no. Se agrega DEFAULT `TRUE`. |
| id_persona | INTEGER | No | FK a `persona` (responsable); cardinalidad mínima 1. |
| id_zona | INTEGER | No | FK a `zona`; cardinalidad mínima 1. |

**hogar_especie** (atributo multivaluado `especies_aceptadas`, regla 3 de la P3)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_hogar | INTEGER | No | Parte de la PK y FK a `hogar_temporal`. |
| especie ⟶ | `especie_t` (enumerado) | No | Antes VARCHAR(30). Mismo conjunto cerrado que `animal.especie`. Parte de la PK. |

### Zona B — rescate, animal y adopción

**rescate**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_rescate | INTEGER | No | Identificador asignado por la carga. PK. |
| descripcion_lugar | VARCHAR(200) | No | Referencia libre del sitio ("bajo el puente de..."). |
| fecha_hora | TIMESTAMP | No | El momento exacto del rescate importa, no solo el día; sin zona horaria por lo explicado arriba. |
| condicion_inicial | VARCHAR(200) | No | Descripción breve del estado del animal al rescatarlo. |
| tipo_ingreso | VARCHAR(30) | No | Categoría de una lista cerrada (CHECK en 001). |
| id_zona | INTEGER | No | FK a `zona`; cardinalidad mínima 1. |

**animal**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Identificador asignado por la carga. PK. |
| nombre | VARCHAR(50) | Sí | Muchos animales de calle llegan sin nombre. |
| especie ⟶ | `especie_t` (enumerado) | No | Antes VARCHAR(30) con CHECK. Es la clave de la jerarquía perro/gato/otro. |
| sexo | VARCHAR(10) | No | 'macho' o 'hembra' (CHECK de la P3); 10 cubre ambos valores. |
| fecha_nacimiento_aprox | DATE | Sí | Es aproximada y a menudo desconocida; solo importa el día. |
| color | VARCHAR(50) | Sí | Descripción libre. |
| senas | VARCHAR(200) | Sí | Señas particulares, texto descriptivo. |
| estado_actual | VARCHAR(30) | No | Etapa del proceso (lista cerrada con CHECK en 001). Se agrega DEFAULT `'rescatado'`. |
| id_rescate | INTEGER | No | FK a `rescate`; cardinalidad mínima 1 (todo animal viene de un rescate). |
| id_madre | INTEGER | Sí | FK recursiva a `animal`; mínima 0 porque la madre suele ser desconocida. |

**perro** (subtipo de animal)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | PK y FK a `animal`. |
| tamano | VARCHAR(20) | No | Lista cerrada (CHECK en 001). |
| nivel_energia | VARCHAR(20) | No | Lista cerrada (CHECK en 001). |
| apto_con_ninos | BOOLEAN | No | Sí o no. |

**gato** (subtipo de animal)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | PK y FK a `animal`. |
| resultado_fiv | BOOLEAN | Sí | Positivo o negativo; `NULL` = sin prueba todavía. |
| resultado_felv | BOOLEAN | Sí | Igual que FIV. |

**otro** (subtipo de animal)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | PK y FK a `animal`. |
| descripcion_especie | VARCHAR(100) | No | Sin esta descripción un animal "otro" no es identificable. |
| cuidados_especiales | VARCHAR(200) | Sí | Solo algunos los requieren. |

**rescate_rescatista** (relación N:M `participa`)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_rescate | INTEGER | No | Parte de la PK y FK a `rescate`. |
| id_persona | INTEGER | No | Parte de la PK y FK a `rescatista`. |

**estancia** (relación ternaria animal–hogar–rescatista)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y FK a `animal`. |
| id_hogar | INTEGER | No | Parte de la PK y FK a `hogar_temporal`. |
| id_persona | INTEGER | No | Parte de la PK y FK a `rescatista` (quien lo coloca). |
| fecha_inicio | DATE | No | Parte de la PK; permite varias estancias del mismo animal en el mismo hogar. |
| fecha_fin | DATE | Sí | `NULL` = la estancia sigue en curso. |
| motivo_salida | VARCHAR(100) | Sí | Solo existe si la estancia terminó. |

**solicitud_adopcion** (relación `solicita`)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y FK a `animal`. |
| id_persona | INTEGER | No | Parte de la PK y FK a `adoptante`. |
| fecha_solicitud | DATE | No | Parte de la PK; DEFAULT `CURRENT_DATE`. |
| estado | VARCHAR(20) | No | Lista cerrada (CHECK en 001); DEFAULT `'pendiente'`. |
| observaciones | VARCHAR(200) | Sí | Nota libre. |

**adopcion** (relación `adopta`)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y FK a `animal`. |
| id_persona | INTEGER | No | Parte de la PK y FK a `adoptante`. |
| fecha_adopcion | DATE | No | Parte de la PK; solo importa el día. |
| fecha_devolucion | DATE | Sí | `NULL` = la adopción sigue vigente. |
| motivo_devolucion | VARCHAR(200) | Sí | Solo existe si hubo devolución. |

**seguimiento** (entidad débil de `adopcion`)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y de la FK compuesta a `adopcion`. |
| id_persona | INTEGER | No | Ídem. |
| fecha_adopcion | DATE | No | Ídem; mismo tipo que en `adopcion`. |
| num_seguimiento | INTEGER | No | Discriminador de la entidad débil: consecutivo dentro de cada adopción. CHECK `> 0` desde la P3. |
| fecha | DATE | No | Día del seguimiento. |
| medio | VARCHAR(30) | No | Lista cerrada (CHECK en 001). |
| estado_del_animal | VARCHAR(200) | No | Descripción obligatoria: es el propósito del seguimiento. |
| observaciones | VARCHAR(200) | Sí | Nota libre. |

### Zona C — atención médica

**clinica**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_clinica | INTEGER | No | Identificador asignado por la carga. PK. |
| nombre | VARCHAR(100) | No | Nombre comercial. |
| direccion | VARCHAR(200) | No | Texto libre en una sola columna (aquí no se descompone). |
| telefono ⟶ | `d_telefono` (CHAR(10)) | No | Antes VARCHAR(15). Mismo dominio que `persona.telefono`. |
| tipo | VARCHAR(30) | No | Lista cerrada (CHECK en 001). |

**vacuna**

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_vacuna | INTEGER | No | Identificador asignado por la carga. PK. |
| nombre | VARCHAR(80) | No | Nombre de la vacuna. |
| especie_destino ⟶ | `especie_t` (enumerado) | No | Antes VARCHAR(30). Misma lista de especies. |
| intervalo_refuerzo_dias | INTEGER | Sí | Días entre refuerzos; `NULL` = dosis única. CHECK `> 0` desde la P3. |

**atencion_medica** (entidad débil de `animal`)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y FK a `animal`. |
| num_atencion | INTEGER | No | Discriminador: consecutivo por animal. CHECK `> 0` desde la P3. |
| fecha | DATE | No | Día de la atención; DEFAULT `CURRENT_DATE`. |
| tipo | VARCHAR(30) | No | Discriminador de la jerarquía; lista cerrada (CHECK en 001). |
| observaciones | VARCHAR(300) | Sí | Notas clínicas, algo más largas que en otras tablas. |
| id_persona | INTEGER | Sí | FK a `veterinario`; mínima 0 (no toda atención la hace un veterinario voluntario). |
| id_clinica | INTEGER | Sí | FK a `clinica`; mínima 0. |

**vacunacion** (subtipo de atención médica)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y de la FK compuesta a `atencion_medica`. |
| num_atencion | INTEGER | No | Ídem. |
| dosis_num | INTEGER | No | Número de dosis; CHECK `> 0` desde la P3. |
| fecha_proxima_dosis | DATE | Sí | `NULL` si no hay refuerzo. |
| id_vacuna | INTEGER | No | FK a `vacuna`; mínima 1. |

**cirugia** (subtipo de atención médica)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y de la FK compuesta a `atencion_medica`. |
| num_atencion | INTEGER | No | Ídem. |
| tipo_cirugia | VARCHAR(50) | No | Sin el tipo, la cirugía no está definida. |
| complicaciones | VARCHAR(200) | Sí | Solo si las hubo. |

**tratamiento** (subtipo de atención médica)

| Columna | Tipo y longitud | Nulo | Por qué |
|---|---|---|---|
| id_animal | INTEGER | No | Parte de la PK y de la FK compuesta a `atencion_medica`. |
| num_atencion | INTEGER | No | Ídem. |
| diagnostico | VARCHAR(200) | No | Un tratamiento sin diagnóstico no tiene sentido. |
| duracion_dias | INTEGER | No | Conteo de días; CHECK `> 0` desde la P3. |

## 3. Dominios y enumerados

Dos conjuntos de valores se repiten en varias tablas, así que se definen una sola vez:

```sql
CREATE DOMAIN d_telefono AS CHAR(10)
    CONSTRAINT ck_d_telefono_formato CHECK (VALUE ~ '^[0-9]{10}$');

CREATE TYPE especie_t AS ENUM ('perro', 'gato', 'otro');
```

| Dominio | Dónde se usa | Qué se gana |
|---|---|---|
| `d_telefono` | `persona.telefono`, `clinica.telefono` | La regla del teléfono vive en un solo lugar; si cambia (por ejemplo, aceptar lada), se cambia con un `ALTER DOMAIN` y se actualizan las dos columnas. El nombre del dominio también documenta la intención. |
| `especie_t` | `animal.especie`, `hogar_especie.especie`, `vacuna.especie_destino` | Las tres columnas aceptan exactamente los mismos valores y no pueden desincronizarse. Es un enumerado y no una tabla catálogo porque el conjunto es estructuralmente cerrado: agregar una especie implicaría agregar una tabla de subtipo. |

**Costo de los enumerados:** agregar un valor es fácil (`ALTER TYPE ... ADD VALUE`), pero quitarlo o reordenarlo es incómodo. Por eso las demás listas (`estado_actual`, `tipo_ingreso`, `medio`, etc.), que viven en una sola columna y pueden crecer, se dejaron como `CHECK (... IN (...))` en 001, que se cambia con un `ALTER TABLE`.


## 4. Atributos del modelo que no se almacenan

- **`/lugares_disponibles`** (hogar temporal): derivado. Se calcula como `capacidad_max` menos las estancias abiertas, así que guardarlo crearía un dato que se desactualiza.
- **`/esterilizado`** (animal): derivado de las cirugías registradas.
- **Compuestos:** `nombre` se descompone en `nombres`, `ap_paterno` y `ap_materno`; `dirección`, en `calle`, `numero` y `cp`.

## 5. Reglas del dominio que una restricción declarativa no cubre

Cubrirlas exigiría disparadores o una verificación diferida al final de la transacción, que quedan fuera del alcance de esta práctica:

- Un animal solo puede aparecer en `perro`, `gato` u `otro` si su `especie` coincide con esa tabla.
- El `tipo` de una `atencion_medica` debe coincidir con la tabla de subtipo en la que tiene su detalle.
- La madre de un animal debe ser hembra y haber nacido antes que la cría.
- Todo rescate tiene al menos un rescatista (cardinalidad mínima 1 del lado N de `participa`).
- Una adopción requiere una solicitud aprobada del mismo adoptante para el mismo animal.
