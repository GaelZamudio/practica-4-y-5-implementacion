-- Ejecutar en CADA base como administrador/lector con acceso a todas las tablas public.
-- Solo lectura de tablas; la función auxiliar existe únicamente en esta sesión.
CREATE OR REPLACE FUNCTION pg_temp.auditar_integridad()
RETURNS TABLE(tipo text,objeto text,infracciones bigint) LANGUAGE plpgsql AS $$
DECLARE r record; condicion text; union_fk text; columnas text; filtro text;
BEGIN
 FOR r IN SELECT c.*, c.conrelid::regclass AS hija,c.confrelid::regclass AS padre
          FROM pg_constraint c JOIN pg_namespace n ON n.oid=c.connamespace
          WHERE c.contype='f' AND n.nspname='public' LOOP
  SELECT string_agg(format('h.%I IS NOT NULL',a.attname),' AND ' ORDER BY k.i),
         string_agg(format('h.%I=p.%I',a.attname,b.attname),' AND ' ORDER BY k.i)
  INTO condicion,union_fk
  FROM unnest(r.conkey,r.confkey) WITH ORDINALITY k(h,p,i)
  JOIN pg_attribute a ON a.attrelid=r.conrelid AND a.attnum=k.h
  JOIN pg_attribute b ON b.attrelid=r.confrelid AND b.attnum=k.p;
  RETURN QUERY EXECUTE format('SELECT %L::text,%L::text,count(*) FROM %s h WHERE %s AND NOT EXISTS(SELECT FROM %s p WHERE %s) HAVING count(*)>0',
    'FK huérfana',r.conname,r.hija,condicion,r.padre,union_fk);
 END LOOP;
 FOR r IN SELECT a.attname,c.oid::regclass AS tabla FROM pg_attribute a
 JOIN pg_class c ON c.oid=a.attrelid JOIN pg_namespace n ON n.oid=c.relnamespace
 WHERE n.nspname='public' AND c.relkind='r' AND a.attnum>0 AND NOT a.attisdropped AND a.attnotnull LOOP
  RETURN QUERY EXECUTE format('SELECT %L::text,%L::text,count(*) FROM %s WHERE %I IS NULL HAVING count(*)>0',
   'NULL prohibido',r.tabla||'.'||r.attname,r.tabla,r.attname);
 END LOOP;
 -- Incluye PK, UNIQUE e índices únicos parciales; respeta NULLS DISTINCT.
 FOR r IN SELECT i.*, i.indrelid::regclass AS tabla,i.indexrelid::regclass AS indice,
                 pg_get_expr(i.indpred,i.indrelid) AS predicado
          FROM pg_index i JOIN pg_class c ON c.oid=i.indrelid JOIN pg_namespace n ON n.oid=c.relnamespace
          WHERE n.nspname='public' AND i.indisunique LOOP
  SELECT string_agg(pg_get_indexdef(r.indexrelid,k,true),', '),
         string_agg('('||pg_get_indexdef(r.indexrelid,k,true)||') IS NOT NULL',' AND ')
  INTO columnas,filtro FROM generate_series(1,r.indnkeyatts) k;
  RETURN QUERY EXECUTE format('SELECT %L::text,%L::text,COALESCE(sum(n-1),0)::bigint FROM (SELECT count(*) n FROM %s WHERE (%s) AND (%s) GROUP BY %s HAVING count(*)>1) d HAVING COALESCE(sum(n-1),0)>0',
   'Duplicado único',r.indice,r.tabla,COALESCE(r.predicado,'true'),CASE WHEN r.indnullsnotdistinct THEN 'true' ELSE filtro END,columnas);
 END LOOP;
END $$;
SELECT * FROM pg_temp.auditar_integridad(); -- Debe devolver CERO FILAS.
-- Mostrar cobertura: un resultado vacío no prueba relaciones que no estén declaradas.
SELECT count(*) FILTER(WHERE contype='f') AS claves_foraneas,
       count(*) FILTER(WHERE contype='f' AND NOT convalidated) AS fk_sin_validar
FROM pg_constraint WHERE connamespace='public'::regnamespace;
