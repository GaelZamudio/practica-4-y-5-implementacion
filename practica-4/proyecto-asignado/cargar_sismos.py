#!/usr/bin/env python3
"""
cargar_sismos.py - Carga el almacén de datos de sismos (fork de
Seismic-Data-Visualization-System) en PostgreSQL.

Lee los archivos de la carpeta sql/ del repositorio (00 a 05), que traen el
esquema y los datos como INSERT, los convierte al vuelo a CSV y los carga con
COPY.

Cumple los requisitos del ejercicio 1.4:
  1. Repetible      CREATE TABLE IF NOT EXISTS + INSERT ... ON CONFLICT DO NOTHING
                    (o NOT EXISTS en la tabla de hechos, que no tiene llave).
                    Ejecutarlo dos veces no duplica renglones ni termina en error.
  2. Ordenado       zonas, economía, tiempo y sismos primero; los hechos al final.
  3. Todo o nada    una sola transacción; ante cualquier falla hace ROLLBACK y
                    dice cuál renglón falló y por qué.
  4. Con cuentas    al terminar informa, por tabla, leídos / insertados /
                    rechazados (ya existían) / total en la tabla.
  5. Sin credenciales  la conexión sale de PGHOST, PGPORT, PGDATABASE, PGUSER y
                    PGPASSWORD (variables de entorno estándar de libpq).
  6. Eficiente      COPY en lugar de un INSERT por renglón, y compara los
                    tiempos de ambos métodos con la misma muestra.

Uso:
  export PGHOST=localhost PGPORT=5432 PGDATABASE=sismos PGUSER=... PGPASSWORD=...
  python3 cargar_sismos.py --datos /ruta/a/Seismic-Data-Visualization-System/sql
  python3 cargar_sismos.py --datos ./sql --limite 500     # carga reducida (mín. 200)
  python3 cargar_sismos.py --datos ./sql --dry-run        # prueba y revierte al final
"""
import argparse
import csv
import io
import os
import re
import sys
import time

import psycopg2

MIN_REGISTROS = 200          # el ejercicio pide al menos 200 registros
NULO = r"\N"                 # marca de NULL en el CSV que se manda a COPY

# Orden de carga: primero las tablas de las que dependen las demás.
# (tabla, archivo, columnas de la llave natural)
ORDEN = [
    ("dim_zonas", "01-dim_zonas.sql", ["id_zonas"]),
    ("dim_economia", "04-dim_economia.sql", ["id_economia"]),
    ("dim_tiempo", "02-dim_tiempo.sql", ["id_tiempo"]),
    ("dim_sismos", "03-dim_sismos.sql", ["id_sismo"]),
    ("fact_impacto_sismos_imputed", "05-fact_impacto_sismos_imputed.sql",
     ["id_sismo", "id_zonas", "id_economia", "id_tiempo"]),
]
HECHOS = "fact_impacto_sismos_imputed"
ARCHIVO_DDL = "00-datawarehouse_tables.sql"


class CargaError(Exception):
    """Falla de datos o de reglas: se informa y se revierte todo."""


# ---------------------------------------------------------------- lectura ----
ENCABEZADO = re.compile(r"INSERT INTO\s+(\w+)\s*\(([^)]*)\)\s*VALUES", re.I)
TUPLA = re.compile(r"\(((?:[^()']|'(?:[^']|'')*')*)\)")
VALOR = re.compile(r"\s*('(?:[^']|'')*'|[^,']+?)\s*(?:,|$)")


def leer_inserts(ruta):
    """Devuelve (columnas, generador de renglones) de un archivo de INSERT.
    Cada renglón es una lista de campos ya listos para el CSV."""
    with open(ruta, encoding="utf-8") as f:
        primera = f.readline()
    m = ENCABEZADO.search(primera)
    if not m:
        raise CargaError(f"{os.path.basename(ruta)}: no reconozco el INSERT de la línea 1")
    columnas = [c.strip() for c in m.group(2).split(",")]

    def generador():
        with open(ruta, encoding="utf-8") as f:
            for linea in f:
                resto = linea[ENCABEZADO.search(linea).end():] if linea.startswith("INSERT") else linea
                for t in TUPLA.finditer(resto):
                    campos = []
                    for v in VALOR.findall(t.group(1)):
                        if v.startswith("'"):
                            campos.append(v[1:-1].replace("''", "'"))
                        elif v.upper() == "NULL":
                            campos.append(NULO)
                        else:
                            campos.append(v)
                    if len(campos) != len(columnas):
                        raise CargaError(
                            f"{os.path.basename(ruta)}: un renglón trae {len(campos)} valores "
                            f"y la tabla espera {len(columnas)}: {t.group(0)[:120]}")
                    yield campos
    return columnas, generador()


class FlujoCSV(io.RawIOBase):
    """Archivo falso de solo lectura que alimenta a COPY sin cargar todo en memoria."""

    def __init__(self, renglones):
        self.renglones = iter(renglones)
        self.buf = b""
        self.cuenta = 0

    def readable(self):
        return True

    def readinto(self, destino):
        while len(self.buf) < len(destino):
            lote = io.StringIO()
            w = csv.writer(lote, lineterminator="\n")
            n = 0
            for r in self.renglones:
                w.writerow(r)
                n += 1
                if n == 5000:
                    break
            if n == 0:
                break
            self.cuenta += n
            self.buf += lote.getvalue().encode("utf-8")
        k = min(len(destino), len(self.buf))
        destino[:k] = self.buf[:k]
        self.buf = self.buf[k:]
        return k


# ------------------------------------------------------------------ carga ----
def conectar():
    faltan = [v for v in ("PGDATABASE", "PGUSER") if not os.environ.get(v)]
    if faltan:
        raise CargaError("Faltan variables de entorno: " + ", ".join(faltan) +
                         ". Define también PGHOST, PGPORT y PGPASSWORD si las necesitas.")
    return psycopg2.connect()   # libpq lee PGHOST/PGPORT/PGDATABASE/PGUSER/PGPASSWORD


def crear_esquema(cur, carpeta):
    ruta = os.path.join(carpeta, ARCHIVO_DDL)
    with open(ruta, encoding="utf-8") as f:
        ddl = f.read()
    # El DDL del repositorio crea la tabla de hechos sin IF NOT EXISTS, lo que
    # haría fallar una segunda ejecución.
    ddl = re.sub(r"CREATE TABLE (?!IF NOT EXISTS)", "CREATE TABLE IF NOT EXISTS ", ddl, flags=re.I)
    cur.execute(ddl)


def filtrar_limite(tabla, columnas, renglones, limite):
    """Carga reducida: se queda con los sismos y tiempos con id < limite."""
    if limite is None:
        return renglones
    pos = {c: i for i, c in enumerate(columnas)}
    if tabla in ("dim_sismos", "dim_tiempo"):
        i = pos[columnas[0]]
        return (r for r in renglones if int(r[i]) < limite)
    if tabla == HECHOS:
        a, b = pos["id_sismo"], pos["id_tiempo"]
        return (r for r in renglones if int(r[a]) < limite and int(r[b]) < limite)
    return renglones


def verificar_huerfanos(cur, stg):
    """Antes de insertar hechos: avisa cuál renglón apunta a una dimensión que no existe."""
    cur.execute(f"""
        SELECT s._n, s.id_sismo, s.id_zonas, s.id_economia, s.id_tiempo,
               d1.id_sismo IS NULL, d2.id_zonas IS NULL,
               d3.id_economia IS NULL, d4.id_tiempo IS NULL,
               count(*) OVER ()
        FROM {stg} s
        LEFT JOIN dim_sismos   d1 ON d1.id_sismo   = s.id_sismo
        LEFT JOIN dim_zonas    d2 ON d2.id_zonas   = s.id_zonas
        LEFT JOIN dim_economia d3 ON d3.id_economia = s.id_economia
        LEFT JOIN dim_tiempo   d4 ON d4.id_tiempo  = s.id_tiempo
        WHERE d1.id_sismo IS NULL OR d2.id_zonas IS NULL
           OR d3.id_economia IS NULL OR d4.id_tiempo IS NULL
        ORDER BY s._n LIMIT 1""")
    r = cur.fetchone()
    if r:
        n, sis, zon, eco, tie, f1, f2, f3, f4, total = r
        motivos = [f"{c}={v} no existe en {t}" for fallo, c, v, t in
                   [(f1, "id_sismo", sis, "dim_sismos"), (f2, "id_zonas", zon, "dim_zonas"),
                    (f3, "id_economia", eco, "dim_economia"), (f4, "id_tiempo", tie, "dim_tiempo")]
                   if fallo]
        raise CargaError(
            f"{HECHOS}, renglón {n} del archivo: " + "; ".join(motivos) +
            f". En total {total} renglones de hechos apuntan a dimensiones inexistentes.")


def cargar_tabla(cur, carpeta, tabla, archivo, llave, limite):
    t0 = time.perf_counter()
    columnas, renglones = leer_inserts(os.path.join(carpeta, archivo))
    renglones = filtrar_limite(tabla, columnas, renglones, limite)
    lista = ", ".join(columnas)
    stg = f"stg_{tabla}"

    # Tabla de paso: mismas columnas, sin llaves ni restricciones; _n guarda el
    # número de renglón para poder reportar cuál falló.
    cur.execute(f"CREATE TEMP TABLE {stg} (LIKE {tabla} INCLUDING DEFAULTS) ON COMMIT DROP")
    cur.execute(f"ALTER TABLE {stg} ADD COLUMN _n BIGSERIAL")

    flujo = FlujoCSV(renglones)
    cur.copy_expert(
        f"COPY {stg} ({lista}) FROM STDIN WITH (FORMAT csv, NULL '{NULO}')",
        io.BufferedReader(flujo, buffer_size=1 << 20))
    leidos = flujo.cuenta

    if tabla == HECHOS:
        verificar_huerfanos(cur, stg)
        cond = " AND ".join(f"f.{c} = s.{c}" for c in llave)
        cur.execute(f"""
            INSERT INTO {tabla} ({lista})
            SELECT {lista} FROM (
                SELECT DISTINCT ON ({', '.join(llave)}) {lista}
                FROM {stg} ORDER BY {', '.join(llave)}, _n) s
            WHERE NOT EXISTS (SELECT 1 FROM {tabla} f WHERE {cond})""")
    else:
        cur.execute(f"""
            INSERT INTO {tabla} ({lista})
            SELECT {lista} FROM {stg} ORDER BY _n
            ON CONFLICT ({', '.join(llave)}) DO NOTHING""")
    insertados = cur.rowcount
    cur.execute(f"SELECT count(*) FROM {tabla}")
    total = cur.fetchone()[0]
    return {"tabla": tabla, "leidos": leidos, "insertados": insertados,
            "rechazados": leidos - insertados, "total": total,
            "seg": time.perf_counter() - t0}


# -------------------------------------------------------------- benchmark ----
def comparar_tiempos(cur, carpeta, muestra):
    """Mide COPY contra un INSERT por renglón con los mismos renglones de dim_sismos
    (en tablas temporales sin llaves, para que ninguno cargue con verificaciones extra)."""
    columnas, gen = leer_inserts(os.path.join(carpeta, "03-dim_sismos.sql"))
    filas = []
    for r in gen:
        filas.append(r)
        if len(filas) == muestra:
            break
    lista = ", ".join(columnas)
    marcas = ", ".join(["%s"] * len(columnas))

    cur.execute("CREATE TEMP TABLE bench_insert (LIKE dim_sismos) ON COMMIT DROP")
    cur.execute("CREATE TEMP TABLE bench_copy (LIKE dim_sismos) ON COMMIT DROP")

    t0 = time.perf_counter()
    for r in filas:
        cur.execute(f"INSERT INTO bench_insert ({lista}) VALUES ({marcas})",
                    [None if v == NULO else v for v in r])
    t_insert = time.perf_counter() - t0

    t0 = time.perf_counter()
    flujo = FlujoCSV(iter(filas))
    cur.copy_expert(f"COPY bench_copy ({lista}) FROM STDIN WITH (FORMAT csv, NULL '{NULO}')",
                    io.BufferedReader(flujo, buffer_size=1 << 20))
    t_copy = time.perf_counter() - t0
    return len(filas), t_insert, t_copy


# ------------------------------------------------------------------ salida ----
def imprimir_cuentas(res):
    print("\nResumen de la carga")
    print(f"{'tabla':<30}{'leídos':>10}{'insertados':>12}{'rechazados':>12}{'total en tabla':>16}{'seg':>8}")
    for r in res:
        print(f"{r['tabla']:<30}{r['leidos']:>10,}{r['insertados']:>12,}"
              f"{r['rechazados']:>12,}{r['total']:>16,}{r['seg']:>8.1f}")
    print("(rechazados = renglones que no se insertaron porque ya existían en la tabla)")


def main():
    ap = argparse.ArgumentParser(description="Carga el almacén de sismos con COPY.")
    ap.add_argument("--datos", default=os.environ.get("SISMOS_SQL_DIR", "./sql"),
                    help="carpeta sql/ del repositorio (por defecto ./sql o $SISMOS_SQL_DIR)")
    ap.add_argument("--limite", type=int, default=None,
                    help=f"carga reducida: solo sismos/tiempos con id menor a N (mínimo {MIN_REGISTROS})")
    ap.add_argument("--muestra", type=int, default=20000,
                    help="renglones para comparar COPY contra INSERT por renglón")
    ap.add_argument("--sin-benchmark", action="store_true", help="omite la comparación de tiempos")
    ap.add_argument("--dry-run", action="store_true", help="hace todo y revierte al final")
    args = ap.parse_args()

    if args.limite is not None and args.limite < MIN_REGISTROS:
        sys.exit(f"--limite debe ser al menos {MIN_REGISTROS}: el ejercicio pide mínimo "
                 f"{MIN_REGISTROS} registros.")

    conn = None
    try:
        conn = conectar()
        cur = conn.cursor()
        t_ini = time.perf_counter()
        crear_esquema(cur, args.datos)

        res = [cargar_tabla(cur, args.datos, t, a, k, args.limite) for t, a, k in ORDEN]

        total_leidos = sum(r["leidos"] for r in res)
        if total_leidos < MIN_REGISTROS:
            raise CargaError(f"Solo se leyeron {total_leidos} registros; el mínimo es {MIN_REGISTROS}.")

        bench = None
        if not args.sin_benchmark:
            bench = comparar_tiempos(cur, args.datos, args.muestra)

        if args.dry_run:
            conn.rollback()
            print("MODO PRUEBA (--dry-run): todo se ejecutó y se revirtió; no quedó nada guardado.")
        else:
            conn.commit()
        imprimir_cuentas(res)
        print(f"\nRegistros leídos en total: {total_leidos:,} (mínimo pedido: {MIN_REGISTROS}) OK")
        print(f"Tiempo total: {time.perf_counter() - t_ini:.1f} s")

        if bench:
            n, t_i, t_c = bench
            tot_sismos = next(r["leidos"] for r in res if r["tabla"] == "dim_sismos")
            print(f"\nCOPY contra INSERT por renglón (misma muestra de {n:,} renglones de dim_sismos)")
            print(f"  INSERT por renglón: {t_i:8.2f} s")
            print(f"  COPY:               {t_c:8.2f} s   ({t_i / t_c:,.0f} veces más rápido)")
            print(f"  Extrapolado a los {tot_sismos:,} renglones de dim_sismos: "
                  f"INSERT ~{t_i / n * tot_sismos:,.0f} s contra COPY ~{t_c / n * tot_sismos:,.1f} s (estimado)")
    except CargaError as e:
        if conn:
            conn.rollback()
        sys.exit(f"\nCARGA REVERTIDA. {e}")
    except psycopg2.Error as e:
        if conn:
            conn.rollback()
        d = e.diag
        partes = [d.message_primary or str(e).strip()]
        if d.message_detail:
            partes.append("Detalle: " + d.message_detail)
        if d.context:
            partes.append("Dónde: " + d.context.strip().replace("\n", " | "))
        sys.exit("\nCARGA REVERTIDA. Falló la base de datos. " + " ".join(partes))
    finally:
        if conn:
            conn.close()


if __name__ == "__main__":
    main()
