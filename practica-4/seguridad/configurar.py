"""Configura 1.6 de forma transaccional. Requiere psycopg 3 y variables de entorno."""
import os
from pathlib import Path
import psycopg
from psycopg import sql


def required(name):
    value = os.environ.get(name)
    if not value:
        raise ValueError(f"Falta la variable de entorno {name}")
    return value


def main():
    passwords = {u: required(v) for u, v in {
        "huellared_app": "HUELLARED_APP_PASSWORD",
        "huellared_consulta": "HUELLARED_CONSULTA_PASSWORD",
        "huellared_admin": "HUELLARED_ADMIN_PASSWORD",
    }.items()}
    with psycopg.connect(host=os.environ.get("PGHOST", "localhost"),
                          port=required("POSTGRES_PORT"),
                          dbname=required("POSTGRES_DB"),
                          user=required("POSTGRES_USER"),
                          password=required("POSTGRES_PASSWORD")) as conn:
        conn.execute(Path(__file__).with_name("roles.sql").read_text(encoding="utf-8-sig"))
        for user, role in [("huellared_app", "hr_app"),
                           ("huellared_consulta", "hr_consulta"),
                           ("huellared_admin", "hr_admin")]:
            if not conn.execute("SELECT 1 FROM pg_roles WHERE rolname=%s", (user,)).fetchone():
                conn.execute(sql.SQL("CREATE ROLE {} LOGIN").format(sql.Identifier(user)))
            conn.execute(sql.SQL("ALTER ROLE {} LOGIN INHERIT NOSUPERUSER NOCREATEDB "
                                 "NOCREATEROLE NOREPLICATION NOBYPASSRLS PASSWORD {}").format(
                                     sql.Identifier(user), sql.Literal(passwords[user])))
            conn.execute(sql.SQL("GRANT {} TO {}").format(sql.Identifier(role), sql.Identifier(user)))
        for role in ("hr_app", "hr_consulta", "hr_admin"):
            conn.execute(sql.SQL("GRANT CONNECT ON DATABASE {} TO {}").format(
                sql.Identifier(required("POSTGRES_DB")), sql.Identifier(role)))
    print("Roles, usuarios y permisos configurados; transacción confirmada.")


if __name__ == "__main__":
    try:
        main()
    except ValueError as exc:
        raise SystemExit(str(exc)) from None
    except psycopg.Error as exc:
        # No imprimir el SQL ni los detalles: podrían contener una contraseña.
        raise SystemExit(f"Configuración revertida. Error PostgreSQL "
                         f"{exc.sqlstate or 'de conexión'}; revisa la conexión, "
                         "los privilegios y la ejecución previa del esquema y 001.") from None
    except Exception:
        # Evita mostrar sentencias que puedan contener contraseñas.
        raise SystemExit("Configuración cancelada y revertida. Revisa conexión, variables, "
                         "privilegios del administrador y ejecución previa del esquema y 001.")
