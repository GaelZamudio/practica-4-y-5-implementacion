-- Ejecutar cada caso por separado en pgAdmin, conectado como el usuario indicado.
-- No ejecutar todo el archivo con una sola conexión ni como postgres.

-- A1: huellared_app. Permitido: lectura y escritura (sin modificar filas).
SELECT current_user, session_user;
SELECT count(*) FROM public.animal;
UPDATE public.animal SET nombre = nombre WHERE FALSE;
-- A2: denegado: DDL sobre tabla del administrador.
ALTER TABLE public.animal ADD COLUMN prueba_permiso integer;

-- C1: huellared_consulta. Permitido.
SELECT current_user, session_user;
SELECT count(*) FROM public.persona;
-- C2: denegado incluso si no hay filas.
DELETE FROM public.persona WHERE FALSE;

-- D1: huellared_admin. Permitido: administrar DDL. Ejecutar este bloque completo.
BEGIN;
SET LOCAL ROLE hr_admin;
CREATE TABLE public.prueba_permiso_admin (id integer PRIMARY KEY);
ROLLBACK;
-- D2: denegado: administrar roles del servidor.
CREATE ROLE prueba_rol_no_autorizado NOLOGIN;

-- R1: administrador. Ejecutar y confirmar antes de cambiar de conexión.
REVOKE SELECT ON TABLE public.persona FROM hr_consulta;
-- R2: conexión huellared_consulta. Debe fallar tras R1.
SELECT count(*) FROM public.persona;
-- R3: administrador. Restaurar para dejar el rol funcional.
GRANT SELECT ON TABLE public.persona TO hr_consulta;
-- R4: huellared_consulta. Debe funcionar otra vez.
SELECT count(*) FROM public.persona;
