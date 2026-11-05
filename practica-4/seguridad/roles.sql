-- Ejercicio 1.6. Ejecutar con configurar.py, después de esquema.sql y 001-dominios.sql.
-- Roles de grupo sin inicio de sesión. Administración limitada a HuellaRed.
DO $$ BEGIN
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='hr_app') THEN CREATE ROLE hr_app NOLOGIN; END IF;
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='hr_consulta') THEN CREATE ROLE hr_consulta NOLOGIN; END IF;
 IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname='hr_admin') THEN CREATE ROLE hr_admin NOLOGIN; END IF;
END $$;
ALTER ROLE hr_app NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE hr_consulta NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
ALTER ROLE hr_admin NOSUPERUSER NOCREATEDB NOCREATEROLE NOREPLICATION NOBYPASSRLS;
REVOKE CREATE ON SCHEMA public FROM PUBLIC;
GRANT USAGE ON SCHEMA public TO hr_app, hr_consulta, hr_admin;
GRANT CREATE ON SCHEMA public TO hr_admin;
-- Propiedad de los objetos del proyecto: permite administrar su DDL sin ser superusuario.
DO $$ DECLARE t text; BEGIN
 FOREACH t IN ARRAY ARRAY['zona','persona','rescatista','adoptante','veterinario',
 'hogar_temporal','hogar_especie','rescate','animal','perro','gato','otro',
 'rescate_rescatista','estancia','solicitud_adopcion','adopcion','seguimiento',
 'clinica','vacuna','atencion_medica','vacunacion','cirugia','tratamiento'] LOOP
 EXECUTE format('ALTER TABLE public.%I OWNER TO hr_admin',t);
 EXECUTE format('REVOKE ALL ON TABLE public.%I FROM PUBLIC, hr_app, hr_consulta',t);
 EXECUTE format('GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE public.%I TO hr_app',t);
 EXECUTE format('GRANT SELECT ON TABLE public.%I TO hr_consulta',t);
 END LOOP;
END $$;
ALTER DOMAIN public.d_telefono OWNER TO hr_admin;
ALTER TYPE public.especie_t OWNER TO hr_admin;
GRANT USAGE ON DOMAIN public.d_telefono TO hr_app, hr_consulta;
GRANT USAGE ON TYPE public.especie_t TO hr_app, hr_consulta;
-- Las tablas futuras necesitan concesiones explícitas; no se otorgan permisos automáticos.
