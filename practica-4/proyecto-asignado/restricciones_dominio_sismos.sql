-- ============================================================
-- Sección 1.7, tarea 3: restricciones de dominio del almacén de sismos
--
-- CORRER SOLO EN UNA COPIA de la base ya cargada con cargar_sismos.py:
--   createdb sismos_copia
--   pg_dump -d "$PGDATABASE" | psql -d sismos_copia
--   psql -d sismos_copia -v ON_ERROR_STOP=1 -f restricciones_dominio_sismos.sql
-- (la conexión sale de PGHOST, PGPORT, PGUSER y PGPASSWORD del entorno)
--
-- Qué hace:
--   1. Inventario de lo que el esquema declara hoy.
--   2. Cuenta cuántos renglones reales violarían cada propuesta.
--   3. Intenta agregar cada restricción en la copia.
--   4. Prueba negativa: intenta meter renglones inválidos y confirma que se rechazan.
-- ============================================================

-- 0. Seguro: se niega a correr si la base no es una copia
DO $$
BEGIN
    IF current_database() NOT LIKE '%copia%' THEN
        RAISE EXCEPTION 'Esto debe correr solo en la copia; base actual: %', current_database();
    END IF;
END $$;

-- 1. Inventario: lo que el esquema declara hoy
--    contype: p = llave primaria, u = unique, f = llave foránea, c = check
SELECT conrelid::regclass AS tabla, contype, conname,
       pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND contype IN ('p', 'u', 'f', 'c')
ORDER BY contype, conrelid::regclass::text;

-- 2. Prueba previa: cuántos renglones reales violan cada propuesta
--    (violan = 0 significa que la restricción se puede agregar sin limpiar datos)
SELECT 'A dim_sismos: dominio físico' AS propuesta, 'dim_sismos' AS tabla,
       count(*) AS filas,
       count(*) FILTER (WHERE NOT (magnitud > 0 AND magnitud <= 10)
                           OR profundidad < 0
                           OR latitud  NOT BETWEEN -90 AND 90
                           OR longitud NOT BETWEEN -180 AND 180) AS violan
FROM dim_sismos
UNION ALL
SELECT 'B dim_tiempo: calendario coherente', 'dim_tiempo',
       count(*),
       count(*) FILTER (WHERE anio NOT BETWEEN 1900 AND 2100
                           OR mes NOT BETWEEN 1 AND 12
                           OR dia NOT BETWEEN 1 AND 31
                           OR trimestre <> (mes - 1) / 3 + 1
                           OR anio <> EXTRACT(YEAR  FROM fecha)
                           OR mes  <> EXTRACT(MONTH FROM fecha)
                           OR dia  <> EXTRACT(DAY   FROM fecha))
FROM dim_tiempo
UNION ALL
SELECT 'C hechos: medidas en su rango', 'fact_impacto_sismos_imputed',
       count(*),
       count(*) FILTER (WHERE poblacion_afectada < 0
                           OR impacto_economico < 0
                           OR determinante_de_riesgo NOT BETWEEN 0 AND 1
                           OR riesgo_proporcional < 0)
FROM fact_impacto_sismos_imputed
UNION ALL
SELECT 'C zonas: pobtot = pobfem + pobmas', 'dim_zonas',
       count(*),
       count(*) FILTER (WHERE pobtot <= 0 OR pobtot <> pobfem + pobmas)
FROM dim_zonas;

-- 3. Agregar las restricciones en la copia. Cada una se intenta por separado:
--    si los datos la violan, PostgreSQL la rechaza y aquí se anota el aviso.
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN
        SELECT * FROM (VALUES
            ('A', 'dim_sismos', 'ck_sismos_magnitud',    'magnitud > 0 AND magnitud <= 10'),
            ('A', 'dim_sismos', 'ck_sismos_profundidad', 'profundidad >= 0'),
            ('A', 'dim_sismos', 'ck_sismos_latitud',     'latitud BETWEEN -90 AND 90'),
            ('A', 'dim_sismos', 'ck_sismos_longitud',    'longitud BETWEEN -180 AND 180'),
            ('B', 'dim_tiempo', 'ck_tiempo_anio',        'anio BETWEEN 1900 AND 2100'),
            ('B', 'dim_tiempo', 'ck_tiempo_mes',         'mes BETWEEN 1 AND 12'),
            ('B', 'dim_tiempo', 'ck_tiempo_dia',         'dia BETWEEN 1 AND 31'),
            ('B', 'dim_tiempo', 'ck_tiempo_trimestre',   'trimestre = (mes - 1) / 3 + 1'),
            ('B', 'dim_tiempo', 'ck_tiempo_fecha',
             'anio = EXTRACT(YEAR FROM fecha) AND mes = EXTRACT(MONTH FROM fecha) AND dia = EXTRACT(DAY FROM fecha)'),
            ('C', 'fact_impacto_sismos_imputed', 'ck_hecho_poblacion',    'poblacion_afectada >= 0'),
            ('C', 'fact_impacto_sismos_imputed', 'ck_hecho_impacto',      'impacto_economico >= 0'),
            ('C', 'fact_impacto_sismos_imputed', 'ck_hecho_determinante', 'determinante_de_riesgo BETWEEN 0 AND 1'),
            ('C', 'fact_impacto_sismos_imputed', 'ck_hecho_riesgo',       'riesgo_proporcional >= 0'),
            ('C', 'dim_zonas',  'ck_zonas_poblacion', 'pobtot > 0 AND pobtot = pobfem + pobmas')
        ) AS t(propuesta, tabla, nombre, expresion)
    LOOP
        BEGIN
            EXECUTE format('ALTER TABLE %I ADD CONSTRAINT %I CHECK (%s)',
                           r.tabla, r.nombre, r.expresion);
            RAISE NOTICE '% | % | % -> SE PUDO AGREGAR (los datos la cumplen)',
                         r.propuesta, r.tabla, r.nombre;
        EXCEPTION
            WHEN check_violation THEN
                RAISE NOTICE '% | % | % -> RECHAZADA (hay renglones que la violan)',
                             r.propuesta, r.tabla, r.nombre;
            WHEN OTHERS THEN
                RAISE NOTICE '% | % | % -> ERROR: %', r.propuesta, r.tabla, r.nombre, SQLERRM;
        END;
    END LOOP;
END $$;

-- 4. Prueba negativa: renglones inválidos que cada restricción debe rechazar.
--    Cada intento se deshace solo: si la base lo acepta, se avisa y se revierte.
DO $$
DECLARE
    c RECORD;
BEGIN
    FOR c IN
        SELECT * FROM (VALUES
            ('magnitud 11 (fuera de 0-10)',
             $q$INSERT INTO dim_sismos VALUES (-1, 11, 20, -100, 10, 'prueba', 'X', 'Prueba')$q$),
            ('magnitud 0',
             $q$INSERT INTO dim_sismos VALUES (-1, 0, 20, -100, 10, 'prueba', 'X', 'Prueba')$q$),
            ('profundidad negativa',
             $q$INSERT INTO dim_sismos VALUES (-1, 5, 20, -100, -3, 'prueba', 'X', 'Prueba')$q$),
            ('latitud 95',
             $q$INSERT INTO dim_sismos VALUES (-1, 5, 95, -100, 10, 'prueba', 'X', 'Prueba')$q$),
            ('longitud -200',
             $q$INSERT INTO dim_sismos VALUES (-1, 5, 20, -200, 10, 'prueba', 'X', 'Prueba')$q$),
            ('mes 13',
             $q$INSERT INTO dim_tiempo VALUES (-1, '00:00:00', '2000-01-01', 2000, 13, 1, 1)$q$),
            ('trimestre 3 en enero',
             $q$INSERT INTO dim_tiempo VALUES (-1, '00:00:00', '2000-01-01', 2000, 1, 1, 3)$q$),
            ('fecha distinta de anio/mes/dia',
             $q$INSERT INTO dim_tiempo VALUES (-1, '00:00:00', '2000-01-01', 2001, 1, 1, 1)$q$),
            ('impacto económico negativo',
             $q$INSERT INTO fact_impacto_sismos_imputed VALUES (0, 0, 0, 0, 100, -5, 0.5, 1, 0)$q$),
            ('determinante de riesgo 2',
             $q$INSERT INTO fact_impacto_sismos_imputed VALUES (0, 0, 0, 0, 100, 5, 2, 1, 0)$q$),
            ('población afectada negativa',
             $q$INSERT INTO fact_impacto_sismos_imputed VALUES (0, 0, 0, 0, -100, 5, 0.5, 1, 0)$q$),
            ('pobtot distinto de pobfem + pobmas',
             $q$INSERT INTO dim_zonas VALUES (-1, 99, 'Prueba', 100, 40, 40)$q$)
        ) AS t(caso, sentencia)
    LOOP
        BEGIN
            EXECUTE c.sentencia;
            RAISE EXCEPTION 'aceptada';        -- si llega aquí, nadie la rechazó
        EXCEPTION
            WHEN check_violation THEN
                RAISE NOTICE 'OK    % -> rechazado por la restricción', c.caso;
            WHEN raise_exception THEN
                RAISE NOTICE 'FALLA % -> la base aceptó un renglón inválido', c.caso;
            WHEN OTHERS THEN
                RAISE NOTICE 'OTRO  % -> error distinto: %', c.caso, SQLERRM;
        END;
    END LOOP;
END $$;

-- 5. Qué quedó declarado en la copia después de la prueba
SELECT conrelid::regclass AS tabla, conname, pg_get_constraintdef(oid) AS definicion
FROM pg_constraint
WHERE connamespace = 'public'::regnamespace
  AND contype = 'c'
ORDER BY conrelid::regclass::text, conname;
