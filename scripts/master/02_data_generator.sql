-- ============================================================================
-- POBLADO DE DATOS SINTÉTICOS MASIVOS (MÍNIMO 50,000 REGISTROS)
-- ============================================================================

-- 1. Poblado de la tabla Pacientes (Genera 50,000 registros únicos)
INSERT INTO Pacientes (DNI, Nombre, Apellidos, FechaNacimiento, Sexo, CiudadOrigen)
SELECT 
    LPAD(s.id::text, 8, '0') AS DNI, -- Genera DNIs fijos de 8 dígitos correlativos (ej: 00000001)
    (ARRAY['Juan', 'Maria', 'Pedro', 'Ana', 'Luis', 'Carmen', 'Jorge', 'Elena', 'Carlos', 'Sofia'])[FLOOR(RANDOM() * 10) + 1] AS Nombre,
    (ARRAY['Gomez', 'Rodriguez', 'Perez', 'Garcia', 'Martinez', 'Lopez', 'Sanchez', 'Diaz', 'Flores', 'Torres'])[FLOOR(RANDOM() * 10) + 1] || ' ' ||
    (ARRAY['Alva', 'Benitez', 'Castro', 'Espinoza', 'Quispe', 'Mendoza', 'Ramos', 'Vargas', 'Rojas', 'Ruiz'])[FLOOR(RANDOM() * 10) + 1] AS Apellidos,
    '1960-01-01'::DATE + (RANDOM() * 16435)::INT AS FechaNacimiento, -- Edades variadas
    (ARRAY['M', 'F'])[FLOOR(RANDOM() * 2) + 1] AS Sexo,
    (ARRAY['Arequipa', 'Chiclayo', 'Cusco', 'Huancayo', 'Iquitos', 'Lima', 'Piura', 'Puno', 'Trujillo', 'Tacna'])[FLOOR(RANDOM() * 10) + 1] AS CiudadOrigen
FROM generate_series(1, 50000) AS s(id);

-- 2. Poblado de la tabla AtencionMedica (Genera 50,000 registros asociados)
INSERT INTO AtencionMedica (DNI, CodMedico, Ciudad, Diagnostico, Peso, Talla, PresionArterial, Edad, FechaAtencion)
SELECT 
    LPAD(FLOOR(RANDOM() * 50000 + 1)::text, 8, '0') AS DNI, -- Vincula aleatoriamente con los DNIS de Pacientes
    FLOOR(RANDOM() * 50 + 101)::INT AS CodMedico,
    (ARRAY['Lima', 'Callao', 'Arequipa', 'Trujillo', 'Cusco'])[FLOOR(RANDOM() * 5) + 1] AS Ciudad,
    -- Limitado estrictamente a los 4 diagnósticos iniciales para evitar errores de partición en este paso
    (ARRAY['Diabetes', 'Obesidad', 'Cardiopatía', 'Hipertensión'])[FLOOR(RANDOM() * 4) + 1] AS Diagnostico,
    ROUND((RANDOM() * (120 - 50) + 50)::NUMERIC, 2) AS Peso,
    ROUND((RANDOM() * (2.00 - 1.45) + 1.45)::NUMERIC, 2) AS Talla,
    (ARRAY['120/80', '130/85', '140/90', '150/95', '110/70'])[FLOOR(RANDOM() * 5) + 1] AS PresionArterial,
    FLOOR(RANDOM() * (90 - 18) + 18)::INT AS Edad,
    '2025-01-01'::DATE + (RANDOM() * 365)::INT AS FechaAtencion
FROM generate_series(1, 50000) AS s(id);

-- 3. Insertar registros con diagnósticos adicionales para probar P2 (creación dinámica de fragmentos)
-- Se espera que fallen hasta que P2 esté implementado (controlado con EXCEPTION)
DO $$
BEGIN
    INSERT INTO AtencionMedica (DNI, CodMedico, Ciudad, Diagnostico, Peso, Talla, PresionArterial, Edad, FechaAtencion)
    SELECT 
        LPAD((50000 + s.id)::text, 8, '0') AS DNI,
        FLOOR(RANDOM() * 50 + 101)::INT AS CodMedico,
        (ARRAY['Ica', 'Huancayo', 'Piura', 'Tacna', 'Puno'])[FLOOR(RANDOM() * 5) + 1] AS Ciudad,
        (ARRAY['Gripe', 'Asma', 'Fractura', 'Anemia', 'Migraña'])[FLOOR(RANDOM() * 5) + 1] AS Diagnostico,
        ROUND((RANDOM() * (120 - 50) + 50)::NUMERIC, 2) AS Peso,
        ROUND((RANDOM() * (2.00 - 1.45) + 1.45)::NUMERIC, 2) AS Talla,
        (ARRAY['120/80', '130/85', '140/90', '110/70', '125/82'])[FLOOR(RANDOM() * 5) + 1] AS PresionArterial,
        FLOOR(RANDOM() * (90 - 18) + 18)::INT AS Edad,
        '2025-06-01'::DATE + (RANDOM() * 30)::INT AS FechaAtencion
    FROM generate_series(1, 20) AS s(id);
    RAISE NOTICE 'Diagnósticos adicionales insertados correctamente (P2 activo)';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Diagnósticos adicionales omitidos (se requiere P2 para crearlos dinámicamente)';
END;
$$;