-- ============================================================================
-- EXTENSIONES PARA ENTORNO DISTRIBUIDO
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS dblink;

-- ============================================================================
-- PARTE 1: ESTRUCTURA DE ATENCION MEDICA (PARTICIONAMIENTO POR LISTA)
-- ============================================================================

-- 1. Crear tabla padre AtencionMedica
CREATE TABLE AtencionMedica (
    DNI CHAR(8),
    CodMedico INTEGER NOT NULL,
    Ciudad VARCHAR(50) NOT NULL,
    Diagnostico VARCHAR(50) NOT NULL,
    Peso DECIMAL(5,2) NOT NULL,
    Talla DECIMAL(4,2) NOT NULL,
    PresionArterial VARCHAR(10) NOT NULL,
    Edad INTEGER NOT NULL CHECK (Edad >= 0),
    FechaAtencion DATE NOT NULL
) PARTITION BY LIST (Diagnostico);

-- 2. Crear las 4 particiones iniciales requeridas
CREATE TABLE am_diabetes PARTITION OF AtencionMedica 
    FOR VALUES IN ('Diabetes');

CREATE TABLE am_obesidad PARTITION OF AtencionMedica 
    FOR VALUES IN ('Obesidad');

CREATE TABLE am_cardiopatia PARTITION OF AtencionMedica 
    FOR VALUES IN ('Cardiopatía');

CREATE TABLE am_hipertension PARTITION OF AtencionMedica 
    FOR VALUES IN ('Hipertensión');


-- ============================================================================
-- PARTE 2: ESTRUCTURA DE PACIENTES (PARTICIONAMIENTO POR RANGO)
-- ============================================================================

-- 3. Crear tabla padre Pacientes
CREATE TABLE Pacientes (
    DNI CHAR(8),
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Sexo CHAR(1) NOT NULL CHECK (Sexo IN ('M', 'F')),
    CiudadOrigen VARCHAR(50) NOT NULL,
    PRIMARY KEY (DNI, CiudadOrigen)
) PARTITION BY RANGE (CiudadOrigen);

-- 4. Crear particiones basadas en el vector ["H", "P"]
-- Partición 1: Ciudades que empiezan con letras antes de la 'H' (A-G)
CREATE TABLE pac_A_G PARTITION OF Pacientes
    FOR VALUES FROM (MINVALUE) TO ('H');

-- Partición 2: Ciudades que empiezan con 'H' hasta antes de la 'P' (H-O)
CREATE TABLE pac_H_O PARTITION OF Pacientes
    FOR VALUES FROM ('H') TO ('P');

-- Partición 3: Ciudades que empiezan con 'P' en adelante (P-Z)
CREATE TABLE pac_P_Z PARTITION OF Pacientes
    FOR VALUES FROM ('P') TO (MAXVALUE);