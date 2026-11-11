"""poblar.py - Ejercicio 1.4: carga de HuellaRed con un solo comando.

Genera los CSV sintéticos si no existen (datos/generar_datos.py), los carga con COPY en
tablas de paso y los inserta en el orden de las claves foráneas. Se conecta como
huellared_app (cargar.conectar), nunca como administrador, y usa solo variables de entorno.

  * Repetible: INSERT ... ON CONFLICT (clave primaria) DO NOTHING. Una segunda corrida
    no duplica renglones ni termina en error.
  * Ordenado: ORDEN lista primero las tablas de las que dependen las demás.
  * Todo o nada: una sola transacción. Si un renglón viola una restricción, se revierte
    toda la carga y el mensaje dice qué tabla, qué restricción y por qué.
  * Con cuentas: por tabla informa leídos, insertados, ya existían y rechazados.
  * Eficiente: COPY hacia tablas de paso; --tiempos compara contra un INSERT por renglón.

Uso (desde la raíz del repositorio):
  python practica-4/poblar/poblar.py                    carga todo
  python practica-4/poblar/poblar.py --rechazos [F.md]  carga y prueba renglones inválidos (todo se revierte)
  python practica-4/poblar/poblar.py --tiempos          compara COPY contra INSERT por renglón (se revierte)
  python practica-4/poblar/poblar.py --regenerar        vuelve a generar los CSV antes de cargar
"""
import argparse
import csv
import json
import re
import sys
import time
from datetime import date
from pathlib import Path

import psycopg

AQUI = Path(__file__).resolve().parent
RAIZ = AQUI.parent                                  # practica-4/
sys.path.insert(0, str(AQUI))                       # cargar.py
sys.path.insert(0, str(RAIZ / "datos"))             # generar_datos.py
from cargar import conectar                         # noqa: E402  (conexión como huellared_app)
import generar_datos                                # noqa: E402

CARPETA = RAIZ / "datos" / "generados"

# Primero las tablas de las que dependen las demás (padres antes que hijas).
ORDEN = ["zona", "persona", "rescatista", "adoptante", "veterinario", "hogar_temporal", "hogar_especie",
         "clinica", "vacuna", "rescate", "animal", "perro", "gato", "otro", "rescate_rescatista",
         "estancia", "solicitud_adopcion", "adopcion", "seguimiento", "atencion_medica",
         "vacunacion", "cirugia", "tratamiento"]

SQL_TIPOS = """SELECT a.attname, format_type(a.atttypid, a.atttypmod)
               FROM pg_attribute a
               WHERE a.attrelid = %s::regclass AND a.attnum > 0 AND NOT a.attisdropped"""
SQL_PK = """SELECT a.attname FROM pg_index i
            JOIN pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY (i.indkey)
            WHERE i.indrelid = %s::regclass AND i.indisprimary"""


def tipos_de(conn, tabla):
    return dict(conn.execute(SQL_TIPOS, (f"public.{tabla}",)).fetchall())


def cargar_tabla(conn, tabla):
    """COPY del CSV a una tabla de paso y de ahí a la tabla real. Devuelve (leídos, insertados)."""
    archivo = CARPETA / f"{tabla}.csv"
    with open(archivo, newline="", encoding="utf-8") as f:
        cabecera = next(csv.reader(f))
    tipos = tipos_de(conn, tabla)
    # Validar longitud antes del cast: VARCHAR(n)/CHAR(n) explícitos pueden truncar.
    # Identifica el renglón original sin alterar los datos del CSV.
    with open(archivo, newline="", encoding="utf-8") as f:
        for numero, fila in enumerate(csv.DictReader(f), 2):
            for columna, valor in fila.items():
                if columna not in tipos or valor is None:
                    raise ValueError(f"{archivo.name}, registro {numero}: cabecera o fila inválida")
                limite = re.fullmatch(r"(?:character varying|character)\((\d+)\)", tipos[columna])
                maximo = int(limite.group(1)) if limite else (10 if tipos[columna].split('.')[-1] == 'd_telefono' else None)
                if maximo is not None and len(valor) > maximo:
                    raise ValueError(f"{archivo.name}, registro {numero}, columna {columna}: "
                                     f"longitud {len(valor)} excede {maximo}")
    pk = [r[0] for r in conn.execute(SQL_PK, (f"public.{tabla}",)).fetchall()]
    paso = f"paso_{tabla}"
    columnas = ", ".join(f'"{c}"' for c in cabecera)
    # La tabla de paso es todo texto y sin restricciones: COPY nunca falla por el contenido.
    # Las restricciones las aplica la tabla real al insertar, con los tipos del esquema.
    conn.execute(f'CREATE TEMP TABLE {paso} ({", ".join(f"{chr(34)}{c}{chr(34)} text" for c in cabecera)}) '
                 "ON COMMIT DROP")
    with conn.cursor() as cur:
        with cur.copy(f"COPY {paso} ({columnas}) FROM STDIN WITH (FORMAT csv, HEADER true, ENCODING 'UTF8')") as copia:
            with open(archivo, "rb") as f:
                while bloque := f.read(1 << 16):
                    copia.write(bloque)
    leidos = conn.execute(f"SELECT count(*) FROM {paso}").fetchone()[0]
    expresiones = ", ".join(f"NULLIF(\"{c}\", '')::{tipos[c]}" for c in cabecera)
    cur = conn.execute(f"INSERT INTO public.{tabla} ({columnas}) SELECT {expresiones} FROM {paso} "
                       f"ON CONFLICT ({', '.join(pk)}) DO NOTHING")
    return leidos, cur.rowcount


def imprimir_cuentas(cuentas, titulo):
    print(f"\n{titulo}")
    print(f"{'tabla':22s}{'leídos':>8s}{'insertados':>12s}{'ya existían':>13s}{'rechazados':>12s}")
    total = [0, 0, 0, 0]
    for tabla, leidos, insertados, rechazados in cuentas:
        existian = leidos - insertados - rechazados
        print(f"{tabla:22s}{leidos:8d}{insertados:12d}{existian:13d}{rechazados:12d}")
        for i, v in enumerate((leidos, insertados, existian, rechazados)):
            total[i] += v
    print(f"{'TOTAL':22s}{total[0]:8d}{total[1]:12d}{total[2]:13d}{total[3]:12d}")


def informar_fallo(tabla, exc):
    d = exc.diag
    print(f"\nCARGA REVERTIDA. Falló la tabla '{tabla}': un renglón fue rechazado.")
    print(f"  SQLSTATE   : {exc.sqlstate}")
    if d.constraint_name:
        print(f"  Restricción: {d.constraint_name}")
    print(f"  Motivo     : {d.message_primary}")
    if d.message_detail:
        print(f"  Detalle    : {d.message_detail}")


def cargar_todo(conn):
    """Carga las 23 tablas en una sola transacción. Si algo falla, informa y sale con código 1."""
    cuentas = []
    for tabla in ORDEN:
        try:
            leidos, insertados = cargar_tabla(conn, tabla)
        except psycopg.Error as exc:
            conn.rollback()
            imprimir_cuentas(cuentas, "Avance provisional antes del error (todo fue revertido):")
            informar_fallo(tabla, exc)
            raise SystemExit(1)
        except (ValueError, KeyError, OSError) as exc:
            conn.rollback()
            raise SystemExit(f"CARGA REVERTIDA. Tabla {tabla}: {exc}") from None
        cuentas.append((tabla, leidos, insertados, 0))
    return cuentas


def probar_rechazos(conn, salida):
    """Intenta insertar renglones inválidos a propósito, uno por uno, cada uno en su punto de recuperación."""
    casos = json.loads((CARPETA / "invalidos.json").read_text(encoding="utf-8"))
    filas, aceptadas = [], 0
    print(f"\nRenglones inválidos a propósito: {len(casos)}")
    for n, caso in enumerate(casos, 1):
        tabla, fila = caso["tabla"], caso["fila"]
        tipos = tipos_de(conn, tabla)
        columnas = list(fila)
        sql = (f"INSERT INTO public.{tabla} ({', '.join(columnas)}) "
               f"VALUES ({', '.join('%s::' + tipos[c] for c in columnas)})")
        try:
            with conn.transaction():              # SAVEPOINT: solo este renglón se deshace si falla
                conn.execute(sql, [fila[c] for c in columnas])
            restriccion, sqlstate, mensaje = "(ninguna)", "-", "ACEPTADO: hay un hueco en las restricciones"
            aceptadas += 1
        except psycopg.Error as exc:
            d = exc.diag
            restriccion = d.constraint_name or (f"NOT NULL ({d.column_name})" if d.column_name else "(tipo de dato)")
            sqlstate, mensaje = exc.sqlstate, (d.message_primary or "").replace("|", "/")
        print(f"{n:2d}. {tabla:18s} {caso['caso']}\n      -> {sqlstate} {restriccion}: {mensaje}")
        filas.append((n, tabla, caso["caso"], restriccion, sqlstate, mensaje))
    print(f"\nRechazados por el gestor: {len(casos) - aceptadas} de {len(casos)}. Aceptados (huecos): {aceptadas}.")
    if salida:
        lineas = ["| # | Tabla | Caso | Restricción que lo rechazó | SQLSTATE | Mensaje del gestor |",
                  "|---|---|---|---|---|---|"]
        lineas += [f"| {n} | `{t}` | {c} | `{r}` | {s} | {m} |" for n, t, c, r, s, m in filas]
        Path(salida).write_text("\n".join(lineas) + "\n", encoding="utf-8")
        print(f"Tabla en Markdown escrita en {salida}")
    return aceptadas


def comparar_tiempos(conn, tabla="atencion_medica"):
    """Mide la misma carga con COPY y con un INSERT por renglón, en tablas temporales."""
    with open(CARPETA / f"{tabla}.csv", newline="", encoding="utf-8") as f:
        lector = csv.reader(f)
        cabecera = next(lector)
        filas = [[v if v != "" else None for v in fila] for fila in lector]
    tipos = tipos_de(conn, tabla)
    columnas = ", ".join(cabecera)
    conn.execute(f"CREATE TEMP TABLE cmp_copy (LIKE public.{tabla}) ON COMMIT DROP")
    conn.execute(f"CREATE TEMP TABLE cmp_insert (LIKE public.{tabla}) ON COMMIT DROP")
    t0 = time.perf_counter()
    with conn.cursor() as cur:
        with cur.copy(f"COPY cmp_copy ({columnas}) FROM STDIN WITH (FORMAT csv, HEADER true)") as copia:
            with open(CARPETA / f"{tabla}.csv", "rb") as f:
                while bloque := f.read(1 << 16):
                    copia.write(bloque)
    t_copy = time.perf_counter() - t0
    sql = f"INSERT INTO cmp_insert ({columnas}) VALUES ({', '.join('%s::' + tipos[c] for c in cabecera)})"
    t0 = time.perf_counter()
    for fila in filas:
        conn.execute(sql, fila)
    t_insert = time.perf_counter() - t0
    print(f"\nTabla {tabla}: {len(filas)} renglones")
    print(f"  COPY                 : {t_copy * 1000:8.1f} ms")
    print(f"  INSERT por renglón   : {t_insert * 1000:8.1f} ms")
    print(f"  COPY es {t_insert / t_copy:.1f} veces más rápido")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--regenerar", action="store_true", help="vuelve a generar los CSV antes de cargar")
    ap.add_argument("--corte", help="fecha límite de los datos generados (AAAA-MM-DD); solo para pruebas")
    ap.add_argument("--rechazos", nargs="?", const="", metavar="SALIDA.md",
                    help="carga y prueba renglones inválidos; todo se revierte. Opcional: escribe la tabla en Markdown")
    ap.add_argument("--tiempos", action="store_true", help="compara COPY contra INSERT por renglón (se revierte)")
    args = ap.parse_args()

    if args.regenerar or not (CARPETA / "persona.csv").exists():
        corte = date.fromisoformat(args.corte) if args.corte else generar_datos.CORTE_POR_OMISION
        resumen = generar_datos.generar(CARPETA, corte)
        print(f"CSV generados en {CARPETA} ({sum(resumen.values())} renglones).")

    inicio = time.perf_counter()
    try:
        with conectar() as conn:
            quien = conn.execute("SELECT current_user, session_user").fetchone()
            print(f"Carga: current_user={quien[0]}, session_user={quien[1]}")
            if args.tiempos:
                comparar_tiempos(conn)
                conn.rollback()
                print("ROLLBACK: las tablas de la comparación eran temporales.")
                return
            cuentas = cargar_todo(conn)
            imprimir_cuentas(cuentas, "Cuentas de la carga:")
            if args.rechazos is not None:
                aceptadas = probar_rechazos(conn, args.rechazos)
                conn.rollback()
                print("ROLLBACK: la carga y las pruebas de rechazo se revirtieron; la base queda como estaba.")
                if aceptadas:
                    raise SystemExit(1)
                return
            conn.commit()
            print(f"\nCOMMIT: carga confirmada en {time.perf_counter() - inicio:.2f} s.")
    except KeyError as exc:
        raise SystemExit(f"Falta la variable de entorno {exc.args[0]}") from None
    except psycopg.OperationalError as exc:
        raise SystemExit(f"No se pudo conectar: {exc}") from None


if __name__ == "__main__":
    main()
