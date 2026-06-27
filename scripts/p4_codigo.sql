DROP TABLE IF EXISTS Pacientes, AtencionMedica CASCADE;

CREATE TABLE Pacientes (
    DNI CHAR(8) PRIMARY KEY,
    Nombre VARCHAR(50) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    FechaNacimiento DATE NOT NULL,
    Sexo CHAR(1) NOT NULL CHECK (Sexo IN ('M','F')),
    CiudadOrigen VARCHAR(50) NOT NULL
);

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
);

INSERT INTO Pacientes
SELECT
    LPAD((10000000+g)::text,8,'0'),
    'Nombre'||g,
    'Apellido'||g,
    DATE '1950-01-01' + (g*7 % 25000),
    (ARRAY['M','F'])[1+(g%2)],
    (ARRAY['Arequipa','Barranca','Cusco','Chiclayo','Ferrenafe',   -- A..F  (sitio1)
           'Huancayo','Huaraz','Ica','Juliaca','Moquegua',          -- H..M  (sitio2)
           'Piura','Puno','Tacna','Tarma','Trujillo'])[1+(g%15)]    -- P..T  (sitio3)
FROM generate_series(1,50000) g;

INSERT INTO AtencionMedica
SELECT
    LPAD((10000000 + 1 + (g % 50000))::text,8,'0'),  -- DNI de un paciente real
    100+(g%50),
    (ARRAY['Lima','Callao','Arequipa','Cusco','Tarma'])[1+(g%5)],
    (ARRAY['Diabetes','Hipertensión','Obesidad','Cardiopatía'])[1+(g%4)],
    ROUND((50+random()*60)::numeric,2),
    ROUND((1.5+random()*0.4)::numeric,2),
    '120/80',
    18+(g%70),
    DATE '2025-01-01' + (g%365)
FROM generate_series(1,60000) g;

CREATE TABLE pacientes_s1 AS SELECT * FROM Pacientes WHERE CiudadOrigen <  'H';
CREATE TABLE pacientes_s2 AS SELECT * FROM Pacientes WHERE CiudadOrigen >= 'H' AND CiudadOrigen < 'P';
CREATE TABLE pacientes_s3 AS SELECT * FROM Pacientes WHERE CiudadOrigen >= 'P';

CREATE TABLE am_diabetes     AS SELECT * FROM AtencionMedica WHERE Diagnostico='Diabetes';
CREATE TABLE am_hipertension AS SELECT * FROM AtencionMedica WHERE Diagnostico='Hipertensión';
CREATE TABLE am_obesidad     AS SELECT * FROM AtencionMedica WHERE Diagnostico='Obesidad';
CREATE TABLE am_cardiopatia  AS SELECT * FROM AtencionMedica WHERE Diagnostico='Cardiopatía';

CREATE INDEX ON pacientes_s1(DNI); CREATE INDEX ON pacientes_s2(DNI); CREATE INDEX ON pacientes_s3(DNI);
CREATE INDEX ON am_diabetes(DNI); CREATE INDEX ON am_hipertension(DNI);
CREATE INDEX ON am_obesidad(DNI); CREATE INDEX ON am_cardiopatia(DNI);
ANALYZE;

SELECT 'pacientes_s1' frag, COUNT(*) FROM pacientes_s1
UNION ALL SELECT 'pacientes_s2', COUNT(*) FROM pacientes_s2
UNION ALL SELECT 'pacientes_s3', COUNT(*) FROM pacientes_s3
UNION ALL SELECT 'am_diabetes', COUNT(*) FROM am_diabetes
UNION ALL SELECT 'am_hipertension', COUNT(*) FROM am_hipertension
UNION ALL SELECT 'am_obesidad', COUNT(*) FROM am_obesidad
UNION ALL SELECT 'am_cardiopatia', COUNT(*) FROM am_cardiopatia;


-- Q1: SELECT * FROM Pacientes ORDER BY FechaNacimiento

CREATE TEMP TABLE tmp_q1 AS
    SELECT * FROM pacientes_s1
    UNION ALL SELECT * FROM pacientes_s2
    UNION ALL SELECT * FROM pacientes_s3;

SELECT * FROM tmp_q1 ORDER BY FechaNacimiento;

DROP TABLE tmp_q1;


-- Q2: SELECT DISTINCT CiudadOrigen FROM Pacientes

CREATE TEMP TABLE tmp_q2 AS
    SELECT DISTINCT CiudadOrigen FROM pacientes_s1
    UNION ALL SELECT DISTINCT CiudadOrigen FROM pacientes_s2
    UNION ALL SELECT DISTINCT CiudadOrigen FROM pacientes_s3;

SELECT * FROM tmp_q2 ORDER BY CiudadOrigen;

DROP TABLE tmp_q2;

-- Q3: SELECT Diagnostico, AVG(Edad) FROM AtencionMedica GROUP BY Diagnostico

CREATE TEMP TABLE tmp_q3 AS
    SELECT Diagnostico, SUM(Edad) AS s, COUNT(*) AS c FROM am_diabetes     GROUP BY Diagnostico
    UNION ALL SELECT Diagnostico, SUM(Edad), COUNT(*) FROM am_hipertension GROUP BY Diagnostico
    UNION ALL SELECT Diagnostico, SUM(Edad), COUNT(*) FROM am_obesidad     GROUP BY Diagnostico
    UNION ALL SELECT Diagnostico, SUM(Edad), COUNT(*) FROM am_cardiopatia  GROUP BY Diagnostico;

SELECT Diagnostico, ROUND(SUM(s)::numeric / SUM(c), 4) AS PromEdad
FROM tmp_q3
GROUP BY Diagnostico
ORDER BY Diagnostico;

DROP TABLE tmp_q3;


CREATE TEMP TABLE tmp_join AS
    SELECT * FROM pacientes_s1 NATURAL JOIN am_diabetes
    UNION ALL SELECT * FROM pacientes_s1 NATURAL JOIN am_hipertension
    UNION ALL SELECT * FROM pacientes_s1 NATURAL JOIN am_obesidad
    UNION ALL SELECT * FROM pacientes_s1 NATURAL JOIN am_cardiopatia
    UNION ALL SELECT * FROM pacientes_s2 NATURAL JOIN am_diabetes
    UNION ALL SELECT * FROM pacientes_s2 NATURAL JOIN am_hipertension
    UNION ALL SELECT * FROM pacientes_s2 NATURAL JOIN am_obesidad
    UNION ALL SELECT * FROM pacientes_s2 NATURAL JOIN am_cardiopatia
    UNION ALL SELECT * FROM pacientes_s3 NATURAL JOIN am_diabetes
    UNION ALL SELECT * FROM pacientes_s3 NATURAL JOIN am_hipertension
    UNION ALL SELECT * FROM pacientes_s3 NATURAL JOIN am_obesidad
    UNION ALL SELECT * FROM pacientes_s3 NATURAL JOIN am_cardiopatia;

SELECT * FROM tmp_join ORDER BY DNI LIMIT 10;

DROP TABLE tmp_join;