DROP DATABASE IF EXISTS lab13_p5;
CREATE DATABASE lab13_p5;
\c lab13_p5

CREATE EXTENSION IF NOT EXISTS postgres_fdw;
CREATE EXTENSION IF NOT EXISTS dblink;

CREATE SERVER worker1 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'worker1', port '5432', dbname 'lab13_p5');
CREATE SERVER worker2 FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'worker2', port '5432', dbname 'lab13_p5');
CREATE USER MAPPING FOR postgres SERVER worker1 OPTIONS (user 'postgres', password 'postgres');
CREATE USER MAPPING FOR postgres SERVER worker2 OPTIONS (user 'postgres', password 'postgres');

CREATE TABLE AtencionMedica (
    DNI CHAR(8), CodMedico INT NOT NULL, Ciudad VARCHAR(50) NOT NULL,
    Diagnostico VARCHAR(50) NOT NULL, Peso DECIMAL(5,2) NOT NULL, Talla DECIMAL(4,2) NOT NULL,
    PresionArterial VARCHAR(10) NOT NULL, Edad INT NOT NULL CHECK(Edad>=0), FechaAtencion DATE NOT NULL
) PARTITION BY LIST (Diagnostico);

CREATE TABLE am_diabetes     PARTITION OF AtencionMedica FOR VALUES IN ('Diabetes');
CREATE TABLE am_hipertension PARTITION OF AtencionMedica FOR VALUES IN ('Hipertensión');
CREATE FOREIGN TABLE am_obesidad PARTITION OF AtencionMedica FOR VALUES IN ('Obesidad')
    SERVER worker1 OPTIONS (schema_name 'public', table_name 'am_obesidad');
CREATE FOREIGN TABLE am_cardiopatia PARTITION OF AtencionMedica FOR VALUES IN ('Cardiopatía')
    SERVER worker2 OPTIONS (schema_name 'public', table_name 'am_cardiopatia');


CREATE TABLE Pacientes (
    DNI CHAR(8) NOT NULL, Nombre VARCHAR(50) NOT NULL, Apellidos VARCHAR(100) NOT NULL,
    FechaNacimiento DATE NOT NULL, Sexo CHAR(1) NOT NULL CHECK(Sexo IN ('M','F')),
    CiudadOrigen VARCHAR(50) NOT NULL
) PARTITION BY RANGE (CiudadOrigen);

CREATE FOREIGN TABLE pacientes_ag PARTITION OF Pacientes FOR VALUES FROM (MINVALUE) TO ('H')
    SERVER worker1 OPTIONS (schema_name 'public', table_name 'pacientes_ag');
CREATE FOREIGN TABLE pacientes_ho PARTITION OF Pacientes FOR VALUES FROM ('H') TO ('P')
    SERVER worker2 OPTIONS (schema_name 'public', table_name 'pacientes_ho');
CREATE TABLE pacientes_pz PARTITION OF Pacientes FOR VALUES FROM ('P') TO (MAXVALUE);


INSERT INTO Pacientes
SELECT LPAD((10000000+g)::text,8,'0'), 'Nombre'||g, 'Apellido'||g,
       DATE '1950-01-01' + (g*7 % 25000), (ARRAY['M','F'])[1+(g%2)],
       (ARRAY['Arequipa','Barranca','Cusco','Chiclayo','Ferrenafe',
              'Huancayo','Huaraz','Ica','Juliaca','Moquegua',
              'Piura','Puno','Tacna','Tarma','Trujillo'])[1+(g%15)]
FROM generate_series(1,50000) g;

INSERT INTO AtencionMedica
SELECT LPAD((10000000 + 1 + (g % 50000))::text,8,'0'), 100+(g%50),
       (ARRAY['Lima','Callao','Arequipa','Cusco','Tarma'])[1+(g%5)],
       (ARRAY['Diabetes','Hipertensión','Obesidad','Cardiopatía'])[1+(g%4)],
       ROUND((50+random()*60)::numeric,2), ROUND((1.5+random()*0.4)::numeric,2),
       '120/80', 18+(g%70), DATE '2025-01-01' + (g%365)
FROM generate_series(1,60000) g;

ANALYZE Pacientes; ANALYZE AtencionMedica;

SELECT 'Pacientes' tabla, tableoid::regclass fragmento, COUNT(*) filas FROM Pacientes GROUP BY 2
UNION ALL
SELECT 'AtencionMedica', tableoid::regclass, COUNT(*) FROM AtencionMedica GROUP BY 2
ORDER BY 1,2;