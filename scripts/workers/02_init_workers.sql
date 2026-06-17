-- ============================================================================
-- CONFIGURACIÓN INICIAL DE NODOS WORKERS (pg_worker1 y pg_worker2)
-- ============================================================================

-- 1. Extensiones necesarias para comunicación distribuida
CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS dblink;

-- 2. Crear tabla AtencionMedica en workers (estructura base para recibir fragmentos remotos)
CREATE TABLE IF NOT EXISTS AtencionMedica (
    DNI CHAR(8),
    CodMedico INTEGER NOT NULL,
    Ciudad VARCHAR(50) NOT NULL,
    Diagnostico VARCHAR(50) NOT NULL,
    Peso DECIMAL(5,2) NOT NULL,
    Talla DECIMAL(4,2) NOT NULL,
    PresionArterial VARCHAR(10) NOT NULL,
    Edad INTEGER NOT NULL CHECK (Edad >= 0),
    FechaAtencion DATE NOT NULL
);

-- 3. Crear tabla Pacientes en workers (estructura base para fragmentos remotos)
CREATE TABLE IF NOT EXISTS Pacientes (
    DNI CHAR(8),
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Sexo CHAR(1) NOT NULL CHECK (Sexo IN ('M', 'F')),
    CiudadOrigen VARCHAR(50) NOT NULL,
    PRIMARY KEY (DNI, CiudadOrigen)
);
