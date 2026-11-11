-- =====================================================================
-- Relación elegida : animal.id_madre → animal.id_animal   (fk_animal_madre)
-- Acción original  : ON DELETE SET NULL
-- Acción probada   : ON DELETE CASCADE
--
-- CÓMO EJECUTARLO EN pgAdmin
--   1. Conéctate a la base huellared_26_gael (la COPIA). Nunca a postgres.
--   2. Abre UNA sola ventana de Query Tool y úsala para todo: las tablas temporales
--      viven en esa sesión. Deja el autocommit activado (valor por omisión).
--   3. Ejecuta UN bloque a la vez: selecciona solo ese bloque y presiona F5.
--      No presiones F5 sin seleccionar: ejecutaría el archivo completo.
--   4. Después de cada bloque marcado [CAPTURA nn], toma la captura de pantalla
--      completa: deben verse el código ejecutado y el resultado.
--   5. Cada experimento abre una transacción (BEGIN) y la deshace (ROLLBACK).
--      Ejecuta siempre el bloque de ROLLBACK antes de pasar al siguiente experimento.
-- =====================================================================


-- ==================== BLOQUE 0 · [CAPTURA 01] ====================
-- Dónde estoy y cómo está la relación antes de tocar nada.
SELECT current_database() AS base_de_trabajo,
       (SELECT count(*) FROM animal)                 AS animales,
       (SELECT count(id_madre) FROM animal)          AS crias_con_madre,
       (SELECT count(DISTINCT id_madre) FROM animal) AS madres,
       (SELECT pg_get_constraintdef(oid) FROM pg_constraint
         WHERE conname = 'fk_animal_madre')          AS accion_actual;


-- ==================== BLOQUE 1 · sin captura ====================
-- Estructuras de apoyo (temporales: desaparecen al cerrar la ventana).
-- arbol: para cada animal, él mismo y todos sus descendientes (crías, crías de crías...).
CREATE TEMP TABLE arbol AS
WITH RECURSIVE t(raiz, id_animal) AS (
    SELECT id_animal, id_animal FROM animal
    UNION
    SELECT t.raiz, a.id_animal FROM t JOIN animal a ON a.id_madre = t.id_animal
)
SELECT raiz, id_animal FROM t;

-- conteos: cuántos renglones tienen hoy las tablas que dependen de animal.
CREATE TEMP VIEW conteos AS
          SELECT 1 AS orden, 'animal' AS tabla, count(*) AS n FROM animal
UNION ALL SELECT 2,  'perro',              count(*) FROM perro
UNION ALL SELECT 3,  'gato',               count(*) FROM gato
UNION ALL SELECT 4,  'otro',               count(*) FROM otro
UNION ALL SELECT 5,  'estancia',           count(*) FROM estancia
UNION ALL SELECT 6,  'solicitud_adopcion', count(*) FROM solicitud_adopcion
UNION ALL SELECT 7,  'adopcion',           count(*) FROM adopcion
UNION ALL SELECT 8,  'seguimiento',        count(*) FROM seguimiento
UNION ALL SELECT 9,  'atencion_medica',    count(*) FROM atencion_medica
UNION ALL SELECT 10, 'vacunacion',         count(*) FROM vacunacion
UNION ALL SELECT 11, 'cirugia',            count(*) FROM cirugia
UNION ALL SELECT 12, 'tratamiento',        count(*) FROM tratamiento;

-- antes: la foto del inicio, para comparar al final de cada experimento.
CREATE TEMP TABLE antes AS SELECT * FROM conteos;


-- ==================== BLOQUE 2 · [CAPTURA 02] ====================
-- Se eligen dos madres de prueba por consulta (no por id fijo):
--   m1: la madre con más descendientes entre las familias donde nadie ha sido adoptado.
--   m2: una madre que no está adoptada, pero alguna de sus crías sí.
CREATE TEMP TABLE elegidas AS
SELECT
  (SELECT t.raiz
     FROM arbol t LEFT JOIN adopcion d ON d.id_animal = t.id_animal
    GROUP BY t.raiz
   HAVING count(DISTINCT t.id_animal) >= 2 AND count(d.id_animal) = 0
    ORDER BY count(DISTINCT t.id_animal) DESC, t.raiz
    LIMIT 1) AS m1,
  (SELECT t.raiz
     FROM arbol t JOIN adopcion d ON d.id_animal = t.id_animal
    WHERE t.raiz <> t.id_animal
      AND t.raiz NOT IN (SELECT id_animal FROM adopcion)
    GROUP BY t.raiz
    ORDER BY count(*) DESC, t.raiz
    LIMIT 1) AS m2;

CREATE TEMP TABLE familia AS
SELECT 1 AS caso, id_animal FROM arbol WHERE raiz = (SELECT m1 FROM elegidas)
UNION ALL
SELECT 2,         id_animal FROM arbol WHERE raiz = (SELECT m2 FROM elegidas);

-- Familia de la madre 1, con lo que cuelga de cada animal:
SELECT (a.id_animal = (SELECT m1 FROM elegidas)) AS es_la_madre,
       a.id_animal, a.nombre, a.especie, a.id_madre,
       (SELECT count(*) FROM estancia x            WHERE x.id_animal = a.id_animal) AS estancias,
       (SELECT count(*) FROM solicitud_adopcion x  WHERE x.id_animal = a.id_animal) AS solicitudes,
       (SELECT count(*) FROM atencion_medica x     WHERE x.id_animal = a.id_animal) AS atenciones,
       (SELECT count(*) FROM adopcion x            WHERE x.id_animal = a.id_animal) AS adopciones
  FROM animal a
 WHERE a.id_animal IN (SELECT id_animal FROM familia WHERE caso = 1)
 ORDER BY es_la_madre DESC, a.id_animal;


-- ==================== EXPERIMENTO A · ON DELETE SET NULL (la acción actual) ====================
-- ==================== BLOQUE 3A · [CAPTURA 03] ====================
-- Se borra la madre 1 y se compara contra la foto del inicio.
BEGIN;
DELETE FROM animal WHERE id_animal = (SELECT m1 FROM elegidas);
SELECT a.tabla, a.n AS antes, c.n AS despues, a.n - c.n AS perdidos
  FROM antes a JOIN conteos c ON c.tabla = a.tabla
 ORDER BY c.orden;

-- ==================== BLOQUE 3B · [CAPTURA 04] ====================
-- (misma transacción) Las crías siguen existiendo; solo perdieron el vínculo con su madre.
SELECT id_animal, nombre, especie, estado_actual, id_madre
  FROM animal
 WHERE id_animal IN (SELECT id_animal FROM familia WHERE caso = 1)
   AND id_animal <> (SELECT m1 FROM elegidas)
 ORDER BY id_animal;

-- ==================== BLOQUE 3C · sin captura ====================
ROLLBACK;


-- ==================== EXPERIMENTO B · ON DELETE CASCADE ====================
-- ==================== BLOQUE 4A · [CAPTURA 05] ====================
-- Se cambia la acción y se borra la MISMA madre 1.
BEGIN;
ALTER TABLE animal DROP CONSTRAINT fk_animal_madre;
ALTER TABLE animal ADD CONSTRAINT fk_animal_madre
    FOREIGN KEY (id_madre) REFERENCES animal (id_animal)
    ON DELETE CASCADE ON UPDATE CASCADE;
DELETE FROM animal WHERE id_animal = (SELECT m1 FROM elegidas);
SELECT a.tabla, a.n AS antes, c.n AS despues, a.n - c.n AS perdidos
  FROM antes a JOIN conteos c ON c.tabla = a.tabla
 ORDER BY c.orden;

-- ==================== BLOQUE 4B · [CAPTURA 06] ====================
-- (misma transacción) La definición vigente y cuántos animales de esa familia sobreviven.
SELECT (SELECT pg_get_constraintdef(oid) FROM pg_constraint
         WHERE conname = 'fk_animal_madre') AS accion_vigente,
       (SELECT count(*) FROM animal
         WHERE id_animal IN (SELECT id_animal FROM familia WHERE caso = 1)) AS animales_de_la_familia_que_siguen;

-- ==================== BLOQUE 4C · sin captura ====================
ROLLBACK;


-- ==================== MADRE 2: el choque con RESTRICT ====================
-- ==================== BLOQUE 5 · [CAPTURA 07] ====================
-- Familia de la madre 2: ella no está adoptada, pero alguna de sus crías sí.
SELECT (a.id_animal = (SELECT m2 FROM elegidas)) AS es_la_madre,
       a.id_animal, a.nombre, a.especie, a.id_madre,
       (SELECT count(*) FROM adopcion x WHERE x.id_animal = a.id_animal) AS adopciones
  FROM animal a
 WHERE a.id_animal IN (SELECT id_animal FROM familia WHERE caso = 2)
 ORDER BY es_la_madre DESC, a.id_animal;


-- ==================== EXPERIMENTO C1 · SET NULL con la madre 2 ====================
-- ==================== BLOQUE 6A · [CAPTURA 08] ====================
-- Se borra la madre 2: sus crías y sus adopciones quedan intactas.
BEGIN;
DELETE FROM animal WHERE id_animal = (SELECT m2 FROM elegidas);
SELECT a.id_animal, a.nombre, a.id_madre,
       (SELECT count(*) FROM adopcion x WHERE x.id_animal = a.id_animal) AS adopciones
  FROM animal a
 WHERE a.id_animal IN (SELECT id_animal FROM familia WHERE caso = 2)
   AND a.id_animal <> (SELECT m2 FROM elegidas)
 ORDER BY a.id_animal;

-- ==================== BLOQUE 6B · sin captura ====================
ROLLBACK;


-- ==================== EXPERIMENTO C2 · CASCADE con la madre 2 ====================
-- ==================== BLOQUE 7A · [CAPTURA 09] ====================
-- Se espera un ERROR: para borrar a la cría adoptada, CASCADE choca con fk_adopcion_animal (RESTRICT).
-- El mensaje aparece en la pestaña Messages de pgAdmin.
BEGIN;
ALTER TABLE animal DROP CONSTRAINT fk_animal_madre;
ALTER TABLE animal ADD CONSTRAINT fk_animal_madre
    FOREIGN KEY (id_madre) REFERENCES animal (id_animal)
    ON DELETE CASCADE ON UPDATE CASCADE;
DELETE FROM animal WHERE id_animal = (SELECT m2 FROM elegidas);

-- ==================== BLOQUE 7B · sin captura ====================
-- Obligatorio tras el error: la transacción quedó abortada.
ROLLBACK;


-- ==================== BLOQUE 8 · [CAPTURA 10] ====================
-- Comprobación final: la copia quedó exactamente como estaba.
SELECT (SELECT count(*) FROM antes a JOIN conteos c ON c.tabla = a.tabla
         WHERE a.n <> c.n)                                    AS tablas_con_cambios,
       (SELECT pg_get_constraintdef(oid) FROM pg_constraint
         WHERE conname = 'fk_animal_madre')                   AS accion_vigente;