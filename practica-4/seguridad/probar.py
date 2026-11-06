"""Ejecuta los casos de pruebas-permisos.sql con conexiones de cada usuario."""
import os
from pathlib import Path
import re
import subprocess
import sys
import tempfile

import psycopg


def conectar(usuario, variable):
    return psycopg.connect(
        host=os.environ.get("PGHOST", "localhost"),
        port=os.environ["POSTGRES_PORT"], dbname=os.environ["POSTGRES_DB"],
        user=usuario, password=os.environ[variable],
    )


def caso(conn, nombre, sentencia, denegado=False, confirmar=False):
    print(f"\n=== {nombre} ===", flush=True)
    print(f"Usuario conectado: {conn.info.user}")
    print(sentencia.strip())
    try:
        cursor = conn.execute(sentencia)
        while True:
            if cursor.description:
                for fila in cursor.fetchall():
                    print(fila)
            print(cursor.statusmessage)
            if not cursor.nextset():
                break
        if denegado:
            raise AssertionError(f"{nombre}: la operación debía ser rechazada")
        if confirmar:
            conn.commit()
        else:
            conn.rollback()
    except psycopg.Error as exc:
        conn.rollback()
        print(f"SQLSTATE={exc.sqlstate}: {exc.diag.message_primary}")
        if not denegado or exc.sqlstate != "42501":
            raise
    finally:
        # También revierte una operación indebidamente permitida antes de abortar.
        conn.rollback()
    print("Resultado: correcto.", flush=True)


def main():
    texto = Path(__file__).with_name("pruebas-permisos.sql").read_text(encoding="utf-8-sig")
    partes = re.split(r"(?m)^-- ([ACDR][1-4]):[^\n]*\n", texto)
    casos = dict(zip(partes[1::2], partes[2::2]))
    with conectar("huellared_app", "HUELLARED_APP_PASSWORD") as app, \
         conectar("huellared_consulta", "HUELLARED_CONSULTA_PASSWORD") as consulta, \
         conectar("huellared_admin", "HUELLARED_ADMIN_PASSWORD") as admin:
        print("PostgreSQL", app.info.server_version)
        for nombre, conn in [("A1", app), ("A2", app), ("C1", consulta),
                             ("C2", consulta), ("D1", admin), ("D2", admin)]:
            caso(conn, nombre, casos[nombre], denegado=nombre.endswith("2"))
        try:
            caso(admin, "R1", casos["R1"], confirmar=True)
            caso(consulta, "R2", casos["R2"], denegado=True)
        finally:
            caso(admin, "R3", casos["R3"], confirmar=True)
        caso(consulta, "R4", casos["R4"])

        print("\n=== L1: conexión real del cargador ===", flush=True)
        # Elegir un ID libre sin depender de los datos del futuro generador.
        identificador = app.execute("SELECT LEAST(COALESCE(min(id_zona), 0), 0)-1 FROM public.zona").fetchone()[0]
        app.rollback()
        with tempfile.TemporaryDirectory() as temporal:
            archivo = Path(temporal) / "carga-prueba.sql"
            archivo.write_text(
                "INSERT INTO public.zona (id_zona, colonia, municipio, entidad) "
                f"VALUES ({identificador}, 'Prueba permisos {identificador}', "
                "'Prueba 1.6', 'Prueba 1.6');", encoding="utf-8")
            cargador = Path(__file__).parents[1] / "poblar" / "cargar.py"
            subprocess.run([sys.executable, str(cargador), str(archivo), "--prueba"], check=True)
        quedan = app.execute("SELECT count(*) FROM public.zona WHERE id_zona=%s", (identificador,)).fetchone()[0]
        app.rollback()
        assert quedan == 0, "La carga de prueba dejó datos"
        print(f"Filas de prueba después del ROLLBACK: {quedan}")
    print("\nTodas las pruebas del 1.6 pasaron. Permiso SELECT restaurado y datos de prueba revertidos.")


if __name__ == "__main__":
    main()
