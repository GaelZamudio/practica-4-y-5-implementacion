-- Ejecutar completo como huellared_admin. PostgreSQL/pgAdmin.
-- Parte A: operaciones sobre datos cargados, revertidas al terminar.
BEGIN;
SET LOCAL ROLE hr_admin;
-- INSERT SELECT: registrar solicitudes pendientes para animales disponibles.
INSERT INTO solicitud_adopcion(id_animal,id_persona,fecha_solicitud,estado)
SELECT a.id_animal,p.id_persona,CURRENT_DATE,'pendiente'
FROM animal a CROSS JOIN (SELECT id_persona FROM adoptante ORDER BY id_persona LIMIT 1) p
WHERE a.estado_actual='disponible_adopcion'
ON CONFLICT(id_animal,id_persona,fecha_solicitud) DO NOTHING
RETURNING *;
-- Upsert: repetir esa solicitud actualiza la observación, conservando su estado.
INSERT INTO solicitud_adopcion(id_animal,id_persona,fecha_solicitud,estado,observaciones)
SELECT a.id_animal,p.id_persona,CURRENT_DATE,'pendiente','Contacto confirmado (ejercicio 2.4)'
FROM animal a CROSS JOIN (SELECT id_persona FROM adoptante ORDER BY id_persona LIMIT 1) p
WHERE a.estado_actual='disponible_adopcion'
ON CONFLICT(id_animal,id_persona,fecha_solicitud) DO UPDATE SET observaciones=EXCLUDED.observaciones
RETURNING *;
-- UPDATE dependiente de otra tabla: marcar animales con adopción vigente.
UPDATE animal a SET estado_actual='adoptado'
WHERE EXISTS(SELECT FROM adopcion d WHERE d.id_animal=a.id_animal AND d.fecha_devolucion IS NULL)
RETURNING id_animal,estado_actual;
-- CASE: clasificar solicitudes pendientes por disponibilidad del animal.
UPDATE solicitud_adopcion s SET observaciones=CASE
 WHEN a.estado_actual='disponible_adopcion' THEN 'Contactar al solicitante'
 WHEN a.estado_actual='en_atencion' THEN 'Esperar alta médica'
 ELSE 'Revisar disponibilidad antes de continuar' END
FROM animal a WHERE a.id_animal=s.id_animal AND s.estado='pendiente'
RETURNING s.id_animal,s.observaciones;
-- DELETE con subconsulta: depurar solicitudes canceladas antiguas.
DELETE FROM solicitud_adopcion WHERE (id_animal,id_persona,fecha_solicitud) IN
 (SELECT id_animal,id_persona,fecha_solicitud FROM solicitud_adopcion
  WHERE estado='cancelada' AND fecha_solicitud<CURRENT_DATE-180) RETURNING *;
-- Borrado lógico: retirar hogares que no tienen estancias abiertas.
UPDATE hogar_temporal h SET activo=FALSE WHERE activo AND NOT EXISTS
 (SELECT FROM estancia e WHERE e.id_hogar=h.id_hogar AND e.fecha_fin IS NULL)
RETURNING id_hogar,activo;
ROLLBACK;

-- Parte B: alta de persona/adoptante, savepoint, rollback parcial y COMMIT real.
-- ID libre elegido dinámicamente; no colisiona con la carga.
BEGIN;
SET LOCAL ROLE hr_admin;
CREATE TEMP TABLE persona_prueba ON COMMIT PRESERVE ROWS AS SELECT LEAST(COALESCE(min(id_persona),0),0)-1 AS id FROM persona;
INSERT INTO persona(id_persona,nombres,ap_paterno,telefono)
SELECT id,'Prueba transacción','HuellaRed','5500000000' FROM persona_prueba;
SAVEPOINT vivienda;
INSERT INTO adoptante SELECT id,'departamento',FALSE,FALSE FROM persona_prueba;
ROLLBACK TO vivienda;
-- Corregir la captura de vivienda sin perder el alta de la persona.
INSERT INTO adoptante SELECT id,'casa',TRUE,FALSE FROM persona_prueba;
COMMIT;
SELECT 'Alta confirmada' AS resultado,p.id_persona,a.tipo_vivienda
FROM persona p JOIN adoptante a USING(id_persona) JOIN persona_prueba t ON t.id=p.id_persona;
-- Limpieza explícita tras demostrar COMMIT. Solo retira el registro recién creado.
BEGIN;
DELETE FROM persona WHERE id_persona=(SELECT id FROM persona_prueba);
COMMIT;
DROP TABLE persona_prueba;

-- Parte C: falla en la segunda tabla; el bloque EXCEPTION usa una subtransacción.
BEGIN;
SET LOCAL ROLE hr_admin;
CREATE TEMP TABLE antes_fallo AS SELECT (SELECT count(*) FROM persona) AS personas,(SELECT count(*) FROM adoptante) AS adoptantes;
DO $$ DECLARE id integer; mensaje text; regla text; BEGIN
 SELECT LEAST(COALESCE(min(id_persona),0),0)-1 INTO id FROM persona;
 BEGIN
  INSERT INTO persona(id_persona,nombres,ap_paterno,telefono) VALUES(id,'Prueba fallo','HuellaRed','5500000000');
  INSERT INTO adoptante VALUES(id,'vivienda_invalida',TRUE,FALSE);
  RAISE EXCEPTION 'Debió fallar el CHECK de vivienda';
 EXCEPTION WHEN check_violation THEN
  GET STACKED DIAGNOSTICS mensaje=MESSAGE_TEXT,regla=CONSTRAINT_NAME;
  IF regla <> 'ck_adoptante_tipo_vivienda' THEN RAISE; END IF;
  RAISE NOTICE 'SQLSTATE 23514, %: %',regla,mensaje;
 END;
 IF EXISTS(SELECT FROM persona WHERE id_persona=id) THEN RAISE EXCEPTION 'No se revirtió el alta'; END IF;
END $$;
SELECT b.personas AS personas_antes,(SELECT count(*) FROM persona) AS personas_despues,
 b.adoptantes AS adoptantes_antes,(SELECT count(*) FROM adoptante) AS adoptantes_despues FROM antes_fallo b;
ROLLBACK;
