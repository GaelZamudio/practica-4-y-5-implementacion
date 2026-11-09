-- Ejercicio 2.6 - Comparación de ON DELETE SET NULL y ON DELETE CASCADE
-- Proyecto: refugio de animales | Relación de Zona C: veterinario-atención médica
--
-- Ejecutar conectado a una COPIA de la base, por ejemplo:
--   psql -d refugio_copia -v ON_ERROR_STOP=1 -f ejercicio_2_6_refugio.sql
--
-- El script selecciona un veterinario con al menos una atención médica,
-- muestra el efecto de la regla actual (SET NULL), revierte esa prueba,
-- cambia temporalmente la FK a CASCADE y muestra su efecto. El ROLLBACK
-- final deshace los borrados y también restaura la definición original.

BEGIN;

-- Elegir de forma reproducible un veterinario con atenciones asociadas:
-- se toma el que tiene más; en empate, el de menor id_persona.
CREATE TEMP TABLE _prueba_veterinario ON COMMIT DROP AS
SELECT v.id_persona
FROM veterinario v
WHERE EXISTS (
    SELECT 1
    FROM atencion_medica am
    WHERE am.id_persona = v.id_persona
)
ORDER BY (
    SELECT count(*)
    FROM atencion_medica am
    WHERE am.id_persona = v.id_persona
) DESC, v.id_persona
LIMIT 1;

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM _prueba_veterinario) THEN
        RAISE EXCEPTION 'No hay veterinarios con atenciones médicas; no se puede demostrar el borrado.';
    END IF;
END $$;

-- Guardar las llaves de las atenciones seleccionadas antes de borrar el padre.
-- Así se pueden contar aunque SET NULL borre la referencia al veterinario.
CREATE TEMP TABLE _prueba_atenciones ON COMMIT DROP AS
SELECT am.id_animal, am.num_atencion
FROM atencion_medica am
JOIN _prueba_veterinario pv ON pv.id_persona = am.id_persona;

\echo
\echo '=== Registro elegido y cantidad inicial de atenciones ==='
SELECT pv.id_persona AS veterinario_elegido,
       (SELECT count(*) FROM _prueba_atenciones) AS atenciones_iniciales
FROM _prueba_veterinario pv;

\echo
\echo '=== Opción 1: acción actual ON DELETE SET NULL ==='
SAVEPOINT escenario_set_null;

DELETE FROM veterinario v
USING _prueba_veterinario pv
WHERE v.id_persona = pv.id_persona;

SELECT 'SET NULL' AS escenario,
       count(*) AS atenciones_originales,
       count(*) FILTER (WHERE am.id_animal IS NOT NULL) AS atenciones_conservadas,
       count(*) FILTER (WHERE am.id_animal IS NULL) AS atenciones_perdidas,
       count(*) FILTER (WHERE am.id_animal IS NOT NULL AND am.id_persona IS NULL)
           AS atenciones_con_veterinario_en_nulo
FROM _prueba_atenciones pa
LEFT JOIN atencion_medica am
       ON am.id_animal = pa.id_animal
      AND am.num_atencion = pa.num_atencion;

-- Deshacer el escenario para que el veterinario vuelva antes de probar CASCADE.
ROLLBACK TO SAVEPOINT escenario_set_null;

\echo
\echo '=== Opción 2: cambiar temporalmente la FK a ON DELETE CASCADE ==='
ALTER TABLE atencion_medica
    DROP CONSTRAINT fk_atencion_veterinario;

ALTER TABLE atencion_medica
    ADD CONSTRAINT fk_atencion_veterinario
    FOREIGN KEY (id_persona)
    REFERENCES veterinario (id_persona)
    ON DELETE CASCADE
    ON UPDATE CASCADE;

DELETE FROM veterinario v
USING _prueba_veterinario pv
WHERE v.id_persona = pv.id_persona;

SELECT 'CASCADE' AS escenario,
       count(*) AS atenciones_originales,
       count(*) FILTER (WHERE am.id_animal IS NOT NULL) AS atenciones_conservadas,
       count(*) FILTER (WHERE am.id_animal IS NULL) AS atenciones_perdidas
FROM _prueba_atenciones pa
LEFT JOIN atencion_medica am
       ON am.id_animal = pa.id_animal
      AND am.num_atencion = pa.num_atencion;

\echo
\echo '=== Efecto en los detalles dependientes de esas atenciones ==='
SELECT (SELECT count(*)
        FROM vacunacion x
        JOIN _prueba_atenciones pa USING (id_animal, num_atencion)) AS vacunaciones_restantes,
       (SELECT count(*)
        FROM cirugia x
        JOIN _prueba_atenciones pa USING (id_animal, num_atencion)) AS cirugias_restantes,
       (SELECT count(*)
        FROM tratamiento x
        JOIN _prueba_atenciones pa USING (id_animal, num_atencion)) AS tratamientos_restantes;

-- Deshace también la eliminación CASCADE y restaura la FK original SET NULL.
ROLLBACK;

\echo 'Prueba finalizada: la transacción fue revertida; los datos originales se conservaron.'
