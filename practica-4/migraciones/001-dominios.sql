-- =====================================================================
-- 001-dominios.sql
-- Prácticas 4 y 5 · Ejercicios 1.1 y 1.2 (proyecto propio)
--
-- Se ejecuta DESPUÉS de esquema.sql (Práctica 3), sobre una base limpia.
-- =====================================================================
BEGIN;

-- =====================================================================
-- 1. Dominios y enumerados (se repiten en varias tablas)
-- =====================================================================

-- Regla: un teléfono es de 10 dígitos, sin lada internacional ni símbolos.
CREATE DOMAIN d_telefono AS CHAR(10)
    CONSTRAINT ck_d_telefono_formato CHECK (VALUE ~ '^[0-9]{10}$');

-- Regla: solo se atienden perros, gatos y "otros".
CREATE TYPE especie_t AS ENUM ('perro', 'gato', 'otro');

ALTER TABLE persona ALTER COLUMN telefono TYPE d_telefono USING telefono::d_telefono;
ALTER TABLE clinica ALTER COLUMN telefono TYPE d_telefono USING telefono::d_telefono;

-- El enumerado ya valida lo que validaba el CHECK de la Práctica 3.
ALTER TABLE animal DROP CONSTRAINT ck_animal_especie;
ALTER TABLE animal        ALTER COLUMN especie         TYPE especie_t USING especie::especie_t;
ALTER TABLE hogar_especie ALTER COLUMN especie         TYPE especie_t USING especie::especie_t;
ALTER TABLE vacuna        ALTER COLUMN especie_destino TYPE especie_t USING especie_destino::especie_t;

-- =====================================================================
-- 2. DEFAULT (valores iniciales)
-- =====================================================================

-- Regla: una persona se registra el día en que se da de alta.
ALTER TABLE persona ALTER COLUMN fecha_registro SET DEFAULT CURRENT_DATE;

-- Regla: un hogar temporal nuevo inicia activo.
ALTER TABLE hogar_temporal ALTER COLUMN activo SET DEFAULT TRUE;

-- Regla: un animal recién ingresado queda como "rescatado".
ALTER TABLE animal ALTER COLUMN estado_actual SET DEFAULT 'rescatado';

-- Regla: una solicitud de adopción nace pendiente y con la fecha del día.
ALTER TABLE solicitud_adopcion ALTER COLUMN estado          SET DEFAULT 'pendiente';
ALTER TABLE solicitud_adopcion ALTER COLUMN fecha_solicitud SET DEFAULT CURRENT_DATE;

-- Regla: una atención médica se registra con la fecha del día si no se indica otra.
ALTER TABLE atencion_medica ALTER COLUMN fecha SET DEFAULT CURRENT_DATE;

-- =====================================================================
-- 3. UNIQUE (simples, compuestas y parciales)
-- =====================================================================

-- Regla: una colonia de un municipio y entidad se registra una sola vez.
ALTER TABLE zona ADD CONSTRAINT uq_zona_ubicacion
    UNIQUE (colonia, municipio, entidad);

-- Regla: una clínica no se repite con el mismo nombre en la misma dirección.
ALTER TABLE clinica ADD CONSTRAINT uq_clinica_nombre_direccion
    UNIQUE (nombre, direccion);

-- Regla: el catálogo no repite una vacuna para la misma especie.
ALTER TABLE vacuna ADD CONSTRAINT uq_vacuna_nombre_especie
    UNIQUE (nombre, especie_destino);

-- Regla: la misma dosis de la misma vacuna no se aplica dos veces al mismo animal.
ALTER TABLE vacunacion ADD CONSTRAINT uq_vacunacion_dosis
    UNIQUE (id_animal, id_vacuna, dosis_num);

-- Regla: un animal no puede estar en dos hogares temporales a la vez (solo una estancia abierta por animal).
CREATE UNIQUE INDEX ux_estancia_abierta
    ON estancia (id_animal) WHERE fecha_fin IS NULL;

-- Regla: un animal no puede estar adoptado por dos personas a la vez (solo una adopción vigente por animal).
CREATE UNIQUE INDEX ux_adopcion_vigente
    ON adopcion (id_animal) WHERE fecha_devolucion IS NULL;

-- =====================================================================
-- 4. CHECK de formato
-- =====================================================================

-- Regla: el correo, si existe, tiene forma usuario@dominio.ext.
ALTER TABLE persona ADD CONSTRAINT ck_persona_correo_formato
    CHECK (correo ~* '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$');

-- Regla: el correo se guarda en minúsculas para que el UNIQUE no distinga "Ana@x.com" de "ana@x.com".
ALTER TABLE persona ADD CONSTRAINT ck_persona_correo_minusculas
    CHECK (correo = lower(correo));

-- Regla: nombres y apellido paterno no pueden ser cadenas vacías (NOT NULL deja pasar '').
ALTER TABLE persona ADD CONSTRAINT ck_persona_nombre_no_vacio
    CHECK (length(btrim(nombres)) > 0 AND length(btrim(ap_paterno)) > 0);

-- Regla: la cédula profesional tiene 7 u 8 dígitos.
ALTER TABLE veterinario ADD CONSTRAINT ck_veterinario_cedula_formato
    CHECK (cedula ~ '^[0-9]{7,8}$');

-- Regla: el código postal mexicano son exactamente 5 dígitos.
ALTER TABLE hogar_temporal ADD CONSTRAINT ck_hogar_cp_formato
    CHECK (cp ~ '^[0-9]{5}$');

-- =====================================================================
-- 5. CHECK de lista de valores permitidos
-- =====================================================================

-- Regla: un rescate ingresa por una de estas tres vías.
ALTER TABLE rescate ADD CONSTRAINT ck_rescate_tipo_ingreso
    CHECK (tipo_ingreso IN ('rescate_en_calle', 'reporte_ciudadano', 'entrega_voluntaria'));

-- Regla: el animal está siempre en uno de los estados del proceso de rescate.
ALTER TABLE animal ADD CONSTRAINT ck_animal_estado_actual
    CHECK (estado_actual IN ('rescatado', 'en_atencion', 'en_hogar_temporal', 'disponible_adopcion', 'adoptado', 'fallecido'));

-- Regla: el tipo de vivienda del adoptante es una categoría conocida.
ALTER TABLE adoptante ADD CONSTRAINT ck_adoptante_tipo_vivienda
    CHECK (tipo_vivienda IN ('casa', 'departamento', 'vecindad', 'otro'));

-- Regla: el tamaño de un perro es chico, mediano o grande.
ALTER TABLE perro ADD CONSTRAINT ck_perro_tamano
    CHECK (tamano IN ('chico', 'mediano', 'grande'));

-- Regla: el nivel de energía de un perro es bajo, medio o alto.
ALTER TABLE perro ADD CONSTRAINT ck_perro_nivel_energia
    CHECK (nivel_energia IN ('bajo', 'medio', 'alto'));

-- Regla: una solicitud de adopción solo puede estar en uno de estos estados.
ALTER TABLE solicitud_adopcion ADD CONSTRAINT ck_solicitud_estado
    CHECK (estado IN ('pendiente', 'aprobada', 'rechazada', 'cancelada'));

-- Regla: el seguimiento posadopción se hace por uno de estos medios.
ALTER TABLE seguimiento ADD CONSTRAINT ck_seguimiento_medio
    CHECK (medio IN ('visita', 'llamada', 'mensaje', 'videollamada'));

-- Regla: una clínica es pública, privada, universitaria o de asociación civil.
ALTER TABLE clinica ADD CONSTRAINT ck_clinica_tipo
    CHECK (tipo IN ('publica', 'privada', 'universitaria', 'asociacion_civil'));

-- Regla: una atención médica es de uno de estos tipos (consulta es la atención que no es vacunación, cirugía ni tratamiento).
ALTER TABLE atencion_medica ADD CONSTRAINT ck_atencion_tipo
    CHECK (tipo IN ('consulta', 'vacunacion', 'cirugia', 'tratamiento'));

-- =====================================================================
-- 6. CHECK de rango (fechas que no pueden estar en el futuro)
-- =====================================================================

-- Regla: nadie se registra con fecha futura.
ALTER TABLE persona ADD CONSTRAINT ck_persona_fecha_registro
    CHECK (fecha_registro <= CURRENT_DATE);

-- Regla: un rescate no puede haber ocurrido en el futuro.
ALTER TABLE rescate ADD CONSTRAINT ck_rescate_fecha_hora
    CHECK (fecha_hora <= LOCALTIMESTAMP);

-- Regla: un animal no pudo nacer en el futuro.
ALTER TABLE animal ADD CONSTRAINT ck_animal_fecha_nacimiento
    CHECK (fecha_nacimiento_aprox <= CURRENT_DATE);

-- Regla: no se registra una solicitud de adopción con fecha futura.
ALTER TABLE solicitud_adopcion ADD CONSTRAINT ck_solicitud_fecha
    CHECK (fecha_solicitud <= CURRENT_DATE);

-- Regla: no se registra una adopción con fecha futura.
ALTER TABLE adopcion ADD CONSTRAINT ck_adopcion_fecha_no_futura
    CHECK (fecha_adopcion <= CURRENT_DATE);

-- Regla: no se registra una atención médica con fecha futura.
ALTER TABLE atencion_medica ADD CONSTRAINT ck_atencion_fecha_no_futura
    CHECK (fecha <= CURRENT_DATE);

-- =====================================================================
-- 7. CHECK entre columnas
-- =====================================================================

-- Regla: solo hay motivo de salida si la estancia ya terminó.
ALTER TABLE estancia ADD CONSTRAINT ck_estancia_motivo_salida
    CHECK (motivo_salida IS NULL OR fecha_fin IS NOT NULL);

-- Regla: solo hay motivo de devolución si el animal fue devuelto.
ALTER TABLE adopcion ADD CONSTRAINT ck_adopcion_motivo_devolucion
    CHECK (motivo_devolucion IS NULL OR fecha_devolucion IS NOT NULL);

-- Regla: un seguimiento no puede ser anterior a la adopción que revisa.
ALTER TABLE seguimiento ADD CONSTRAINT ck_seguimiento_fecha
    CHECK (fecha >= fecha_adopcion);

COMMIT; 