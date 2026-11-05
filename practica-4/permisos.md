# Usuarios y permisos — HuellaRed

Ejercicio 1.6 · PostgreSQL 17 · Responsable: Gael.

## Roles y usuarios

| Rol (NOLOGIN) | Usuario (LOGIN) | Propósito |
|---|---|---|
| hr_app | huellared_app | Cargar y mantener los datos del proyecto: SELECT, INSERT, UPDATE y DELETE sobre sus 23 tablas. |
| hr_consulta | huellared_consulta | Consultar las 23 tablas sin modificarlas. |
| hr_admin | huellared_admin | Administrar tablas y tipos del proyecto, conceder permisos y efectuar cambios DDL. No administra roles ni bases del servidor. |

Los usuarios heredan los permisos de su rol. El administrador del servidor solo configura inicialmente estos objetos. El rol hr_admin pasa a ser propietario de las tablas y tipos del proyecto. Para crear objetos nuevos como propietario común, el administrador debe ejecutar `SET ROLE hr_admin`. No se conceden permisos automáticos sobre futuras tablas.

El cargador necesita acceder a todas las tablas porque poblará entidades, subtipos y relaciones. La aplicación no recibe TRUNCATE, creación de objetos ni propiedad de tablas. Consulta solo recibe SELECT. Los identificadores son enteros asignados por la carga: el esquema no usa secuencias que requieran concesiones adicionales. Se retira CREATE de PUBLIC en el esquema public. Este alcance corresponde a una base dedicada a HuellaRed con los usuarios nuevos de esta práctica.

## Archivos y preparación

- `seguridad/roles.sql`: roles y concesiones, con sentencias SQL ejecutables.
- `seguridad/configurar.py`: ejecuta el SQL y crea los usuarios con contraseñas tomadas del entorno, en una misma transacción.
- `seguridad/pruebas-permisos.sql`: casos para ejecutar por separado en pgAdmin.

Ejecutar primero `esquema.sql` y `migraciones/001-dominios.sql`. La configuración requiere una conexión inicial como administrador del servidor y acceso al puerto publicado por Docker. No vuelve a ejecutar el esquema ni las migraciones.

Completar localmente las variables de `.env.example` en `.env`, que está excluido de Git: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_PORT, PGHOST y las tres HUELLARED_*_PASSWORD. Mantener las variables POSTGRES_* de Docker con las credenciales del administrador inicial; las nuevas contraseñas pertenecen a los usuarios de la práctica. No incluir contraseñas en capturas.

El programa lee variables del entorno, no carga `.env` automáticamente. Si solo están en `.env`, una forma de ejecutarlo desde la raíz del repositorio es:

```powershell
python -m pip install "psycopg[binary]>=3.2,<4" "python-dotenv>=1,<2"
python -m dotenv -f .env run -- python practica-4/seguridad/configurar.py
```

También puede ejecutarse directamente si las variables ya están exportadas:

```powershell
python practica-4/seguridad/configurar.py
```

La configuración es transaccional y admite repetirse para estos mismos usuarios y roles. Si falla, no confirma cambios. Se debe realizar sobre los nombres reservados de esta práctica, sin asignarles otros roles adicionales que amplíen sus permisos.

## Conexión del cargador (ejercicio 1.4)

El futuro cargador deberá usar `huellared_app`, con contraseña tomada de `HUELLARED_APP_PASSWORD`, host PGHOST, puerto POSTGRES_PORT y base POSTGRES_DB. No usará POSTGRES_USER ni POSTGRES_PASSWORD para autenticar la carga. El código de conexión será equivalente a:

```python
conn = psycopg.connect(
    host=os.environ.get("PGHOST", "localhost"),
    port=os.environ["POSTGRES_PORT"],
    dbname=os.environ["POSTGRES_DB"],
    user="huellared_app",
    password=os.environ["HUELLARED_APP_PASSWORD"],
)
```

Pendiente de integrar y demostrar al implementar 1.4: guardar la salida de `SELECT current_user, session_user` desde la conexión real del cargador. Definir estos permisos no demuestra por sí solo que el cargador ya los utiliza.

## Pruebas en pgAdmin y evidencias

Registrar tres conexiones a la misma base con los usuarios anteriores. Ejecutar cada caso seleccionado del archivo SQL desde la conexión indicada, con autocommit habilitado. No ejecutar el archivo entero de una sola vez. Ante un error dentro de una transacción abierta, ejecutar ROLLBACK antes de continuar. Los mensajes siguientes son esperados; sustituir o acompañar con la salida real obtenida.

| Caso | Usuario | Resultado esperado | Mensaje real / evidencia pendiente |
|---|---|---|---|
| A1 | huellared_app | SELECT funciona; UPDATE sin filas funciona y afecta 0 filas. | Captura usuario, consultas y resultado. |
| A2 | huellared_app | ALTER TABLE rechazado: se requiere ser propietario. | Copiar error real y capturar. |
| C1 | huellared_consulta | SELECT funciona aunque la tabla esté vacía. | Captura usuario y resultado. |
| C2 | huellared_consulta | DELETE rechazado por falta de permiso sobre persona. | Copiar error real y capturar. |
| D1 | huellared_admin | CREATE TABLE funciona; ROLLBACK retira el objeto de prueba. | Capturar mensajes del bloque completo. |
| D2 | huellared_admin | CREATE ROLE rechazado por carecer de CREATEROLE. | Copiar error real y capturar. |
| R1–R2 | admin retira; consulta intenta leer | REVOKE confirmado; SELECT sobre persona deja de funcionar. | Capturar REVOKE y error en la conexión de consulta. |
| R3–R4 | admin restaura; consulta vuelve a leer | GRANT confirmado; SELECT funciona de nuevo. | Capturar restauración y lectura. |

Para las pruebas D1 y D2, la administración está deliberadamente limitada al proyecto. Por eso puede gestionar sus tablas pero no crear roles del servidor. No es un superusuario.

Ejemplos de las sentencias principales (los casos completos están en el archivo SQL):

```sql
-- Consulta permitida para consulta:
SELECT count(*) FROM public.persona;
-- Escritura denegada para consulta:
DELETE FROM public.persona WHERE FALSE;
-- Administrador retira y, después de demostrar el rechazo, restaura:
REVOKE SELECT ON TABLE public.persona FROM hr_consulta;
GRANT SELECT ON TABLE public.persona TO hr_consulta;
```

Guardar las capturas en `evidencias/` con nombres como `1.6-app-permitido.png`, `1.6-app-denegado.png`, `1.6-consulta-permitido.png`, `1.6-consulta-denegado.png`, `1.6-admin-permitido.png`, `1.6-admin-denegado.png`, `1.6-revoke.png` y `1.6-restauracion.png`. Incorporar aquí los enlaces y errores reales después de ejecutar. No hay resultados de ejecución fabricados en esta entrega.

## Matriz de permisos sobre tablas actuales

S = SELECT; I = INSERT; U = UPDATE; D = DELETE. Administración incluye permisos de propietario (DDL y concesión de permisos) sobre cada tabla. La creación de usuarios permanece a cargo del administrador del servidor.

| Tabla | hr_app | hr_consulta | hr_admin |
|---|---|---|---|
| zona | S, I, U, D | S | Propietario |
| persona | S, I, U, D | S | Propietario |
| rescatista | S, I, U, D | S | Propietario |
| adoptante | S, I, U, D | S | Propietario |
| veterinario | S, I, U, D | S | Propietario |
| hogar_temporal | S, I, U, D | S | Propietario |
| hogar_especie | S, I, U, D | S | Propietario |
| rescate | S, I, U, D | S | Propietario |
| animal | S, I, U, D | S | Propietario |
| perro | S, I, U, D | S | Propietario |
| gato | S, I, U, D | S | Propietario |
| otro | S, I, U, D | S | Propietario |
| rescate_rescatista | S, I, U, D | S | Propietario |
| estancia | S, I, U, D | S | Propietario |
| solicitud_adopcion | S, I, U, D | S | Propietario |
| adopcion | S, I, U, D | S | Propietario |
| seguimiento | S, I, U, D | S | Propietario |
| clinica | S, I, U, D | S | Propietario |
| vacuna | S, I, U, D | S | Propietario |
| atencion_medica | S, I, U, D | S | Propietario |
| vacunacion | S, I, U, D | S | Propietario |
| cirugia | S, I, U, D | S | Propietario |
| tratamiento | S, I, U, D | S | Propietario |
