# Claves foráneas y acciones referenciales — Proyecto propio

Práctica 5 · Ejercicios 2.1 y 2.2 · HuellaRed · PostgreSQL

Este inventario se basa en `esquema.sql`, que crea el modelo relacional de la Práctica 3. La migración `practica-4/migraciones/001-dominios.sql` agrega dominios y restricciones de dominio; no cambia las claves foráneas. Las 29 claves foráneas están declaradas en el esquema, que contiene 23 tablas. Las columnas que forman parte de una FK son `NOT NULL` salvo cuando la relación es opcional.

`ON UPDATE CASCADE` se usa en todas las claves: si se modifica una clave primaria referenciada, las referencias conservan su vínculo. En este modelo los identificadores se asignan al insertar y normalmente no cambian, pero la acción evita referencias rotas si se actualiza alguno.

## Zona A — personas y hogares

| Restricción | Columna hija → columna referenciada | Relación EER | Nulos | ON DELETE y regla del dominio |
|---|---|---|---|---|
| `fk_rescatista_persona` | `rescatista.id_persona` → `persona.id_persona` | Persona es rescatista | No; el subtipo requiere su supertipo | `CASCADE`: borrar la persona elimina su registro de subtipo. |
| `fk_adoptante_persona` | `adoptante.id_persona` → `persona.id_persona` | Persona es adoptante | No; el subtipo requiere su supertipo | `CASCADE`: borrar la persona elimina su registro de subtipo. |
| `fk_veterinario_persona` | `veterinario.id_persona` → `persona.id_persona` | Persona es veterinario voluntario | No; el subtipo requiere su supertipo | `CASCADE`: borrar la persona elimina su registro de subtipo. |
| `fk_hogar_persona` | `hogar_temporal.id_persona` → `persona.id_persona` | Persona es responsable de hogar temporal | No; cada hogar tiene responsable | `RESTRICT`: no borrar una persona que aún es responsable de un hogar. |
| `fk_hogar_zona` | `hogar_temporal.id_zona` → `zona.id_zona` | Hogar temporal ubicado en zona | No; cada hogar está ubicado en una zona | `RESTRICT`: conservar la zona mientras tenga hogares. |
| `fk_hogar_especie_hogar` | `hogar_especie.id_hogar` → `hogar_temporal.id_hogar` | Hogar acepta especies (atributo multivaluado) | No; toda especie aceptada pertenece a un hogar | `CASCADE`: las filas que describen especies no tienen sentido sin el hogar. |

## Zona B — rescate, animal y adopción

| Restricción | Columna hija → columna referenciada | Relación EER | Nulos | ON DELETE y regla del dominio |
|---|---|---|---|---|
| `fk_rescate_zona` | `rescate.id_zona` → `zona.id_zona` | Rescate ocurre en zona | No; todo rescate ocurre en una zona | `RESTRICT`: una zona con rescates registrados no se elimina. |
| `fk_animal_rescate` | `animal.id_rescate` → `rescate.id_rescate` | Rescate origina animal | No; todo animal registrado proviene de un rescate | `RESTRICT`: preservar el rescate que explica el origen del animal. |
| `fk_animal_madre` | `animal.id_madre` → `animal.id_animal` | Animal es madre de otro animal (recursiva) | Sí; la madre puede ser desconocida o no registrada | `SET NULL`: al borrar el registro de la madre, el animal sigue existiendo con parentesco desconocido. |
| `fk_perro_animal` | `perro.id_animal` → `animal.id_animal` | Animal es perro | No; subtipo requiere supertipo | `CASCADE`: el detalle de perro se elimina con el animal. |
| `fk_gato_animal` | `gato.id_animal` → `animal.id_animal` | Animal es gato | No; subtipo requiere supertipo | `CASCADE`: el detalle de gato se elimina con el animal. |
| `fk_otro_animal` | `otro.id_animal` → `animal.id_animal` | Animal es de otra especie | No; subtipo requiere supertipo | `CASCADE`: el detalle se elimina con el animal. |
| `fk_rescate_rescatista_rescate` | `rescate_rescatista.id_rescate` → `rescate.id_rescate` | Rescatista participa en rescate (N:M) | No; fila asociativa requiere rescate | `CASCADE`: borrar el rescate elimina sus asociaciones de participación. |
| `fk_rescate_rescatista_rescatista` | `rescate_rescatista.id_persona` → `rescatista.id_persona` | Rescatista participa en rescate (N:M) | No; fila asociativa requiere rescatista | `RESTRICT`: no eliminar un rescatista con participaciones registradas. |
| `fk_estancia_animal` | `estancia.id_animal` → `animal.id_animal` | Animal permanece en hogar con rescatista (ternaria) | No; toda estancia identifica al animal | `CASCADE`: la estancia es un registro dependiente del animal. |
| `fk_estancia_hogar` | `estancia.id_hogar` → `hogar_temporal.id_hogar` | Animal permanece en hogar con rescatista (ternaria) | No; toda estancia identifica el hogar | `RESTRICT`: conservar hogares con estancias históricas. |
| `fk_estancia_rescatista` | `estancia.id_persona` → `rescatista.id_persona` | Animal permanece en hogar con rescatista (ternaria) | No; toda estancia identifica al rescatista responsable | `RESTRICT`: conservar al responsable asociado a la estancia. |
| `fk_solicitud_animal` | `solicitud_adopcion.id_animal` → `animal.id_animal` | Adoptante solicita animal | No; cada solicitud es de un animal | `CASCADE`: la solicitud depende de la existencia del animal en el sistema. |
| `fk_solicitud_adoptante` | `solicitud_adopcion.id_persona` → `adoptante.id_persona` | Adoptante solicita animal | No; cada solicitud identifica adoptante | `CASCADE`: al eliminar al adoptante se eliminan sus solicitudes. |
| `fk_adopcion_animal` | `adopcion.id_animal` → `animal.id_animal` | Adoptante adopta animal | No; cada adopción identifica animal | `RESTRICT`: conservar el animal mientras existan adopciones, incluso históricas. |
| `fk_adopcion_adoptante` | `adopcion.id_persona` → `adoptante.id_persona` | Adoptante adopta animal | No; cada adopción identifica adoptante | `RESTRICT`: conservar el adoptante asociado al historial de adopción. |
| `fk_seguimiento_adopcion` | `seguimiento.(id_animal,id_persona,fecha_adopcion)` → `adopcion.(id_animal,id_persona,fecha_adopcion)` | Seguimiento pertenece a adopción (entidad débil) | No; el seguimiento no existe sin adopción | `CASCADE`: borrar la adopción elimina sus seguimientos dependientes. |

## Zona C — atención médica

| Restricción | Columna hija → columna referenciada | Relación EER | Nulos | ON DELETE y regla del dominio |
|---|---|---|---|---|
| `fk_atencion_animal` | `atencion_medica.id_animal` → `animal.id_animal` | Animal recibe atención médica (entidad débil) | No; toda atención pertenece a un animal | `CASCADE`: la atención no tiene identidad independiente del animal en este modelo. |
| `fk_atencion_veterinario` | `atencion_medica.id_persona` → `veterinario.id_persona` | Atención realizada por veterinario | Sí; la participación es opcional | `SET NULL`: la atención se conserva si se elimina al veterinario. |
| `fk_atencion_clinica` | `atencion_medica.id_clinica` → `clinica.id_clinica` | Atención se realiza en clínica | Sí; la participación es opcional | `SET NULL`: la atención se conserva si se elimina la clínica. |
| `fk_vacunacion_atencion` | `vacunacion.(id_animal,num_atencion)` → `atencion_medica.(id_animal,num_atencion)` | Atención médica es vacunación (subtipo) | No; detalle de vacunación requiere atención | `CASCADE`: el detalle del subtipo se elimina con la atención. |
| `fk_vacunacion_vacuna` | `vacunacion.id_vacuna` → `vacuna.id_vacuna` | Vacunación aplica vacuna | No; toda vacunación identifica vacuna | `RESTRICT`: no borrar una vacuna referida por aplicaciones registradas. |
| `fk_cirugia_atencion` | `cirugia.(id_animal,num_atencion)` → `atencion_medica.(id_animal,num_atencion)` | Atención médica es cirugía (subtipo) | No; detalle de cirugía requiere atención | `CASCADE`: el detalle del subtipo se elimina con la atención. |
| `fk_tratamiento_atencion` | `tratamiento.(id_animal,num_atencion)` → `atencion_medica.(id_animal,num_atencion)` | Atención médica es tratamiento (subtipo) | No; detalle de tratamiento requiere atención | `CASCADE`: el detalle del subtipo se elimina con la atención. |
