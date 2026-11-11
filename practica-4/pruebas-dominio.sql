-- =====================================================================
-- pruebas-dominio.sql
-- Prácticas 4 y 5 · Ejercicio 1.5 (proyecto propio)
--
-- Diez casos que intentan violar las restricciones de dominio declaradas
-- en esquema.sql y migraciones/001-dominios.sql.
--
-- Se ejecuta con:
--   psql -d <base> -f pruebas-dominio.sql
--
-- Todo corre dentro de UNA transacción que termina en ROLLBACK, así que
-- la base queda exactamente como estaba. ON_ERROR_ROLLBACK hace que un
-- error deshaga solo la sentencia que falló y la prueba siguiente continúe.
-- =====================================================================
\set ON_ERROR_ROLLBACK on
\set ON_ERROR_STOP off
\set VERBOSITY default
\pset footer off

BEGIN;

-- ---------------------------------------------------------------------
-- Datos base válidos (ids 9000+ para no chocar con la carga)
-- ---------------------------------------------------------------------
INSERT INTO zona (id_zona, colonia, municipio, entidad)
VALUES (9001, 'Colonia prueba dominio', 'Municipio prueba dominio', 'Entidad prueba');

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

-- =====================================================================
\echo '=== Caso 1. NOT NULL: persona sin apellido paterno ==='
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9003, 'María', NULL, '5511112222');

-- =====================================================================
\echo '=== Caso 2. DEFAULT: animal y persona sin estado ni fecha de registro ==='
INSERT INTO animal (id_animal, nombre, especie, sexo, id_rescate)
VALUES (9002, 'Tizón', 'gato', 'macho', 9001);
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9004, 'Jorge', 'Díaz', '5533334444');
SELECT id_animal, nombre, estado_actual FROM animal WHERE id_animal = 9002;
SELECT id_persona, nombres, fecha_registro = CURRENT_DATE AS registrado_hoy
FROM persona WHERE id_persona = 9004;

-- =====================================================================
\echo '=== Caso 3. UNIQUE simple: dos personas con el mismo correo ==='
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono, correo)
VALUES (9005, 'Ana María', 'Soto', '5599990000', 'ana.lopez@ejemplo.com');

-- =====================================================================
\echo '=== Caso 4. UNIQUE compuesta: la misma colonia dos veces ==='
INSERT INTO zona (id_zona, colonia, municipio, entidad)
VALUES (9002, 'Colonia prueba dominio', 'Municipio prueba dominio', 'Entidad prueba');

-- =====================================================================
\echo '=== Caso 5. UNIQUE parcial: un animal adoptado por dos personas a la vez ==='
INSERT INTO adopcion (id_animal, id_persona, fecha_adopcion)
VALUES (9001, 9002, '2026-10-15');

-- =====================================================================
\echo '=== Caso 6. CHECK de rango: rescate con fecha en el futuro ==='
INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9002, 'Parque Alameda', LOCALTIMESTAMP + INTERVAL '3 days', 'Herido', 'reporte_ciudadano', 9001);

-- =====================================================================
\echo '=== Caso 7. CHECK de formato (dominio): teléfono con letras ==='
INSERT INTO persona (id_persona, nombres, ap_paterno, telefono)
VALUES (9006, 'Carla', 'Vega', '55ABC12345');

-- =====================================================================
\echo '=== Caso 8. CHECK de formato: correo sin arroba ==='
UPDATE persona SET correo = 'luis.perez.ejemplo.com' WHERE id_persona = 9002;

-- =====================================================================
\echo '=== Caso 9. CHECK de lista de valores: tipo de ingreso inexistente ==='
INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9003, 'Mercado de Sonora', '2026-10-20 17:00', 'Desnutrido', 'abandono', 9001);

-- =====================================================================
\echo '=== Caso 10. CHECK entre columnas: seguimiento anterior a la adopción ==='
INSERT INTO seguimiento (id_animal, id_persona, fecha_adopcion, num_seguimiento, fecha, medio, estado_del_animal)
VALUES (9001, 9001, '2026-10-01', 1, '2026-09-25', 'llamada', 'Se adapta bien');

-- ---------------------------------------------------------------------
\echo '=== Comprobación: solo existen los renglones válidos ==='
SELECT 'persona' AS tabla, count(*) FROM persona WHERE id_persona >= 9000
UNION ALL SELECT 'zona', count(*) FROM zona WHERE id_zona >= 9000
UNION ALL SELECT 'rescate', count(*) FROM rescate WHERE id_rescate >= 9000
UNION ALL SELECT 'adopcion', count(*) FROM adopcion WHERE id_animal >= 9000
UNION ALL SELECT 'seguimiento', count(*) FROM seguimiento WHERE id_animal >= 9000;

ROLLBACK;
