-- =====================================================================
-- alejandro-rojas.sql
-- Prácticas 4 y 5 · Ejercicio 2.6 · Trabajo individual
-- Autor: Alejandro Rojas (Zona A: personas y hogares)
--
-- Relación: hogar_temporal -> persona   (fk_hogar_persona)
-- Acción original: ON DELETE RESTRICT.  Acción de prueba: ON DELETE CASCADE.
--
-- Se ejecuta SOBRE UNA COPIA de la base, nunca sobre la del equipo:
--   createdb -T <base_del_equipo> copia_26_alejandro
--   psql -d copia_26_alejandro -f alejandro-rojas.sql
-- Además todo va en una transacción que termina en ROLLBACK, así que
-- ni siquiera la copia queda modificada.
-- =====================================================================
\set ON_ERROR_ROLLBACK on
\set ON_ERROR_STOP off
\pset footer off

BEGIN;

-- ---------------------------------------------------------------------
-- Datos de prueba (ids 9000+)
--   Persona 9101 (Marta): responsable del hogar 9101, que TIENE una estancia.
--   Persona 9102 (Raúl):  responsable del hogar 9102, que NO tiene estancias.
--   Persona 9103 (Sofía): rescatista que coloca al animal en el hogar 9101.
-- ---------------------------------------------------------------------
INSERT INTO zona (id_zona, colonia, municipio, entidad)
VALUES (9101, 'Portales Norte', 'Benito Juárez', 'Ciudad de México');

INSERT INTO persona (id_persona, nombres, ap_paterno, telefono, correo) VALUES
 (9101, 'Marta', 'Ríos',   '5510000001', 'marta.rios@ejemplo.com'),
 (9102, 'Raúl',  'Mendoza','5510000002', 'raul.mendoza@ejemplo.com'),
 (9103, 'Sofía', 'Navarro','5510000003', 'sofia.navarro@ejemplo.com');

INSERT INTO rescatista (id_persona, vehiculo_propio, disponibilidad) VALUES
 (9101, FALSE, 'fines de semana'),
 (9102, TRUE,  'tardes'),
 (9103, TRUE,  'diario');

INSERT INTO hogar_temporal (id_hogar, alias, calle, numero, cp, capacidad_max, id_persona, id_zona) VALUES
 (9101, 'Casa Marta', 'Calle Odesa', '45', '03300', 3, 9101, 9101),
 (9102, 'Casa Raúl',  'Calle Bruselas','12', '03300', 2, 9102, 9101);

INSERT INTO hogar_especie (id_hogar, especie) VALUES
 (9101, 'perro'), (9101, 'gato'),
 (9102, 'perro'), (9102, 'gato');

INSERT INTO rescate (id_rescate, descripcion_lugar, fecha_hora, condicion_inicial, tipo_ingreso, id_zona)
VALUES (9101, 'Parque de los Venados', '2026-10-02 09:00', 'Sano, desorientado', 'rescate_en_calle', 9101);

INSERT INTO animal (id_animal, nombre, especie, sexo, id_rescate)
VALUES (9101, 'Pimienta', 'perro', 'hembra', 9101);

INSERT INTO estancia (id_animal, id_hogar, id_persona, fecha_inicio)
VALUES (9101, 9101, 9103, '2026-10-03');

-- Vista auxiliar para contar renglones de prueba en cada tabla afectada
CREATE TEMP VIEW conteo AS
SELECT 'persona'        AS tabla, count(*) AS renglones FROM persona        WHERE id_persona BETWEEN 9101 AND 9103
UNION ALL SELECT 'rescatista',     count(*) FROM rescatista     WHERE id_persona BETWEEN 9101 AND 9103
UNION ALL SELECT 'hogar_temporal', count(*) FROM hogar_temporal WHERE id_hogar IN (9101, 9102)
UNION ALL SELECT 'hogar_especie',  count(*) FROM hogar_especie  WHERE id_hogar IN (9101, 9102)
UNION ALL SELECT 'estancia',       count(*) FROM estancia       WHERE id_animal = 9101;

\echo '=== Estado inicial ==='
SELECT * FROM conteo;

-- =====================================================================
\echo '=== A. Con ON DELETE RESTRICT (acción actual): borrar a Raúl ==='
DELETE FROM persona WHERE id_persona = 9102;
SELECT * FROM conteo;

-- =====================================================================
\echo '=== Cambio en la copia: RESTRICT -> CASCADE ==='
ALTER TABLE hogar_temporal DROP CONSTRAINT fk_hogar_persona;
ALTER TABLE hogar_temporal ADD CONSTRAINT fk_hogar_persona
    FOREIGN KEY (id_persona) REFERENCES persona (id_persona)
    ON DELETE CASCADE ON UPDATE CASCADE;

SELECT conname, confdeltype AS accion_al_borrar   -- c = cascade, r = restrict
FROM pg_constraint WHERE conname = 'fk_hogar_persona';

-- =====================================================================
\echo '=== B. Con ON DELETE CASCADE: borrar a Raúl (hogar SIN estancias) ==='
DELETE FROM persona WHERE id_persona = 9102;
SELECT * FROM conteo;

-- =====================================================================
\echo '=== C. Con ON DELETE CASCADE: borrar a Marta (hogar CON una estancia) ==='
DELETE FROM persona WHERE id_persona = 9101;
SELECT * FROM conteo;

ROLLBACK;
