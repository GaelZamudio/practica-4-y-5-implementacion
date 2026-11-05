-- Practica 3: Transformacion EER a relacional
-- Zona A: Personas y hogares
-- Responsable: Alejandro
-- Motor: PostgreSQL
-- Tablas (7): zona, persona, rescatista, adoptante, veterinario,
--             hogar_temporal, hogar_especie
-- Orden: 1 de 3; no depende de otras zonas.

CREATE TABLE zona (
    id_zona   INT NOT NULL,
    colonia   VARCHAR(80) NOT NULL,
    municipio VARCHAR(80) NOT NULL,
    entidad   VARCHAR(50) NOT NULL,
    CONSTRAINT pk_zona PRIMARY KEY (id_zona)
);

CREATE TABLE persona (
    id_persona     INT NOT NULL,
    nombres        VARCHAR(60) NOT NULL,
    ap_paterno     VARCHAR(50) NOT NULL,
    ap_materno     VARCHAR(50),
    telefono       VARCHAR(15) NOT NULL,
    correo         VARCHAR(100),
    fecha_registro DATE NOT NULL,
    CONSTRAINT pk_persona PRIMARY KEY (id_persona),
    CONSTRAINT uq_persona_correo UNIQUE (correo)
);

CREATE TABLE rescatista (
    id_persona      INT NOT NULL,
    vehiculo_propio BOOLEAN NOT NULL,
    disponibilidad  VARCHAR(50),
    CONSTRAINT pk_rescatista PRIMARY KEY (id_persona),
    CONSTRAINT fk_rescatista_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE adoptante (
    id_persona     INT NOT NULL,
    tipo_vivienda  VARCHAR(30) NOT NULL,
    tiene_patio    BOOLEAN NOT NULL,
    otras_mascotas BOOLEAN NOT NULL,
    CONSTRAINT pk_adoptante PRIMARY KEY (id_persona),
    CONSTRAINT fk_adoptante_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE veterinario (
    id_persona   INT NOT NULL,
    cedula       VARCHAR(20) NOT NULL,
    especialidad VARCHAR(50),
    CONSTRAINT pk_veterinario PRIMARY KEY (id_persona),
    CONSTRAINT uq_veterinario_cedula UNIQUE (cedula),
    CONSTRAINT fk_veterinario_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE hogar_temporal (
    id_hogar      INT NOT NULL,
    alias         VARCHAR(50),
    calle         VARCHAR(100) NOT NULL,
    numero        VARCHAR(10) NOT NULL,
    cp            CHAR(5) NOT NULL,
    capacidad_max INT NOT NULL,
    activo        BOOLEAN NOT NULL,
    id_persona    INT NOT NULL,
    id_zona       INT NOT NULL,
    CONSTRAINT pk_hogar_temporal PRIMARY KEY (id_hogar),
    CONSTRAINT ck_hogar_capacidad CHECK (capacidad_max > 0),
    CONSTRAINT fk_hogar_persona FOREIGN KEY (id_persona)
        REFERENCES persona (id_persona) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_hogar_zona FOREIGN KEY (id_zona)
        REFERENCES zona (id_zona) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE hogar_especie (
    id_hogar INT NOT NULL,
    especie  VARCHAR(30) NOT NULL,
    CONSTRAINT pk_hogar_especie PRIMARY KEY (id_hogar, especie),
    CONSTRAINT fk_hogar_especie_hogar FOREIGN KEY (id_hogar)
        REFERENCES hogar_temporal (id_hogar) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Practica 3: Transformacion EER a relacional
-- Zona B: Rescate, animal y adopcion
-- Responsable: Gael
-- Motor: PostgreSQL
-- Tablas (10): rescate, rescate_rescatista, animal, perro, gato, otro,
--              estancia, solicitud_adopcion, adopcion, seguimiento
-- Orden: 2 de 3. Requiere las tablas zona, rescatista, adoptante y
-- hogar_temporal de la zona A. La zona C depende de animal.
-- Los identificadores INT se proporcionan al insertar; no se generan
-- automaticamente, de acuerdo con el inventario comun.

CREATE TABLE rescate (
    id_rescate       INT NOT NULL,
    descripcion_lugar VARCHAR(200) NOT NULL,
    fecha_hora       TIMESTAMP NOT NULL,
    condicion_inicial VARCHAR(200) NOT NULL,
    tipo_ingreso     VARCHAR(30) NOT NULL,
    id_zona          INT NOT NULL,
    CONSTRAINT pk_rescate PRIMARY KEY (id_rescate),
    CONSTRAINT fk_rescate_zona FOREIGN KEY (id_zona)
        REFERENCES zona (id_zona) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE animal (
    id_animal             INT NOT NULL,
    nombre                VARCHAR(50),
    especie               VARCHAR(30) NOT NULL,
    sexo                  VARCHAR(10) NOT NULL,
    fecha_nacimiento_aprox DATE,
    color                 VARCHAR(50),
    senas                 VARCHAR(200),
    estado_actual         VARCHAR(30) NOT NULL,
    id_rescate            INT NOT NULL,
    id_madre              INT,
    CONSTRAINT pk_animal PRIMARY KEY (id_animal),
    CONSTRAINT ck_animal_especie CHECK (especie IN ('perro', 'gato', 'otro')),
    CONSTRAINT ck_animal_sexo CHECK (sexo IN ('macho', 'hembra')),
    CONSTRAINT ck_animal_no_es_su_madre CHECK (id_madre IS NULL OR id_madre <> id_animal),
    CONSTRAINT fk_animal_rescate FOREIGN KEY (id_rescate)
        REFERENCES rescate (id_rescate) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_animal_madre FOREIGN KEY (id_madre)
        REFERENCES animal (id_animal) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE perro (
    id_animal      INT NOT NULL,
    tamano         VARCHAR(20) NOT NULL,
    nivel_energia  VARCHAR(20) NOT NULL,
    apto_con_ninos BOOLEAN NOT NULL,
    CONSTRAINT pk_perro PRIMARY KEY (id_animal),
    CONSTRAINT fk_perro_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE gato (
    id_animal     INT NOT NULL,
    resultado_fiv BOOLEAN,
    resultado_felv BOOLEAN,
    CONSTRAINT pk_gato PRIMARY KEY (id_animal),
    CONSTRAINT fk_gato_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE otro (
    id_animal           INT NOT NULL,
    descripcion_especie VARCHAR(100) NOT NULL,
    cuidados_especiales VARCHAR(200),
    CONSTRAINT pk_otro PRIMARY KEY (id_animal),
    CONSTRAINT fk_otro_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE rescate_rescatista (
    id_rescate INT NOT NULL,
    id_persona INT NOT NULL,
    CONSTRAINT pk_rescate_rescatista PRIMARY KEY (id_rescate, id_persona),
    CONSTRAINT fk_rescate_rescatista_rescate FOREIGN KEY (id_rescate)
        REFERENCES rescate (id_rescate) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_rescate_rescatista_rescatista FOREIGN KEY (id_persona)
        REFERENCES rescatista (id_persona) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE estancia (
    id_animal   INT NOT NULL,
    id_hogar    INT NOT NULL,
    id_persona  INT NOT NULL,
    fecha_inicio DATE NOT NULL,
    fecha_fin   DATE,
    motivo_salida VARCHAR(100),
    CONSTRAINT pk_estancia PRIMARY KEY (id_animal, id_hogar, id_persona, fecha_inicio),
    CONSTRAINT ck_estancia_fechas CHECK (fecha_fin IS NULL OR fecha_fin >= fecha_inicio),
    CONSTRAINT fk_estancia_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_estancia_hogar FOREIGN KEY (id_hogar)
        REFERENCES hogar_temporal (id_hogar) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_estancia_rescatista FOREIGN KEY (id_persona)
        REFERENCES rescatista (id_persona) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE solicitud_adopcion (
    id_animal        INT NOT NULL,
    id_persona       INT NOT NULL,
    fecha_solicitud  DATE NOT NULL,
    estado           VARCHAR(20) NOT NULL,
    observaciones    VARCHAR(200),
    CONSTRAINT pk_solicitud_adopcion PRIMARY KEY (id_animal, id_persona, fecha_solicitud),
    CONSTRAINT fk_solicitud_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_solicitud_adoptante FOREIGN KEY (id_persona)
        REFERENCES adoptante (id_persona) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE adopcion (
    id_animal       INT NOT NULL,
    id_persona      INT NOT NULL,
    fecha_adopcion  DATE NOT NULL,
    fecha_devolucion DATE,
    motivo_devolucion VARCHAR(200),
    CONSTRAINT pk_adopcion PRIMARY KEY (id_animal, id_persona, fecha_adopcion),
    CONSTRAINT ck_adopcion_fechas CHECK (fecha_devolucion IS NULL OR fecha_devolucion >= fecha_adopcion),
    CONSTRAINT fk_adopcion_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_adopcion_adoptante FOREIGN KEY (id_persona)
        REFERENCES adoptante (id_persona) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE seguimiento (
    id_animal         INT NOT NULL,
    id_persona        INT NOT NULL,
    fecha_adopcion    DATE NOT NULL,
    num_seguimiento   INT NOT NULL,
    fecha             DATE NOT NULL,
    medio             VARCHAR(30) NOT NULL,
    estado_del_animal VARCHAR(200) NOT NULL,
    observaciones     VARCHAR(200),
    CONSTRAINT pk_seguimiento PRIMARY KEY
        (id_animal, id_persona, fecha_adopcion, num_seguimiento),
    CONSTRAINT ck_seguimiento_numero CHECK (num_seguimiento > 0),
    CONSTRAINT fk_seguimiento_adopcion FOREIGN KEY
        (id_animal, id_persona, fecha_adopcion)
        REFERENCES adopcion (id_animal, id_persona, fecha_adopcion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- Practica 3: Transformacion EER a relacional
-- Zona C: Atencion medica
-- Responsable: Jose
-- Motor: PostgreSQL
-- Tablas (6): clinica, vacuna, atencion_medica, vacunacion, cirugia,
--             tratamiento
-- Orden: 3 de 3. Requiere animal (zona B) y veterinario (zona A).
-- No se crean tablas sustitutas de animal, persona ni veterinario.

CREATE TABLE clinica (
    id_clinica INT NOT NULL,
    nombre     VARCHAR(100) NOT NULL,
    direccion  VARCHAR(200) NOT NULL,
    telefono   VARCHAR(15) NOT NULL,
    tipo       VARCHAR(30) NOT NULL,
    CONSTRAINT pk_clinica PRIMARY KEY (id_clinica)
);

CREATE TABLE vacuna (
    id_vacuna              INT NOT NULL,
    nombre                 VARCHAR(80) NOT NULL,
    especie_destino        VARCHAR(30) NOT NULL,
    intervalo_refuerzo_dias INT,
    CONSTRAINT pk_vacuna PRIMARY KEY (id_vacuna),
    CONSTRAINT ck_vacuna_intervalo CHECK
        (intervalo_refuerzo_dias IS NULL OR intervalo_refuerzo_dias > 0)
);

CREATE TABLE atencion_medica (
    id_animal     INT NOT NULL,
    num_atencion  INT NOT NULL,
    fecha         DATE NOT NULL,
    tipo          VARCHAR(30) NOT NULL,
    observaciones VARCHAR(300),
    id_persona    INT,
    id_clinica    INT,
    CONSTRAINT pk_atencion_medica PRIMARY KEY (id_animal, num_atencion),
    CONSTRAINT ck_atencion_numero CHECK (num_atencion > 0),
    CONSTRAINT fk_atencion_animal FOREIGN KEY (id_animal)
        REFERENCES animal (id_animal) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_atencion_veterinario FOREIGN KEY (id_persona)
        REFERENCES veterinario (id_persona) ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT fk_atencion_clinica FOREIGN KEY (id_clinica)
        REFERENCES clinica (id_clinica) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE vacunacion (
    id_animal          INT NOT NULL,
    num_atencion       INT NOT NULL,
    dosis_num          INT NOT NULL,
    fecha_proxima_dosis DATE,
    id_vacuna          INT NOT NULL,
    CONSTRAINT pk_vacunacion PRIMARY KEY (id_animal, num_atencion),
    CONSTRAINT ck_vacunacion_dosis CHECK (dosis_num > 0),
    CONSTRAINT fk_vacunacion_atencion FOREIGN KEY (id_animal, num_atencion)
        REFERENCES atencion_medica (id_animal, num_atencion)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_vacunacion_vacuna FOREIGN KEY (id_vacuna)
        REFERENCES vacuna (id_vacuna) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE cirugia (
    id_animal      INT NOT NULL,
    num_atencion   INT NOT NULL,
    tipo_cirugia   VARCHAR(50) NOT NULL,
    complicaciones VARCHAR(200),
    CONSTRAINT pk_cirugia PRIMARY KEY (id_animal, num_atencion),
    CONSTRAINT fk_cirugia_atencion FOREIGN KEY (id_animal, num_atencion)
        REFERENCES atencion_medica (id_animal, num_atencion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE tratamiento (
    id_animal     INT NOT NULL,
    num_atencion  INT NOT NULL,
    diagnostico   VARCHAR(200) NOT NULL,
    duracion_dias INT NOT NULL,
    CONSTRAINT pk_tratamiento PRIMARY KEY (id_animal, num_atencion),
    CONSTRAINT ck_tratamiento_duracion CHECK (duracion_dias > 0),
    CONSTRAINT fk_tratamiento_atencion FOREIGN KEY (id_animal, num_atencion)
        REFERENCES atencion_medica (id_animal, num_atencion)
        ON DELETE CASCADE ON UPDATE CASCADE
);

