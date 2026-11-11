# Usuarios y permisos — HuellaRed

Ejercicio 1.6 · PostgreSQL 17 · Responsable: Gael.

## Roles y usuarios

| Rol (NOLOGIN) | Usuario (LOGIN) | Propósito |
|---|---|---|
| hr_app | huellared_app | Cargar y mantener los datos del proyecto: SELECT, INSERT y UPDATE sobre sus 23 tablas; DELETE solo en hogar_especie, rescate_rescatista y solicitud_adopcion. |
| hr_consulta | huellared_consulta | Consultar las 23 tablas sin modificarlas. |
| hr_admin | huellared_admin | Administrar tablas y tipos del proyecto, conceder permisos y efectuar cambios DDL. No administra roles ni bases del servidor. |

Los usuarios heredan los permisos de su rol. El administrador del servidor solo configura inicialmente estos objetos. El rol hr_admin pasa a ser propietario de las tablas y tipos del proyecto. Para crear objetos nuevos como propietario común, el administrador debe ejecutar `SET ROLE hr_admin`. No se conceden permisos automáticos sobre futuras tablas.

El rol de aplicación atiende el registro y mantenimiento de las 23 tablas: SELECT para consultar registros y sus relaciones; INSERT para altas y carga; UPDATE para corregir datos y registrar cambios de estado; DELETE únicamente sobre hogar_especie, rescate_rescatista y solicitud_adopcion, sujeto a las claves foráneas. El cargador usa ese mismo rol. No recibe TRUNCATE, creación de objetos permanentes en public ni propiedad de tablas. Consulta solo recibe SELECT sobre las tablas. Los identificadores son enteros asignados por el generador y conservados por la carga: el esquema no usa secuencias que requieran concesiones adicionales. Se retira CREATE de PUBLIC en el esquema public. Este alcance corresponde a una base dedicada a HuellaRed con los usuarios nuevos de esta práctica.

## Archivos y preparación

- `seguridad/roles.sql`: roles y concesiones, con sentencias SQL ejecutables.
- `seguridad/configurar.py`: ejecuta el SQL y crea los usuarios con contraseñas tomadas del entorno, en una misma transacción.
- `seguridad/pruebas-permisos.sql`: casos para ejecutar por separado en pgAdmin.
- `seguridad/probar.py`: ejecuta esos mismos casos con conexiones reales de cada usuario y comprueba la conexión del cargador. Revierte los datos de prueba y restaura el permiso retirado.
- `poblar/cargar.py`: ejecuta un archivo SQL de datos usando exclusivamente `huellared_app`.

El entorno de estas prácticas usa el contenedor `postgres_huellared_p45` y guarda sus datos en `data/`.

Completar localmente las variables de `.env.example` en `.env`, que está excluido de Git: POSTGRES_DB, POSTGRES_USER, POSTGRES_PASSWORD, POSTGRES_PORT, PGHOST y las tres HUELLARED_*_PASSWORD. Mantener las variables POSTGRES_* de Docker con las credenciales del administrador inicial; las nuevas contraseñas pertenecen a los usuarios de la práctica.

Desde la raíz, con Docker Desktop encendido, ejecutar `docker compose up -d`.
PostgreSQL inicia; el servicio configurar ejecuta `docker/inicializar.py` (esquema, migración y roles), y poblar carga como huellared_app. Comprobar `docker compose ps -a`: PostgreSQL debe estar saludable y ambos auxiliares en Exited (0). La configuración está automatizada; los siguientes comandos de Python son una alternativa para ejecutarla fuera de Docker.

Para detener sin borrar datos, usar `docker compose stop`; para iniciar de nuevo, `docker compose up -d`.

El programa lee variables del entorno, no carga `.env` automáticamente. Desde la raíz del repositorio, preparar las dependencias una vez:

```powershell
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install "psycopg[binary]>=3.2,<4" "python-dotenv[cli]>=1,<2"
```

Configurar usuarios y permisos con las variables de `.env`:

```powershell
.\.venv\Scripts\python.exe -m dotenv -f .env run -- .\.venv\Scripts\python.exe practica-4/seguridad/configurar.py
```

La configuración es transaccional y admite repetirse para estos mismos usuarios y roles. Si falla, no confirma cambios. Se debe realizar sobre los nombres reservados de esta práctica, sin asignarles otros roles adicionales que amplíen sus permisos. Se ejecutó dos veces correctamente; la salida está en [la evidencia de configuración](../evidencias/1.6-permisos/configuracion.png). `.env` y `.venv` están excluidos de Git.

## Conexión del cargador (ejercicio 1.4)

`poblar/cargar.py` se conecta como `huellared_app`, con contraseña tomada de `HUELLARED_APP_PASSWORD`, host PGHOST, puerto POSTGRES_PORT y base POSTGRES_DB. No usa POSTGRES_USER ni POSTGRES_PASSWORD para autenticar la carga. Su conexión es:

```python
conn = psycopg.connect(
    host=os.environ.get("PGHOST", "localhost"),
    port=os.environ["POSTGRES_PORT"],
    dbname=os.environ["POSTGRES_DB"],
    user="huellared_app",
    password=os.environ["HUELLARED_APP_PASSWORD"],
)
```

Para ejecutar un archivo de datos:

```powershell
.\.venv\Scripts\python.exe -m dotenv -f .env run -- .\.venv\Scripts\python.exe practica-4/poblar/cargar.py ruta/al/archivo.sql
```

El archivo debe contener SQL de datos, sin órdenes de psql ni BEGIN/COMMIT/ROLLBACK: la transacción la controla Python. La opción `--prueba` ejecuta la carga y la revierte. La prueba L1 utiliza este mismo programa para insertar una zona de prueba, comprueba `current_user` y `session_user`, y verifica que no quedó la fila después del ROLLBACK:

```text
Carga: current_user=huellared_app, session_user=huellared_app
INSERT 0 1
ROLLBACK: carga de prueba revertida.
Filas de prueba después del ROLLBACK: 0
```

Esto demuestra el requisito de conexión del 1.6. El generador, la carga del conjunto completo, sus conteos y la repetibilidad del 1.4 se desarrollarán en el siguiente ejercicio sobre esta entrada de carga.

## Pruebas y evidencias

Las pruebas se ejecutaron sobre PostgreSQL 17.11 con conexiones autenticadas como cada usuario, el esquema y la migración 001 aplicados y las tablas inicialmente vacías. La salida completa, incluidas las sentencias y los mensajes del gestor, está en [evidencias/permisos-1.png](../evidencias/1.6-permisos/permisos-1.png), [evidencias/permisos-2.png](../evidencias/1.6-permisos/permisos-2.png) y [evidencias/permisos-3.png](../evidencias/1.6-permisos/permisos-3.png). No se necesitan datos del generador para comprobar los permisos.

Para repetirlas y guardar su salida desde PowerShell:

```powershell
$env:PYTHONIOENCODING = 'utf-8'
$salida = & .\.venv\Scripts\python.exe -m dotenv -f .env run -- .\.venv\Scripts\python.exe practica-4/seguridad/probar.py
if ($LASTEXITCODE -ne 0) { throw 'Fallaron las pruebas de permisos' }
$salida | Set-Content -Encoding utf8 evidencias/1.6-permisos.txt
```

También se pueden repetir manualmente en pgAdmin: registrar tres conexiones a la misma base con los usuarios anteriores y ejecutar cada caso seleccionado del archivo SQL desde la conexión indicada, con autocommit habilitado. No ejecutar el archivo entero de una sola vez. Ante un error dentro de una transacción abierta, ejecutar ROLLBACK antes de continuar.

| Caso | Usuario | Resultado esperado | Resultado real |
|---|---|---|---|
| A1 | huellared_app | SELECT funciona; UPDATE sin filas funciona y afecta 0 filas. | Identidad `huellared_app`; conteo 0; `UPDATE 0`. |
| A2 | huellared_app | ALTER TABLE rechazado: se requiere ser propietario. | `42501: must be owner of table animal`. |
| C1 | huellared_consulta | SELECT funciona aunque la tabla esté vacía. | Identidad `huellared_consulta`; conteo 0. |
| C2 | huellared_consulta | DELETE rechazado por falta de permiso sobre persona. | `42501: permission denied for table persona`. |
| D1 | huellared_admin | CREATE TABLE funciona; ROLLBACK retira el objeto de prueba. | `CREATE TABLE` y `ROLLBACK`. |
| D2 | huellared_admin | CREATE ROLE rechazado por carecer de CREATEROLE. | `42501: permission denied to create role`. |
| R1–R2 | admin retira; consulta intenta leer | REVOKE confirmado; SELECT sobre persona deja de funcionar. | `REVOKE`; `42501: permission denied for table persona`. |
| R3–R4 | admin restaura; consulta vuelve a leer | GRANT confirmado; SELECT funciona de nuevo. | `GRANT`; SELECT devuelve conteo 0. |
| L1 | huellared_app, desde cargar.py | Inserción permitida, revertida al terminar la prueba. | `INSERT 0 1`; identidad de aplicación; 0 filas de prueba después del ROLLBACK. |

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

## Matriz de permisos sobre tablas actuales

S = SELECT; I = INSERT; U = UPDATE; D = DELETE. Administración incluye permisos de propietario (DDL y concesión de permisos) sobre cada tabla. La creación de usuarios permanece a cargo del administrador del servidor.

| Tabla | hr_app | hr_consulta | hr_admin |
|---|---|---|---|
| zona | S, I, U | S | Propietario |
| persona | S, I, U | S | Propietario |
| rescatista | S, I, U | S | Propietario |
| adoptante | S, I, U | S | Propietario |
| veterinario | S, I, U | S | Propietario |
| hogar_temporal | S, I, U | S | Propietario |
| hogar_especie | S, I, U, D | S | Propietario |
| rescate | S, I, U | S | Propietario |
| animal | S, I, U | S | Propietario |
| perro | S, I, U | S | Propietario |
| gato | S, I, U | S | Propietario |
| otro | S, I, U | S | Propietario |
| rescate_rescatista | S, I, U, D | S | Propietario |
| estancia | S, I, U | S | Propietario |
| solicitud_adopcion | S, I, U, D | S | Propietario |
| adopcion | S, I, U | S | Propietario |
| seguimiento | S, I, U | S | Propietario |
| clinica | S, I, U | S | Propietario |
| vacuna | S, I, U | S | Propietario |
| atencion_medica | S, I, U | S | Propietario |
| vacunacion | S, I, U | S | Propietario |
| cirugia | S, I, U | S | Propietario |
| tratamiento | S, I, U | S | Propietario |


## Evidencias de ejecución

### Configuración de roles y usuarios

La captura documenta la configuración mediante Python. El arranque actual con Compose ejecuta esta misma configuración automáticamente.

![Configuración de roles y usuarios](../evidencias/1.6-permisos/configuracion.png)

### Pruebas de permisos

Las tres imágenes consecutivas corresponden a la salida de una misma ejecución, desde A1 hasta L1. La base estaba vacía, por lo que las consultas de conteo devuelven cero.

![Pruebas de permisos — parte 1 de 3](../evidencias/1.6-permisos/permisos-1.png)

![Pruebas de permisos — parte 2 de 3](../evidencias/1.6-permisos/permisos-2.png)

![Pruebas de permisos — parte 3 de 3](../evidencias/1.6-permisos/permisos-3.png)

La salida fotografiada cubre A1, A2, C1, C2, D1, D2, R1–R4 y L1. Los casos adicionales A3 y A4 del script actual comprueban la denegación de DELETE en adopcion y su autorización en solicitud_adopcion; se verificaron en la validación posterior y no aparecen en esta secuencia de imágenes.
