CREATE OR REPLACE PROCEDURE sp_insertar_atencion_distribuido(
    p_dni CHAR(8),
    p_codmedico INTEGER,
    p_ciudad VARCHAR(50),
    p_diagnostico VARCHAR(50),
    p_peso DECIMAL(5,2),
    p_talla DECIMAL(4,2),
    p_presion VARCHAR(10),
    p_edad INTEGER,
    p_fecha DATE,
    p_servidor_destino TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_clean_diag TEXT;
    v_part_name  TEXT;
    v_conn_str   TEXT;
    v_remote_sql TEXT;
BEGIN
    p_servidor_destino := lower(trim(p_servidor_destino));

    -- CASO 1: Destino Local
    IF p_servidor_destino = 'local' THEN
        CALL sp_insertar_atencion(p_dni, p_codmedico, p_ciudad, p_diagnostico, p_peso, p_talla, p_presion, p_edad, p_fecha);
        RETURN;
    END IF;

    -- Generar identificador de tabla
    v_clean_diag := translate(lower(p_diagnostico), 'áéíóúñ', 'aeioun');
    v_part_name  := 'am_' || trim(both '_' from regexp_replace(v_clean_diag, '[^a-z0-9]+', '_', 'g'));

    -- Resolver cadena de conexión
    CASE p_servidor_destino
        WHEN 'worker1' THEN
            v_conn_str := 'host=pg_worker1 dbname=minsa_worker1 user=abel password=incentivos';
        WHEN 'worker2' THEN
            v_conn_str := 'host=pg_worker2 dbname=minsa_worker2 user=abel password=incentivos';
        ELSE
            RAISE EXCEPTION 'Destino "%" desconocido. Valores válidos: local, worker1, worker2', p_servidor_destino;
    END CASE;

    -- PASO A: Ejecutar bloque anónimo remoto vía dblink
    v_remote_sql := format(
        'DO $do$
         BEGIN
             IF NOT EXISTS (
                 SELECT 1 FROM pg_class WHERE relname = %L
             ) THEN
                 CREATE TABLE %I (
                     CHECK (Diagnostico = %L)
                 ) INHERITS (AtencionMedica);
             END IF;
         END $do$;',
        v_part_name, v_part_name, p_diagnostico
    );

    PERFORM dblink_exec(v_conn_str, v_remote_sql);

    -- PASO B: Inserción remota segura
    v_remote_sql := format(
        'INSERT INTO %I (DNI, CodMedico, Ciudad, Diagnostico, Peso, Talla, PresionArterial, Edad, FechaAtencion) ' ||
        'VALUES (%L, %s, %L, %L, %s, %s, %L, %s, %L);',
        v_part_name,p_dni, p_codmedico, p_ciudad, p_diagnostico, p_peso, p_talla, p_presion, p_edad, p_fecha
    );

    PERFORM dblink_exec(v_conn_str, v_remote_sql);

    RAISE NOTICE '[MINSA DISTBUITED] Registro enviado a nodo "%" en partición "%"', p_servidor_destino, v_part_name;

EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'Fallo de coordinación distribuida hacia %: %', p_servidor_destino, SQLERRM;
END;
$$;


CALL sp_insertar_atencion_distribuido('44556677', 301, 'Trujillo', 'Asma', 60.0, 1.65, '120/80', 22, '2026-06-10', 'worker1');

SELECT * FROM dblink(
    'host=pg_worker1 dbname=minsa_worker1 user=abel password=incentivos',
    'SELECT DNI, Diagnostico, Ciudad, Edad FROM am_asma'
) AS rem(DNI CHAR(8), Diagnostico VARCHAR(50), Ciudad VARCHAR(50), Edad INTEGER);



CALL sp_insertar_atencion_distribuido('55667788', 302, 'Puno', 'Gastritis', 68.5, 1.70, '110/70', 50, '2026-06-11', 'worker2');

SELECT * FROM dblink(
    'host=pg_worker2 dbname=minsa_worker2 user=abel password=incentivos',
    'SELECT DNI, Diagnostico, Ciudad, Edad FROM am_gastritis'
) AS rem(DNI CHAR(8), Diagnostico VARCHAR(50), Ciudad VARCHAR(50), Edad INTEGER);




-- 2 CONSULTAS DE EVIDENCIA CON EXPLAIN ANALYZE 

-- CONSULTA DISTRIBUIDA 1:
-- Consolidar el conteo nacional de diagnósticos barriendo los 3 servidores físicos
EXPLAIN ANALYZE
SELECT Diagnostico, COUNT(*) AS Total, 'Master (Local)' AS Nodo_Fisico
FROM AtencionMedica GROUP BY Diagnostico
UNION ALL
SELECT * FROM dblink(
    'host=pg_worker1 dbname=minsa_worker1 user=abel password=incentivos',
    'SELECT Diagnostico, COUNT(*)::int, ''Worker 1'' FROM AtencionMedica GROUP BY Diagnostico'
) AS w1(Diagnostico VARCHAR(50), Total INT, Nodo_Fisico TEXT)
UNION ALL
SELECT * FROM dblink(
    'host=pg_worker2 dbname=minsa_worker2 user=abel password=incentivos',
    'SELECT Diagnostico, COUNT(*)::int, ''Worker 2'' FROM AtencionMedica GROUP BY Diagnostico'
) AS w2(Diagnostico VARCHAR(50), Total INT, Nodo_Fisico TEXT);


-- CONSULTA DISTRIBUIDA 2:
-- Cruce JOIN entre pacientes locales (Master) y un diagnóstico alojado en Worker 1
EXPLAIN ANALYZE
SELECT p.DNI, p.Nombre, p.Apellidos, rem.Diagnostico, rem.Ciudad
FROM Pacientes p
JOIN dblink(
    'host=pg_worker1 dbname=minsa_worker1 user=abel password=incentivos',
    'SELECT DNI, Diagnostico, Ciudad FROM AtencionMedica WHERE Diagnostico = ''Asma'''
) AS rem(DNI CHAR(8), Diagnostico VARCHAR(50), Ciudad VARCHAR(50))
ON p.DNI = rem.DNI;


