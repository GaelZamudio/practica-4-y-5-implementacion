"""Generador de datos sintéticos de HuellaRed (ejercicios 1.3 y 1.4).

Escribe un CSV por tabla del esquema en practica-4/datos/generados/ y un archivo
invalidos.json con renglones inválidos a propósito, que sirven para probar qué
restricción rechaza cada uno (poblar.py --rechazos).

  * Semilla fija: dos ejecuciones producen exactamente los mismos archivos.
  * Solo usa la biblioteca estándar de Python.
  * Respeta esquema.sql y migraciones/001-dominios.sql: tipos, NOT NULL, UNIQUE,
    CHECK y claves foráneas. También respeta reglas del dominio que ninguna
    restricción cubre (un perro solo en la tabla perro, la madre es hembra y nació
    antes que la cría cuando ambas fechas se conocen, todo rescate tiene rescatista, toda adopción tiene una
    solicitud aprobada).
  * Los identificadores son enteros consecutivos asignados aquí, porque el esquema
    no usa secuencias.
  * Datos ficticios: los nombres y teléfonos se generan y podrían coincidir accidentalmente con datos reales
    (los correos usan el dominio reservado example.com).

Uso:  python generar_datos.py [--destino CARPETA] [--corte AAAA-MM-DD]
"""
import argparse
import csv
import json
import random
import unicodedata
from datetime import date, datetime, timedelta
from pathlib import Path

SEMILLA = 20261105
CORTE_POR_OMISION = date(2026, 10, 31)   # ningún dato es posterior a esta fecha
DESTINO_POR_OMISION = Path(__file__).resolve().parent / "generados"

N_PERSONAS = 420
N_RESCATES = 420
N_ANIMALES = 480
N_HOGARES = 60
N_CLINICAS = 25
RESCATISTAS = range(1, 91)       # personas 1-90
ADOPTANTES = range(71, 331)      # personas 71-330 (71-90 son ambas cosas: jerarquía solapada)
VETERINARIOS = range(331, 356)   # personas 331-355; 356-420 son solo personas

# ---------------------------------------------------------------- catálogos
ALCALDIAS = {
    "Cuauhtémoc": ["Centro", "Roma Norte", "Roma Sur", "Condesa", "Juárez", "Doctores", "Obrera",
                   "Guerrero", "Morelos", "Santa María la Ribera", "San Rafael", "Tabacalera", "Hipódromo"],
    "Benito Juárez": ["Del Valle Centro", "Narvarte Poniente", "Narvarte Oriente", "Portales Norte",
                      "Nápoles", "Álamos", "Santa Cruz Atoyac", "Xoco", "Insurgentes Mixcoac"],
    "Coyoacán": ["Del Carmen", "Santa Catarina", "Pedregal de Santo Domingo", "Copilco El Alto",
                 "Ajusco", "Los Reyes", "Santa Úrsula Coapa", "Villa Coyoacán"],
    "Iztapalapa": ["Santa Martha Acatitla", "San Miguel Teotongo", "Constitución de 1917", "Juan Escutia",
                   "Ermita Zaragoza", "Leyes de Reforma", "Paraje San Juan"],
    "Gustavo A. Madero": ["Lindavista", "San Felipe de Jesús", "Cuautepec de Madero", "Aragón La Villa",
                          "Industrial", "Martín Carrera", "Providencia", "Granjas Modernas"],
    "Álvaro Obregón": ["San Ángel", "Santa Fe", "Las Águilas", "Tizapán", "Olivar del Conde",
                       "Jardines del Pedregal", "Tolteca"],
    "Tlalpan": ["Tlalpan Centro", "Pedregal de San Nicolás", "Héroes de Padierna", "Fuentes del Pedregal",
                "San Pedro Mártir", "Toriello Guerra"],
    "Miguel Hidalgo": ["Polanco", "Anáhuac", "Tacuba", "Escandón", "San Miguel Chapultepec",
                       "Daniel Garza", "Observatorio"],
    "Azcapotzalco": ["Clavería", "San Álvaro", "Nueva Santa María", "Ángel Zimbrón", "Del Gas"],
    "Venustiano Carranza": ["Jardín Balbuena", "Moctezuma 2a Sección", "Peñón de los Baños", "Romero Rubio"],
    "Iztacalco": ["Agrícola Oriental", "Gabriel Ramos Millán", "Granjas México", "Juventino Rosas",
                  "Reforma Iztaccíhuatl"],
    "Xochimilco": ["Santa Cruz Acalpixca", "San Gregorio Atlapulco", "Santiago Tepalcatlalpan",
                   "Santiago Tulyehualco"],
    "Tláhuac": ["Del Mar", "San Francisco Tlaltenco", "Santa Catarina Yecahuizotl"],
    "La Magdalena Contreras": ["San Jerónimo Lídice", "San Bernabé Ocotepec", "Pueblo Nuevo Alto"],
    "Cuajimalpa de Morelos": ["Contadero", "Lomas de Vista Hermosa", "San Mateo Tlaltenango"],
    "Milpa Alta": ["Villa Milpa Alta", "San Antonio Tecómitl"],
}
ENTIDAD = "Ciudad de México"

NOMBRES_M = ["Luis", "Carlos", "Jorge", "Miguel", "Javier", "Alejandro", "Diego", "Fernando", "Ricardo",
             "Eduardo", "Sergio", "Pablo", "Andrés", "Héctor", "Raúl", "Iván", "Mauricio", "Óscar",
             "Rodrigo", "Emilio"]
NOMBRES_F = ["Ana", "María", "Laura", "Sofía", "Daniela", "Gabriela", "Fernanda", "Paola", "Mariana",
             "Karla", "Valeria", "Elena", "Patricia", "Verónica", "Lucía", "Andrea", "Claudia", "Rosa",
             "Carmen", "Alicia"]
SEGUNDOS = ["José", "Luis", "Carlos", "María", "Guadalupe", "Fernanda", "Isabel", "Antonio", "Eduardo",
            "del Carmen"]
APELLIDOS = ["García", "Hernández", "López", "Martínez", "González", "Pérez", "Rodríguez", "Sánchez",
             "Ramírez", "Cruz", "Flores", "Gómez", "Morales", "Vázquez", "Jiménez", "Reyes", "Díaz",
             "Torres", "Gutiérrez", "Ruiz", "Mendoza", "Aguilar", "Ortiz", "Castillo", "Romero", "Álvarez",
             "Chávez", "Rivera", "Juárez", "Domínguez", "Guerrero", "Estrada", "Cortés", "Vega", "Silva",
             "Navarro", "Ramos", "Salazar", "Medina", "Herrera"]
NOMBRES_ANIMAL = ["Canela", "Tizón", "Luna", "Max", "Rocky", "Bella", "Mishi", "Pelusa", "Chispa", "Toby",
                  "Nala", "Simba", "Coco", "Lola", "Firulais", "Mocha", "Bruno", "Kira", "Duque", "Maya",
                  "Pinto", "Galleta", "Osito", "Manchas", "Gordo", "Princesa", "Rufo", "Nube", "Trueno",
                  "Michi"]
COLORES = ["Negro", "Blanco", "Café", "Gris", "Naranja", "Atigrado", "Tricolor", "Beige", "Manchado", "Canela"]
SENAS = ["Cola cortada", "Oreja caída", "Mancha en el ojo", "Cicatriz en el lomo", "Collar rojo",
         "Manchas blancas en las patas", "Pelo largo", "Ojos de distinto color"]
CALLES = ["Av. Insurgentes Sur", "Calle Durango", "Eje Central", "Calzada de Tlalpan", "Av. Revolución",
          "Calle Morelos", "Av. Universidad", "Calle Hidalgo", "Av. Río Churubusco", "Calle Allende",
          "Calzada Ermita Iztapalapa", "Av. Chapultepec", "Calle Zaragoza", "Av. Patriotismo", "Calle Juárez"]
LUGARES = ["Bajo el puente", "Parque", "Mercado", "Estación del Metro", "Esquina", "Terreno baldío",
           "Camellón", "Afuera de una escuela", "Estacionamiento", "Barranca"]
CONDICIONES = ["Herido", "Desnutrido", "Deshidratado", "Con sarna", "Atropellado", "Cachorro abandonado",
               "Con parásitos", "Sano", "Con fiebre", "Con fractura"]
DISPONIBILIDAD = ["Fines de semana", "Entre semana por la tarde", "Noches", "Cualquier día", "Solo urgencias"]
ESPECIALIDADES = ["Medicina general", "Cirugía", "Medicina felina", "Dermatología", "Animales exóticos"]
MOTIVOS_DEVOLUCION = ["Alergia de un familiar", "Cambio de domicilio", "Problemas de conducta",
                      "No se adaptó", "Falta de tiempo"]
MOTIVOS_SALIDA = ["Adopción", "Traslado a otro hogar", "Recuperación completa", "Fin del periodo acordado"]
ESTADOS_SEGUIMIENTO = ["Bien adaptado y sano", "Come bien, pero tímido", "Aumentó de peso",
                       "Requiere revisión veterinaria", "Se lleva bien con otras mascotas",
                       "Muy activo y juguetón"]
OBS_SEGUIMIENTO = ["Se recomienda otra visita", "Sin novedades", "El adoptante envió fotos"]
DIAGNOSTICOS = ["Sarna sarcóptica", "Parvovirosis", "Moquillo", "Infección respiratoria", "Desnutrición",
                "Parásitos intestinales", "Herida infectada", "Otitis", "Conjuntivitis"]
CIRUGIAS = ["Extracción de cuerpo extraño", "Reducción de fractura", "Amputación", "Limpieza de herida",
            "Extracción dental"]
OTROS = [("Conejo", "Heno y espacio para saltar"), ("Cobayo", "Vitamina C en la dieta"),
         ("Tortuga", None), ("Paloma", "Revisión de alas"), ("Hámster", None), ("Pato", None)]
PREFIJOS = ["Veterinaria", "Clínica Veterinaria", "Hospital Veterinario", "Centro de Atención Animal"]
SUFIJOS = ["Huellitas", "San Francisco", "Patitas", "Del Valle", "Animalia", "La Roma", "Mascotas Felices",
           "Norte", "Sur", "Pedregal", "Coyoacán", "Polanco", "Condesa", "Satélite", "Zaragoza",
           "Tlalpan", "Narvarte", "Santa Fe", "Lindavista", "Portales", "Aragón", "Iztapalapa",
           "Xochimilco", "Tacuba", "Centro"]
# (nombre, especie_destino, intervalo_refuerzo_dias); None = dosis única
VACUNAS = [("Rabia", "perro", 365), ("Quíntuple canina", "perro", 365), ("Séxtuple canina", "perro", 365),
           ("Bordetella", "perro", 180), ("Leptospirosis", "perro", 365),
           ("Rabia", "gato", 365), ("Triple felina", "gato", 365), ("Leucemia felina", "gato", 365),
           ("Cuádruple felina", "gato", 365),
           ("Mixomatosis", "otro", 180), ("Enfermedad hemorrágica viral del conejo", "otro", 365),
           ("Newcastle (aves)", "otro", None)]


def slug(texto):
    """'Álvarez' -> 'alvarez': minúsculas, sin acentos, solo a-z y 0-9."""
    sin_acentos = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return "".join(c for c in sin_acentos.lower() if c.isalnum())


def formato(valor):
    if valor is None:
        return ""
    if isinstance(valor, bool):
        return "true" if valor else "false"
    if isinstance(valor, datetime):
        return valor.strftime("%Y-%m-%d %H:%M:%S")
    if isinstance(valor, date):
        return valor.isoformat()
    return str(valor)


def escribir(destino, tabla, columnas, filas):
    with open(destino / f"{tabla}.csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f, lineterminator="\n")
        w.writerow(columnas)
        for fila in filas:
            w.writerow([formato(v) for v in fila])
    return len(filas)


def generar(destino=DESTINO_POR_OMISION, corte=CORTE_POR_OMISION):
    """Genera todos los CSV en `destino` y devuelve {tabla: renglones}."""
    rng = random.Random(SEMILLA)
    destino = Path(destino)
    destino.mkdir(parents=True, exist_ok=True)
    desde = corte - timedelta(days=3 * 365)          # ventana de datos: 3 años antes del corte

    def dia(a, b):
        return a + timedelta(days=rng.randint(0, max((b - a).days, 0)))

    # ---- zona
    zonas = []
    for alcaldia, colonias in ALCALDIAS.items():
        for colonia in colonias:
            zonas.append((len(zonas) + 1, colonia, alcaldia, ENTIDAD))
    n_zonas = len(zonas)

    # ---- persona y sus subtipos
    personas = []
    for pid in range(1, N_PERSONAS + 1):
        base = NOMBRES_M if rng.random() < 0.5 else NOMBRES_F
        nombres = rng.choice(base)
        if rng.random() < 0.3:
            nombres += " " + rng.choice(SEGUNDOS)
        ap_p = rng.choice(APELLIDOS)
        ap_m = None if rng.random() < 0.08 else rng.choice(APELLIDOS)
        telefono = rng.choice(["55", "56"]) + f"{rng.randrange(10 ** 8):08d}"
        correo = None if rng.random() < 0.15 else f"{slug(nombres.split()[0])}.{slug(ap_p)}{pid}@example.com"
        personas.append((pid, nombres, ap_p, ap_m, telefono, correo, dia(desde, corte - timedelta(days=10))))

    rescatistas = [(p, rng.random() < 0.45, rng.choice(DISPONIBILIDAD + [None])) for p in RESCATISTAS]
    adoptantes = [(p, rng.choices(["casa", "departamento", "vecindad", "otro"], [35, 50, 10, 5])[0],
                   rng.random() < 0.5, rng.random() < 0.45) for p in ADOPTANTES]
    cedulas = set()
    veterinarios = []
    for p in VETERINARIOS:
        while True:
            cedula = str(rng.randrange(1_000_000, 100_000_000))      # 7 u 8 dígitos
            if cedula not in cedulas:
                cedulas.add(cedula)
                break
        veterinarios.append((p, cedula, rng.choice(ESPECIALIDADES + [None])))

    # ---- hogares temporales y especies que aceptan
    hogares, hogar_especie = [], []
    for hid in range(1, N_HOGARES + 1):
        alias = None if rng.random() < 0.4 else f"Hogar {rng.choice(NOMBRES_F + NOMBRES_M)} {hid}"
        numero = rng.choice(["S/N", str(rng.randint(1, 999)), f"{rng.randint(1, 200)}-{rng.choice('ABC')}"])
        hogares.append((hid, alias, rng.choice(CALLES), numero, f"{rng.randint(1000, 16999):05d}",
                        rng.randint(1, 8), rng.random() < 0.9, rng.randint(1, N_PERSONAS),
                        rng.randint(1, n_zonas)))
        for esp in rng.sample(["perro", "gato", "otro"], rng.choice([1, 1, 2, 3])):
            hogar_especie.append((hid, esp))

    # ---- clínicas y vacunas
    clinicas = []
    for cid in range(1, N_CLINICAS + 1):
        zona = rng.choice(zonas)
        clinicas.append((cid, f"{rng.choice(PREFIJOS)} {SUFIJOS[cid - 1]}",
                         f"{rng.choice(CALLES)} {rng.randint(1, 999)}, Col. {zona[1]}, {zona[2]}",
                         rng.choice(["55", "56"]) + f"{rng.randrange(10 ** 8):08d}",
                         rng.choices(["publica", "privada", "universitaria", "asociacion_civil"],
                                     [2, 6, 1, 3])[0]))
    vacunas = [(i + 1,) + v for i, v in enumerate(VACUNAS)]
    vacunas_de = {e: [v for v in vacunas if v[2] == e] for e in ("perro", "gato", "otro")}

    # ---- rescates y quiénes participaron
    rescates, participantes, rescate_rescatista = [], {}, []
    for rid in range(1, N_RESCATES + 1):
        d = dia(desde, corte - timedelta(days=5))
        fecha_hora = datetime(d.year, d.month, d.day, rng.randint(6, 22), rng.randint(0, 59), rng.randint(0, 59))
        zona = rng.choice(zonas)
        rescates.append({"id": rid, "fecha": fecha_hora, "dia": d, "zona": zona[0],
                         "lugar": f"{rng.choice(LUGARES)}, colonia {zona[1]}",
                         "condicion": rng.choice(CONDICIONES),
                         "ingreso": rng.choices(["rescate_en_calle", "reporte_ciudadano", "entrega_voluntaria"],
                                                [55, 30, 15])[0]})
        participantes[rid] = rng.sample(list(RESCATISTAS), rng.choice([1, 1, 2, 3]))
        rescate_rescatista += [(rid, p) for p in participantes[rid]]

    # ---- animales (todo rescate origina al menos un animal) y su madre
    animales = []
    for aid in range(1, N_ANIMALES + 1):
        rid = aid if aid <= N_RESCATES else rng.randint(1, N_RESCATES)
        r = rescates[rid - 1]
        nac = None if rng.random() < 0.3 else r["dia"] - timedelta(days=rng.randint(60, 4200))
        animales.append({"id": aid, "rid": rid, "rdia": r["dia"], "nac": nac,
                         "especie": rng.choices(["perro", "gato", "otro"], [50, 40, 10])[0],
                         "sexo": rng.choice(["macho", "hembra"]),
                         "nombre": None if rng.random() < 0.35 else rng.choice(NOMBRES_ANIMAL),
                         "color": None if rng.random() < 0.1 else rng.choice(COLORES),
                         "senas": None if rng.random() < 0.5 else rng.choice(SENAS),
                         "madre": None, "abierta": False, "vigente": False, "n_adop": 0,
                         "devuelto": False, "fallecido": False})
    for a in animales:
        if a["id"] > 1 and rng.random() < 0.12:
            candidatas = [m for m in animales[:a["id"] - 1]
                          if m["sexo"] == "hembra" and m["especie"] == a["especie"]
                          and (m["nac"] is None or a["nac"] is None or m["nac"] <= a["nac"] - timedelta(days=365))]
            if candidatas:
                a["madre"] = rng.choice(candidatas)["id"]

    # ---- estancias en hogar temporal (a lo más una abierta por animal)
    estancias = []
    for a in animales:
        a["libre"] = a["rdia"] + timedelta(days=rng.randint(0, 5))     # desde cuándo puede adoptarse
        if rng.random() >= 0.55:
            continue
        inicio = a["libre"]
        n = rng.choice([1, 1, 1, 2])
        for k in range(n):
            if inicio > corte - timedelta(days=20):
                break
            # Elegir únicamente hogares compatibles y con capacidad durante la estancia.
            abierta = k == n - 1 and rng.random() < 0.3
            fin = None if abierta else min(inicio + timedelta(days=rng.randint(10, 150)), corte)
            candidatos = []
            for h in hogares:
                if not h[7] or (h[0], a["especie"]) not in hogar_especie:
                    continue
                coincidentes = [e for e in estancias if e[1] == h[0]
                                and e[3] <= (fin or corte) and (e[4] or corte) >= inicio]
                puntos = [inicio] + [e[3] for e in coincidentes if e[3] >= inicio]
                ocupacion = max(sum(e[3] <= d <= (e[4] or corte) for e in coincidentes) for d in puntos)
                if ocupacion < h[6]:
                    candidatos.append(h[0])
            if not candidatos:
                break
            hogar = rng.choice(candidatos)
            resp = rng.choice(participantes[a["rid"]])
            if abierta:
                estancias.append((a["id"], hogar, resp, inicio, None, None))
                a["abierta"] = True
                break
            estancias.append((a["id"], hogar, resp, inicio, fin, rng.choice(MOTIVOS_SALIDA)))
            a["libre"] = fin
            inicio = fin + timedelta(days=rng.randint(1, 3))

    # ---- adopciones, solicitudes aprobadas y devoluciones
    adopciones, solicitudes, claves_sol = [], [], set()

    def solicitud(a, persona, fecha, estado, obs=None):
        if (a["id"], persona, fecha) not in claves_sol:
            claves_sol.add((a["id"], persona, fecha))
            solicitudes.append((a["id"], persona, fecha, estado, obs))

    for a in animales:
        if a["abierta"] or rng.random() >= 0.72:
            continue
        adoptante = rng.choice(list(ADOPTANTES))
        f_adop = a["libre"] + timedelta(days=rng.randint(10, 150))
        if f_adop > corte:
            continue
        solicitud(a, adoptante, max(a["rdia"] + timedelta(days=1), f_adop - timedelta(days=rng.randint(3, 40))),
                  "aprobada")
        f_dev = motivo = None
        if rng.random() < 0.13:
            f_dev = f_adop + timedelta(days=rng.randint(10, 120))
            if f_dev <= corte:
                motivo = rng.choice(MOTIVOS_DEVOLUCION)
            else:
                f_dev = None
        adopciones.append((a["id"], adoptante, f_adop, f_dev, motivo))
        a["n_adop"] += 1
        if f_dev is None:
            a["vigente"] = True
            continue
        a["devuelto"] = True
        if rng.random() < 0.5:                      # otra persona lo adopta después
            otro = rng.choice([p for p in ADOPTANTES if p != adoptante])
            f2 = f_dev + timedelta(days=rng.randint(10, 90))
            if f2 <= corte:
                solicitud(a, otro, max(f_dev + timedelta(days=1), f2 - timedelta(days=rng.randint(3, 30))),
                          "aprobada")
                adopciones.append((a["id"], otro, f2, None, None))
                a["n_adop"] += 1
                a["vigente"] = True
                a["devuelto"] = False

    # ---- solicitudes que no terminaron en adopción
    for a in animales:
        if a["n_adop"] == 0 and rng.random() < 0.35:
            for _ in range(rng.randint(1, 3)):
                f = a["rdia"] + timedelta(days=rng.randint(2, 200))
                if f <= corte:
                    solicitud(a, rng.choice(list(ADOPTANTES)), f,
                              rng.choices(["pendiente", "rechazada", "cancelada"], [50, 30, 20])[0],
                              rng.choice([None, "Faltó comprobante de domicilio", "Prefirió otro animal"]))

    # ---- seguimiento posadopción
    seguimientos = []
    for (aid, pid, f_adop, f_dev, _) in adopciones:
        if rng.random() < 0.7:
            limite = f_dev if f_dev else corte
            fecha = f_adop
            for num in range(1, rng.choice([1, 2, 3, 4]) + 1):
                fecha = fecha + timedelta(days=rng.randint(15, 45))
                if fecha > limite:
                    break
                seguimientos.append((aid, pid, f_adop, num, fecha,
                                     rng.choice(["visita", "llamada", "mensaje", "videollamada"]),
                                     rng.choice(ESTADOS_SEGUIMIENTO),
                                     None if rng.random() < 0.6 else rng.choice(OBS_SEGUIMIENTO)))

    # ---- estado actual coherente con lo que ocurrió
    for a in animales:
        if a["vigente"]:
            a["estado"] = "adoptado"
        elif a["abierta"]:
            a["estado"] = "en_hogar_temporal"
        elif a["devuelto"]:
            a["estado"] = "disponible_adopcion"
        elif a["n_adop"] == 0 and rng.random() < 0.10:
            a["estado"] = "fallecido"
            a["fallecido"] = True
        else:
            a["estado"] = rng.choices(["rescatado", "en_atencion", "disponible_adopcion"], [20, 30, 50])[0]

    # ---- atenciones médicas y su detalle (vacunación, cirugía o tratamiento)
    atenciones, vacunaciones, cirugias, tratamientos = [], [], [], []
    for a in animales:
        limite = min(corte, a["rdia"] + timedelta(days=60 if a["fallecido"] else 400))
        fechas = sorted(dia(a["rdia"], limite) for _ in range(rng.choice([1, 2, 2, 3, 3, 4, 5, 6])))
        dosis = {}
        for num, fecha in enumerate(fechas, 1):
            tipo = rng.choices(["consulta", "vacunacion", "cirugia", "tratamiento"], [40, 28, 10, 22])[0]
            vet = None if rng.random() < 0.12 else rng.choice(list(VETERINARIOS))
            clin = None if rng.random() < 0.12 else rng.randint(1, N_CLINICAS)
            obs = None if rng.random() < 0.4 else "Evolución favorable"
            atenciones.append((a["id"], num, fecha, tipo, obs, vet, clin))
            if tipo == "vacunacion":
                vac = rng.choice(vacunas_de[a["especie"]])
                dosis[vac[0]] = dosis.get(vac[0], 0) + 1
                proxima = fecha + timedelta(days=vac[3]) if vac[3] else None
                vacunaciones.append((a["id"], num, dosis[vac[0]], proxima, vac[0]))
            elif tipo == "cirugia":
                if not any(c[0] == a["id"] for c in cirugias[-3:]) and rng.random() < 0.5:
                    nombre = "Esterilización" if a["sexo"] == "hembra" else "Castración"
                else:
                    nombre = rng.choice(CIRUGIAS)
                cirugias.append((a["id"], num, nombre,
                                 "Hemorragia leve controlada" if rng.random() < 0.12 else None))
            elif tipo == "tratamiento":
                tratamientos.append((a["id"], num, rng.choice(DIAGNOSTICOS), rng.randint(3, 60)))

    # ---- subtipos de animal
    perros, gatos, otros, animal_filas = [], [], [], []
    for a in animales:
        animal_filas.append((a["id"], a["nombre"], a["especie"], a["sexo"], a["nac"], a["color"], a["senas"],
                             a["estado"], a["rid"], a["madre"]))
        if a["especie"] == "perro":
            perros.append((a["id"], rng.choice(["chico", "mediano", "grande"]),
                           rng.choice(["bajo", "medio", "alto"]), rng.random() < 0.6))
        elif a["especie"] == "gato":
            gatos.append((a["id"], rng.choices([None, False, True], [30, 62, 8])[0],
                          rng.choices([None, False, True], [30, 65, 5])[0]))
        else:
            esp, cuidados = rng.choice(OTROS)
            otros.append((a["id"], esp, cuidados))

    # ---- escritura (en el orden en que se cargan)
    cuentas = {}
    cuentas["zona"] = escribir(destino, "zona", ["id_zona", "colonia", "municipio", "entidad"], zonas)
    cuentas["persona"] = escribir(destino, "persona", ["id_persona", "nombres", "ap_paterno", "ap_materno",
                                                      "telefono", "correo", "fecha_registro"], personas)
    cuentas["rescatista"] = escribir(destino, "rescatista", ["id_persona", "vehiculo_propio", "disponibilidad"],
                                     rescatistas)
    cuentas["adoptante"] = escribir(destino, "adoptante", ["id_persona", "tipo_vivienda", "tiene_patio",
                                                          "otras_mascotas"], adoptantes)
    cuentas["veterinario"] = escribir(destino, "veterinario", ["id_persona", "cedula", "especialidad"], veterinarios)
    cuentas["hogar_temporal"] = escribir(destino, "hogar_temporal", ["id_hogar", "alias", "calle", "numero", "cp",
                                                                    "capacidad_max", "activo", "id_persona",
                                                                    "id_zona"], hogares)
    cuentas["hogar_especie"] = escribir(destino, "hogar_especie", ["id_hogar", "especie"], hogar_especie)
    cuentas["clinica"] = escribir(destino, "clinica", ["id_clinica", "nombre", "direccion", "telefono", "tipo"],
                                  clinicas)
    cuentas["vacuna"] = escribir(destino, "vacuna", ["id_vacuna", "nombre", "especie_destino",
                                                    "intervalo_refuerzo_dias"], vacunas)
    cuentas["rescate"] = escribir(destino, "rescate", ["id_rescate", "descripcion_lugar", "fecha_hora",
                                                      "condicion_inicial", "tipo_ingreso", "id_zona"],
                                  [(r["id"], r["lugar"], r["fecha"], r["condicion"], r["ingreso"], r["zona"])
                                   for r in rescates])
    cuentas["animal"] = escribir(destino, "animal", ["id_animal", "nombre", "especie", "sexo",
                                                    "fecha_nacimiento_aprox", "color", "senas", "estado_actual",
                                                    "id_rescate", "id_madre"], animal_filas)
    cuentas["perro"] = escribir(destino, "perro", ["id_animal", "tamano", "nivel_energia", "apto_con_ninos"], perros)
    cuentas["gato"] = escribir(destino, "gato", ["id_animal", "resultado_fiv", "resultado_felv"], gatos)
    cuentas["otro"] = escribir(destino, "otro", ["id_animal", "descripcion_especie", "cuidados_especiales"], otros)
    cuentas["rescate_rescatista"] = escribir(destino, "rescate_rescatista", ["id_rescate", "id_persona"],
                                             rescate_rescatista)
    cuentas["estancia"] = escribir(destino, "estancia", ["id_animal", "id_hogar", "id_persona", "fecha_inicio",
                                                        "fecha_fin", "motivo_salida"], estancias)
    cuentas["solicitud_adopcion"] = escribir(destino, "solicitud_adopcion",
                                             ["id_animal", "id_persona", "fecha_solicitud", "estado",
                                              "observaciones"], solicitudes)
    cuentas["adopcion"] = escribir(destino, "adopcion", ["id_animal", "id_persona", "fecha_adopcion",
                                                        "fecha_devolucion", "motivo_devolucion"], adopciones)
    cuentas["seguimiento"] = escribir(destino, "seguimiento", ["id_animal", "id_persona", "fecha_adopcion",
                                                              "num_seguimiento", "fecha", "medio",
                                                              "estado_del_animal", "observaciones"], seguimientos)
    cuentas["atencion_medica"] = escribir(destino, "atencion_medica", ["id_animal", "num_atencion", "fecha", "tipo",
                                                                      "observaciones", "id_persona", "id_clinica"],
                                          atenciones)
    cuentas["vacunacion"] = escribir(destino, "vacunacion", ["id_animal", "num_atencion", "dosis_num",
                                                            "fecha_proxima_dosis", "id_vacuna"], vacunaciones)
    cuentas["cirugia"] = escribir(destino, "cirugia", ["id_animal", "num_atencion", "tipo_cirugia",
                                                      "complicaciones"], cirugias)
    cuentas["tratamiento"] = escribir(destino, "tratamiento", ["id_animal", "num_atencion", "diagnostico",
                                                              "duracion_dias"], tratamientos)

    # ---- renglones inválidos a propósito (cada uno viola una restricción distinta)
    p_con_correo = next(p for p in personas if p[5])
    vigente = next(x for x in adopciones if x[3] is None)
    otro_adoptante = next(p for p in ADOPTANTES if p != vigente[1])
    con_seguimiento = seguimientos[0]
    z = zonas[0]
    manana = (corte + timedelta(days=400)).isoformat()
    invalidos = [
        ("persona", "NOT NULL: sin apellido paterno",
         {"id_persona": 90001, "nombres": "María", "ap_paterno": None, "telefono": "5511112222"}),
        ("persona", "Dominio d_telefono: letras en el teléfono",
         {"id_persona": 90002, "nombres": "Carla", "ap_paterno": "Vega", "telefono": "55ABC12345"}),
        ("persona", "CHECK de formato: correo sin arroba",
         {"id_persona": 90003, "nombres": "Luis", "ap_paterno": "Pérez", "telefono": "5587654321",
          "correo": "luis.perez.example.com"}),
        ("persona", "CHECK: correo con mayúsculas",
         {"id_persona": 90004, "nombres": "Ana", "ap_paterno": "Soto", "telefono": "5587654321",
          "correo": "Ana.Soto@Ejemplo.com"}),
        ("persona", "UNIQUE: correo repetido",
         {"id_persona": 90005, "nombres": "Ana María", "ap_paterno": "Soto", "telefono": "5599990000",
          "correo": p_con_correo[5]}),
        ("persona", "CHECK de rango: fecha de registro futura",
         {"id_persona": 90006, "nombres": "Jorge", "ap_paterno": "Díaz", "telefono": "5533334444",
          "fecha_registro": manana}),
        ("veterinario", "CHECK de formato: cédula de 5 dígitos",
         {"id_persona": 356, "cedula": "12345"}),
        ("hogar_temporal", "CHECK de formato: código postal de 4 dígitos",
         {"id_hogar": 90001, "calle": "Calle Durango", "numero": "12", "cp": "6000", "capacidad_max": 3,
          "activo": True, "id_persona": 1, "id_zona": 1}),
        ("rescate", "CHECK de lista: tipo de ingreso inexistente",
         {"id_rescate": 90001, "descripcion_lugar": "Mercado de Sonora", "fecha_hora": "2026-01-10 17:00:00",
          "condicion_inicial": "Desnutrido", "tipo_ingreso": "abandono", "id_zona": 1}),
        ("rescate", "CHECK de rango: rescate en el futuro",
         {"id_rescate": 90002, "descripcion_lugar": "Parque Alameda", "fecha_hora": manana + " 10:00:00",
          "condicion_inicial": "Herido", "tipo_ingreso": "reporte_ciudadano", "id_zona": 1}),
        ("animal", "CHECK de lista: estado inexistente",
         {"id_animal": 90001, "especie": "perro", "sexo": "macho", "estado_actual": "volando", "id_rescate": 1}),
        ("animal", "Enumerado especie_t: especie inexistente",
         {"id_animal": 90002, "especie": "ave", "sexo": "macho", "id_rescate": 1}),
        ("animal", "FOREIGN KEY: rescate que no existe",
         {"id_animal": 90003, "especie": "gato", "sexo": "hembra", "id_rescate": 999999}),
        ("animal", "CHECK: un animal no puede ser su propia madre",
         {"id_animal": 90004, "especie": "gato", "sexo": "hembra", "id_rescate": 1, "id_madre": 90004}),
        ("zona", "UNIQUE compuesta: colonia repetida",
         {"id_zona": 90001, "colonia": z[1], "municipio": z[2], "entidad": z[3]}),
        ("estancia", "CHECK entre columnas: motivo de salida sin fecha de fin",
         {"id_animal": 1, "id_hogar": 1, "id_persona": 1, "fecha_inicio": "2020-01-01", "motivo_salida": "Prueba"}),
        ("adopcion", "UNIQUE parcial: segunda adopción vigente del mismo animal",
         {"id_animal": vigente[0], "id_persona": otro_adoptante, "fecha_adopcion": corte.isoformat()}),
        ("seguimiento", "CHECK entre columnas: seguimiento anterior a la adopción",
         {"id_animal": con_seguimiento[0], "id_persona": con_seguimiento[1],
          "fecha_adopcion": con_seguimiento[2].isoformat(), "num_seguimiento": 99,
          "fecha": (con_seguimiento[2] - timedelta(days=5)).isoformat(), "medio": "llamada",
          "estado_del_animal": "Se adapta bien"}),
        ("solicitud_adopcion", "CHECK de lista: estado inexistente",
         {"id_animal": 1, "id_persona": 71, "fecha_solicitud": "2019-01-01", "estado": "en_proceso"}),
        ("clinica", "Dominio d_telefono: teléfono corto",
         {"id_clinica": 90001, "nombre": "Clínica de prueba", "direccion": "Calle Prueba 1", "telefono": "123",
          "tipo": "privada"}),
        ("vacuna", "CHECK: intervalo de refuerzo en cero",
         {"id_vacuna": 90001, "nombre": "Prueba", "especie_destino": "perro", "intervalo_refuerzo_dias": 0}),
    ]
    with open(destino / "invalidos.json", "w", encoding="utf-8") as f:
        json.dump([{"tabla": t, "caso": c, "fila": fila} for t, c, fila in invalidos], f,
                  ensure_ascii=False, indent=1)
    return cuentas


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--destino", default=str(DESTINO_POR_OMISION), help="carpeta de salida de los CSV")
    ap.add_argument("--corte", default=CORTE_POR_OMISION.isoformat(),
                    help="fecha límite de los datos (AAAA-MM-DD); debe ser anterior a hoy")
    args = ap.parse_args()
    resumen = generar(args.destino, date.fromisoformat(args.corte))
    for tabla, n in resumen.items():
        print(f"{tabla:20s} {n:6d}")
    print(f"{'TOTAL':20s} {sum(resumen.values()):6d}  -> {args.destino}")
