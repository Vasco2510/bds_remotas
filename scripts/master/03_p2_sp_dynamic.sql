CREATE OR REPLACE PROCEDURE sp_insertar_atencion(
    p_dni CHAR(8),
    p_codmedico INTEGER,
    p_ciudad VARCHAR(50),
    p_diagnostico VARCHAR(50),
    p_peso DECIMAL(5,2),
    p_talla DECIMAL(4,2),
    p_presion VARCHAR(10),
    p_edad INTEGER,
    p_fecha DATE
) LANGUAGE plpgsql AS $$
DECLARE
    v_clean_diag TEXT;
    v_part_name TEXT;
    v_existe    BOOLEAN;
    v_sql       TEXT;

BEGIN
    -- 1. Estandarizar el nombre de la partición (Ej: "Gripe Aviar" -> "am_gripe_aviar")
    v_clean_diag := translate(lower(p_diagnostico), 'áéíóúñ', 'aeioun');
    v_part_name  := 'am_' || trim(both '_' from regexp_replace(v_clean_diag, '[^a-z0-9]+', '_', 'g'));

    -- 2. Verificar en el catálogo del sistema si ya existe
    SELECT EXISTS (
        SELECT 1
        FROM pg_class c
        JOIN pg_inherits i ON c.oid = i.inhrelid
        JOIN pg_class p ON i.inhparent = p.oid
        WHERE p.relname = 'atencionmedica'
          AND c.relname = v_part_name
    ) INTO v_existe;

    -- 3. Si el fragmento no existe, generamos el DDL dinámico
    IF NOT v_existe THEN
        BEGIN
            v_sql := format(
                'CREATE TABLE %I PARTITION OF AtencionMedica FOR VALUES IN (%L);',
                v_part_name,
                p_diagnostico
            );

            RAISE NOTICE '[MINSA AUTO-DDL] Creando nueva partición local: "%" para diagnóstico: "%"', v_part_name, p_diagnostico;
            EXECUTE v_sql;

        EXCEPTION
            WHEN duplicate_table THEN

                RAISE NOTICE 'La partición "%" ya fue creada por una transacción concurrente.', v_part_name;
        END;
    END IF;

    -- 4. Inserción del registro
    INSERT INTO AtencionMedica (
        DNI, CodMedico, Ciudad, Diagnostico, Peso, Talla, PresionArterial, Edad, FechaAtencion
    ) VALUES (
        p_dni, p_codmedico, p_ciudad, p_diagnostico, p_peso, p_talla, p_presion, p_edad, p_fecha
    );

END;
$$;



-- EVIDENCIA DE PRUEBAS 
-- Caso A: Diagnóstico totalmente nuevo (Debe disparar el CREATE TABLE)
CALL sp_insertar_atencion('11223344', 105, 'Arequipa', 'Dengue', 71.2, 1.68, '120/80', 28, '2026-06-01');

-- Caso B: Otro diagnóstico nuevo
CALL sp_insertar_atencion('22334455', 108, 'Cusco', 'Bronquitis', 65.0, 1.60, '115/75', 42, '2026-06-02');

-- Caso C: Diagnóstico repetido del Caso A (Prueba de idempotencia: NO debe intentar crear tabla)
CALL sp_insertar_atencion('33445566', 105, 'Ica', 'Dengue', 80.1, 1.75, '130/85', 35, '2026-06-03');

SELECT relname FROM pg_class WHERE relname IN ('am_dengue', 'am_bronquitis');


/* =========================================================================
   ¿Se puede usar un TRIGGER en tablas particionadas como alternativa?

   Sí es posible técnicamente (desde PostgreSQL 13 se permiten triggers BEFORE INSERT
   a nivel de fila en tablas particionadas). Sin embargo, en Arquitectura de Software
   se considera una mala práctica crítica por dos razones:

   1. Bloqueos severos: Ejecutar un DDL (CREATE TABLE) dentro de una
      transacción DML disparada por un trigger eleva el nivel de bloqueo de la tabla
      padre a 'AccessExclusiveLock', paralizando todas las lecturas concurrentes del hospital.
   2. Violación del Principio de Responsabilidad Única: El motor de base de datos ocultaría
      mutaciones estructurales del esquema detrás de un simple comando INSERT, dificultando
      el trazado de errores y auditorías de rendimiento. El Stored Procedure hace explícita
      la intención transaccional.
========================================================================= */
