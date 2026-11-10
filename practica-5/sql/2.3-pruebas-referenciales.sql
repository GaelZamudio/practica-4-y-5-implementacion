-- Ejecutar completo en pgAdmin como huellared_admin, en HuellaRed poblada.
-- Los datos son sintéticos del generador; no se presentan como observaciones reales.
BEGIN;
SET LOCAL ROLE hr_admin;
CREATE TEMP TABLE objetivo AS SELECT id_animal,id_persona,fecha_adopcion FROM seguimiento ORDER BY id_animal LIMIT 1;
DO $$ BEGIN IF NOT EXISTS(SELECT FROM objetivo) THEN RAISE EXCEPTION 'Primero poblar HuellaRed'; END IF; END $$;
-- DELETE CASCADE: borrar una adopción elimina sus seguimientos dependientes.
SAVEPOINT cascada;
SELECT 'antes CASCADE' AS etapa,(SELECT count(*) FROM adopcion) AS adopciones,(SELECT count(*) FROM seguimiento) AS seguimientos;
DELETE FROM adopcion a USING objetivo o WHERE (a.id_animal,a.id_persona,a.fecha_adopcion)=(o.id_animal,o.id_persona,o.fecha_adopcion);
SELECT 'después CASCADE' AS etapa,(SELECT count(*) FROM adopcion) AS adopciones,(SELECT count(*) FROM seguimiento) AS seguimientos;
ROLLBACK TO cascada;
-- DELETE RESTRICT: preservar al animal que tiene una adopción registrada.
SELECT 'antes RESTRICT' AS etapa,(SELECT count(*) FROM animal) AS animales,(SELECT count(*) FROM adopcion) AS adopciones;
DO $$ DECLARE regla text; mensaje text; BEGIN
 BEGIN
  DELETE FROM animal WHERE id_animal=(SELECT id_animal FROM objetivo);
  RAISE EXCEPTION 'La operación debió fallar';
 EXCEPTION WHEN foreign_key_violation THEN
  GET STACKED DIAGNOSTICS regla=CONSTRAINT_NAME,mensaje=MESSAGE_TEXT;
  IF regla <> 'fk_adopcion_animal' THEN RAISE; END IF;
  RAISE NOTICE 'SQLSTATE 23503, %: %',regla,mensaje;
 END;
END $$;
SELECT 'después RESTRICT' AS etapa,(SELECT count(*) FROM animal) AS animales,(SELECT count(*) FROM adopcion) AS adopciones;
-- DELETE SET NULL: la atención sobrevive a la baja de una clínica.
CREATE TEMP TABLE clinica_objetivo AS SELECT id_clinica FROM atencion_medica WHERE id_clinica IS NOT NULL ORDER BY id_clinica LIMIT 1;
SAVEPOINT opcional;
SELECT 'antes SET NULL' AS etapa,(SELECT count(*) FROM clinica) AS clinicas,count(*) AS atenciones,count(*) FILTER(WHERE id_clinica IS NULL) AS sin_clinica FROM atencion_medica;
DELETE FROM clinica WHERE id_clinica=(SELECT id_clinica FROM clinica_objetivo);
SELECT 'después SET NULL' AS etapa,(SELECT count(*) FROM clinica) AS clinicas,count(*) AS atenciones,count(*) FILTER(WHERE id_clinica IS NULL) AS sin_clinica FROM atencion_medica;
ROLLBACK TO opcional;
-- UPDATE CASCADE: corregir el identificador de una zona propaga sus referencias.
CREATE TEMP TABLE cambio_zona AS SELECT (SELECT min(id_zona) FROM rescate) AS anterior,(SELECT LEAST(min(id_zona),0)-1 FROM zona) AS nuevo;
SAVEPOINT actualizar;
SELECT 'antes UPDATE' AS etapa,(SELECT count(*) FROM zona) AS zonas,count(*) AS rescates,count(*) FILTER(WHERE id_zona=(SELECT anterior FROM cambio_zona)) AS referencias FROM rescate;
UPDATE zona SET id_zona=(SELECT nuevo FROM cambio_zona) WHERE id_zona=(SELECT anterior FROM cambio_zona);
SELECT 'después UPDATE' AS etapa,(SELECT count(*) FROM zona) AS zonas,count(*) AS rescates,count(*) FILTER(WHERE id_zona=(SELECT nuevo FROM cambio_zona)) AS referencias FROM rescate;
ROLLBACK TO actualizar;
-- FK inválida y orden de carga: un nuevo rescate no puede preceder a su zona.
CREATE TEMP TABLE ids AS SELECT (SELECT LEAST(min(id_rescate),0)-1 FROM rescate) AS rescate,(SELECT LEAST(min(id_zona),0)-1 FROM zona) AS zona;
DO $$ DECLARE mensaje text; regla text; BEGIN
 BEGIN
  INSERT INTO rescate SELECT rescate,'Ejercicio 2.3',LOCALTIMESTAMP,'Sano','reporte_ciudadano',zona FROM ids;
  RAISE EXCEPTION 'Debió rechazarse la FK inexistente';
 EXCEPTION WHEN foreign_key_violation THEN
  GET STACKED DIAGNOSTICS mensaje=MESSAGE_TEXT,regla=CONSTRAINT_NAME;
  IF regla <> 'fk_rescate_zona' THEN RAISE; END IF;
  RAISE NOTICE 'Hija antes que padre: SQLSTATE 23503, %: %',regla,mensaje;
 END;
END $$;
INSERT INTO zona SELECT zona,'Colonia ejercicio 2.3','Municipio ejercicio 2.3','Entidad prueba' FROM ids;
INSERT INTO rescate SELECT rescate,'Ejercicio 2.3',LOCALTIMESTAMP,'Sano','reporte_ciudadano',zona FROM ids;
SELECT 'Padre antes que hija: correcto' AS resultado,r.* FROM rescate r JOIN ids i ON r.id_rescate=i.rescate;
ROLLBACK;
