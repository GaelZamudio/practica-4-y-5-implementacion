# Ejercicio 1.3. La fuente de datos del proyecto propio

**Proyecto:** Sistema de Rescate, Cuidado y Adopción de Animales en situación de calle (Ciudad de México)
**Fecha de consulta de todas las fuentes:** 5 de noviembre de 2026
**Decisión:** no existe un conjunto publicado que sirva para el dominio; **los datos de las 23 tablas se generan con un script** y son **sintéticos**.

Como no se carga ningún conjunto real, no aplican los puntos 1 a 4 del enunciado (referencia del conjunto cargado, formato, tabla de correspondencia y problemas de limpieza). En su lugar, este documento incluye lo que el enunciado pide para los datos generados: dónde se buscó, con qué términos y por qué se concluye que no hay datos. También documenta los conjuntos relacionados que se evaluaron y se descartaron.

---

## 1. Dónde se buscó y con qué términos

| Lugar | Términos de búsqueda | Qué se encontró |
|---|---|---|
| Portal de Datos Abiertos de la CDMX (datos.cdmx.gob.mx) | "animales", "maltrato animal", "rescate animal", "esterilización", "Agencia de Atención Animal", "Brigada de Vigilancia Animal" | No hay conjuntos con registros individuales de animales rescatados, adoptados o atendidos. |
| Portal de datos abiertos federal (datos.gob.mx) | "centro de control animal", "adopción de mascotas", "vacunación antirrábica" | Solo informes y cifras agregadas, sin registros por animal. |
| INEGI | "mascotas", "animales de compañía", "servicios veterinarios" | Solo el DENUE (directorio de negocios) y encuestas con preguntas sobre mascotas en el hogar; nada sobre rescates ni adopciones. |
| Agencia de Atención Animal (Agatan), PAOT y SSC | "esterilizaciones", "rescates", "denuncias" | Boletines con totales anuales (número de esterilizaciones, vacunas o denuncias), no bases de datos. |
| Prensa y resoluciones de transparencia publicadas (InfoCDMX) | "maltrato animal CDMX denuncias", "animales rescatados CDMX" | Totales por alcaldía o por año; ningún registro individual descargable. |
| Catálogo de datos abiertos de EE. UU. (catalog.data.gov) | "animal shelter intakes", "animal center outcomes", "stray" | Conjuntos de refugios municipales de otras ciudades (ver sección 3). |

## 2. Por qué se concluye que no hay datos publicados

1. **Las autoridades de la CDMX solo publican cifras agregadas.** Ninguna dependencia ofrece un registro por animal con su rescate, su estancia y su adopción.
2. **Las personas** (rescatistas, adoptantes, veterinarios y responsables de hogares temporales) son datos personales protegidos por la Ley General de Protección de Datos Personales en Posesión de Sujetos Obligados. No se publican, ni deben publicarse.
3. **El historial clínico** (atenciones, vacunaciones, cirugías y tratamientos) lo guardan clínicas y asociaciones privadas; no existe un conjunto abierto.
4. **Las estancias en hogar temporal y el seguimiento posadopción** son procesos internos de cada asociación protectora.

---

## 3. Conjuntos relacionados evaluados y descartados

### 3.1 Austin Animal Center (refugio municipal de Austin, Texas)

City of Austin. (2025). *Austin Animal Center Intakes (10/01/2013 to 05/05/2025)* [Conjunto de datos]. Data.AustinTexas.gov. Recuperado el 5 de noviembre de 2026, de https://data.austintexas.gov/d/wter-evkm

City of Austin. (2025). *Austin Animal Center Outcomes (10/01/2013 to 05/05/2025)* [Conjunto de datos]. Data.AustinTexas.gov. Recuperado el 5 de noviembre de 2026, de https://data.austintexas.gov/d/9t4d-g238

**Licencia:** sin licencia explícita. La ficha del conjunto en data.gov no proporciona información de licencia.

**Qué trae:** un renglón por cada ingreso y por cada egreso del refugio, con 12 campos cada uno: identificador del animal, nombre, fecha, tipo de ingreso o egreso, especie, sexo, edad, raza y color.

**Por qué se descarta:**

1. **No es nuestro caso.** Los rescates son de Austin, así que todos colgarían de una zona artificial "EXT". Nuestro esquema gira alrededor de la colonia, el municipio y los hogares temporales de la CDMX, y esa es la mitad del dominio.
2. **La mitad del esquema seguiría siendo sintética.** Los datos reales solo cubrirían `animal`, `rescate` y `adopcion`. Las personas, los hogares temporales, las estancias, el seguimiento y toda la parte médica habría que generarlos igual, y además asignarlos a animales reales de otro país.

### 3.2 DENUE del INEGI (servicios veterinarios en la CDMX)

Instituto Nacional de Estadística y Geografía. (2026). *Directorio Estadístico Nacional de Unidades Económicas (DENUE)* (Versión 05/2026) [Conjunto de datos]. Recuperado el 5 de noviembre de 2026, de https://www.inegi.org.mx/app/mapa/denue/default.aspx

**Licencia:** Términos de Libre Uso de la Información del INEGI (https://www.inegi.org.mx/inegi/terminos.html). Permiten copiar, distribuir y adaptar la información citando al INEGI como fuente.

**Qué trae:** cada establecimiento económico del país; con la actividad SCIAN 541941 (servicios veterinarios para mascotas) se obtienen las veterinarias de la CDMX con nombre, dirección y teléfono.

**Por qué se descarta:**

1. **Solo alimentaría una tabla.** Serviría para `clinica`, pero todas las atenciones médicas, vacunaciones, cirugías y tratamientos que cuelgan de ella serían sintéticas.
2. **Atribuiría atenciones inventadas a negocios reales.** Mezclar nombres y teléfonos de veterinarias existentes con historiales clínicos ficticios daría información falsa sobre establecimientos reales. Es más honesto que la clínica también sea sintética.

---

## 4. Datos generados

### Tablas sintéticas (las 23 del esquema)

| Zona del modelo | Tablas |
|---|---|
| A. Personas y hogares | `zona`, `persona`, `rescatista`, `adoptante`, `veterinario`, `hogar_temporal`, `hogar_especie` |
| B. Rescate, animal y adopción | `rescate`, `rescate_rescatista`, `animal`, `perro`, `gato`, `otro`, `estancia`, `adopcion`, `solicitud_adopcion`, `seguimiento` |
| C. Atención médica | `clinica`, `atencion_medica`, `vacunacion`, `cirugia`, `tratamiento`, `vacuna`|



### Reglas que cumple el generador

- **Usa los nombres y valores del esquema.** Por ejemplo, `animal.sexo` toma `macho` o `hembra`; el tipo de rescate toma `rescate_en_calle`, `reporte_ciudadano` o `entrega_voluntaria`; `rescate` usa `fecha_hora`, `descripcion_lugar` y `condicion_inicial`; el rescatista de cada rescate se registra en `rescate_rescatista`.
- **Los identificadores los asigna la carga**, no el generador.
- **`zona` usa colonias y municipios reales de la CDMX** con su entidad, para que las consultas por alcaldía tengan sentido. Los nombres de colonia son públicos y no identifican a nadie.
- **`clinica` es ficticia**: nombre, dirección, teléfono y tipo inventados, por la razón de la sección 3.2.
- **Respeta todas las restricciones** del esquema y de las migraciones: NOT NULL, UNIQUE, CHECK de rango, de formato y de lista de valores. Las fechas son coherentes entre tablas: una estancia o una adopción nunca es anterior a su rescate, y un seguimiento nunca es anterior a su adopción.
- **Al menos 200 renglones** en cada tabla principal (`persona`, `animal`, `rescate`, `adopcion`, `atencion_medica`), con variedad suficiente de colonias, especies, edades, condiciones y tipos de rescate para que las consultas de las Prácticas 9 a 12 devuelvan algo interesante.
- **Sin datos personales reales**: nombres, teléfonos y correos son ficticios.
- **Semilla fija**: genera siempre los mismos datos, para que la carga del ejercicio 1.4 sea repetible.
