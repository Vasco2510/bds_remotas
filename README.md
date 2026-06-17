# Laboratorio BD2: Fragmentación Dinámica, Asignación y Consultas Distribuidas

**Curso:** Base de Datos II — UTEC  
**Profesor:** Heider Sanchez  
**Periodo:** 2026-1

---

## Contexto del Laboratorio

El Ministerio de Salud ha lanzado una iniciativa nacional para recolectar datos de atenciones médicas. Se creó la tabla `AtencionMedica` en un servidor principal con datos de Lima y Callao. Ahora se expande a nivel nacional usando **fragmentación horizontal por diagnóstico** con creación dinámica de fragmentos y **distribución en 3 servidores** (1 Master + 2 Workers).

### Tablas principales

**AtencionMedica** — Fragmentada por `Diagnostico` (LIST):
| Columna | Tipo | Descripción |
|---------|------|-------------|
| DNI | CHAR(8) | Documento del paciente |
| CodMedico | INTEGER | Código del médico |
| Ciudad | VARCHAR(50) | Ciudad de atención |
| Diagnostico | VARCHAR(50) | **Clave de partición** |
| Peso | DECIMAL(5,2) | Peso en kg |
| Talla | DECIMAL(4,2) | Talla en metros |
| PresionArterial | VARCHAR(10) | Ej: 130/85 |
| Edad | INTEGER | Edad (>= 0) |
| FechaAtencion | DATE | Fecha de atención |

**Pacientes** — Fragmentada por `CiudadOrigen` (RANGE con vector `["H", "P"]`):
| Columna | Tipo | Descripción |
|---------|------|-------------|
| DNI | CHAR(8) | Documento (PK compuesta con CiudadOrigen) |
| Nombre | VARCHAR(50) | Nombres |
| Apellidos | VARCHAR(100) | Apellidos |
| FechaNacimiento | DATE | Fecha de nacimiento |
| Sexo | CHAR(1) | M o F |
| CiudadOrigen | VARCHAR(50) | **Clave de partición** |

> ⚠️ Nota técnica: En PostgreSQL, las tablas particionadas por RANGE requieren que la PK incluya la columna de partición. Por eso `Pacientes` tiene `PRIMARY KEY (DNI, CiudadOrigen)`.

---

## Arquitectura Docker

```
┌─────────────────────────────────────────────────────┐
│                    minsa_network                      │
│                                                       │
│  ┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  │  pg_master    │   │  pg_worker1  │   │  pg_worker2  │
│  │  (coordinador)│   │  (worker 1)  │   │  (worker 2)  │
│  │  Puerto: 5432 │   │  Puerto: 5433 │   │  Puerto: 5434 │
│  │  DB: minsa_db │   │  DB: minsa_w1 │   │  DB: minsa_w2 │
│  └──────┬───────┘   └──────┬───────┘   └──────┬───────┘
│         │                  │                   │
│  ┌──────┴───────┐          │                   │
│  │  postgres_fdw │◄─────────┴───────────────────┘
│  │  + dblink     │   Conexiones entre servidores
│  └──────────────┘
└─────────────────────────────────────────────────────┘
```

**Versión:** PostgreSQL 15  
**Credenciales:** Usuario `abel` / contraseña `incentivos`

---

## Inicio Rápido

```bash
# 1. Clonar y entrar al proyecto
cd lab12

# 2. Iniciar los 3 contenedores
docker-compose up -d

# 3. Verificar que estén corriendo
docker-compose ps

# 4. Ver logs de inicialización (opcional)
docker logs pg_master
docker logs pg_worker1
docker logs pg_worker2
```

---

## Conexiones desde pgAdmin

Agregar 3 servidores en pgAdmin:

| Servidor | Host | Puerto | DB | Usuario |
|----------|------|--------|----|---------|
| pg_master | `localhost` | `5432` | `minsa_db` | `abel` |
| pg_worker1 | `localhost` | `5433` | `minsa_worker1` | `abel` |
| pg_worker2 | `localhost` | `5434` | `minsa_worker2` | `abel` |

> Para conectarte desde otro equipo, usa la IP del host donde corren los contenedores.

---

## Estado Actual (Precargado por Integrante 1)

Todo se inicializa **automáticamente** al hacer `docker-compose up -d`:

| Componente | Detalle |
|------------|---------|
| `AtencionMedica` | Particionada por LIST (`Diagnostico`) con 4 particiones iniciales: Diabetes, Obesidad, Cardiopatía, Hipertensión |
| `Pacientes` | Particionada por RANGE (`CiudadOrigen`) con 3 particiones: A-G, H-O, P-Z |
| 50,000 registros en `Pacientes` | Datos sintéticos con ciudades de todo el Perú |
| 50,000 registros en `AtencionMedica` | Asociados aleatoriamente a los pacientes |
| Extensiones instaladas | `postgres_fdw` y `dblink` en master y workers |
| Tablas base en workers | `AtencionMedica` y `Pacientes` creadas en worker1 y worker2 |
| 20 registros extras | Insertados con diagnósticos nuevos (Gripe, Asma, etc.) si P2 ya está activo; si no, se omiten con aviso |

---

---

## Tareas Pendientes por Integrante

### 👤 Integrante 2 — Programador de Base de Datos (Backend / DB Developer)

Foco: lógica procedimental PL/pgSQL, automatización de fragmentos, motor de la primera parte.

#### P2: Procedimiento Dinámico Local (4 pts) — `scripts/master/03_p2_sp_dynamic.sql`

```sql
-- Procedimiento que inserta en AtencionMedica creando la partición si no existe
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
BEGIN
    -- 1. Verificar si existe partición para p_diagnostico (consultar pg_class + pg_inherits)
    -- 2. Si no existe: EXECUTE 'CREATE TABLE am_' || ... || ' PARTITION OF AtencionMedica FOR VALUES IN (...)' 
    -- 3. Insertar el registro
    -- 4. Capturar excepción si la partición ya existe (duplicado)
END;
$$;
```

**Requisitos:**
- Verificar existencia de partición en `pg_class` + `pg_inherits`
- Usar `EXECUTE` con SQL dinámico para crear la partición
- Insertar el registro en la partición correspondiente
- Insertar `k` registros (distintos) que evidencien la creación dinámica de fragmentos
- Investigar si se puede usar un `TRIGGER` en tablas particionadas (como alternativa)

**Demo esperada:**
```sql
CALL sp_insertar_atencion('12345678', 201, 'Ica', 'Gripe', 68.5, 1.70, '120/80', 30, '2025-07-01');
-- Debe crear automáticamente la partición am_gripe si no existe
-- Verificar: SELECT relname FROM pg_class WHERE relkind='p';
```

#### P3: Asignación Distribuida (5 pts) — `scripts/master/04_p3_sp_distributed.sql`

```sql
-- Procedimiento que inserta creando la partición en el servidor remoto correspondiente
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
    p_servidor_destino TEXT  -- 'local', 'worker1', 'worker2'
) LANGUAGE plpgsql AS $$
BEGIN
    -- 1. Si p_servidor_destino = 'local': mismo lógica que P2 (crear partición local)
    -- 2. Si p_servidor_destino = 'worker1':
    --      Usar dblink para conectarse a worker1 y ejecutar creación remota de partición
    --      Luego insertar remotamente
    -- 3. Si p_servidor_destino = 'worker2': igual que worker1
    -- 4. Opcional: usar postgres_fdw con CREATE FOREIGN TABLE dinámica
END;
$$;
```

**Requisitos:**
- Modificar P2 para que cree fragmentos en servidores remotos
- Usar `dblink` o `postgres_fdw`
- Distribuir fragmentos entre master, worker1 y worker2
- Ejecutar 2 consultas que evidencien tablas distribuidas (ej: SELECT desde master que cruce datos locales + remotos)
- Incluir `EXPLAIN ANALYZE` de las consultas

**Demo esperada:**
```sql
CALL sp_insertar_atencion_distribuido('87654321', 202, 'Piura', 'Asma', 72.0, 1.65, '130/85', 25, '2025-07-05', 'worker1');
-- Verificar desde master con dblink:
SELECT * FROM dblink('host=pg_worker1 ...', 'SELECT * FROM am_asma') AS t(...);
```

---

### 👤 Integrante 3 — Especialista en Optimización y Consultas (Analyst & Tuning Specialist)

Foco: corazón analítico del laboratorio (consultas distribuidas), puntaje estricto de la segunda parte.

#### P4: Algoritmos Distribuidos Localmente (4 pts) — `scripts/master/05_p4_algoritmos_locales.sql`

Simular el ambiente distribuido **en un solo servidor** usando tablas temporales.

**Tabla de distribución de fragmentos (simulada):**

| Fragmento | Servidor simulado | Condición |
|-----------|-------------------|-----------|
| `pac_a_g` (Ciudades A-G) | Sitio 1 | `CiudadOrigen < 'H'` |
| `pac_h_o` (Ciudades H-O) | Sitio 2 | `CiudadOrigen >= 'H' AND CiudadOrigen < 'P'` |
| `pac_p_z` (Ciudades P-Z) | Sitio 3 | `CiudadOrigen >= 'P'` |
| `am_diabetes` | Sitio 1 | `Diagnostico = 'Diabetes'` |
| `am_obesidad` | Sitio 1 | `Diagnostico = 'Obesidad'` |
| `am_cardiopatia` | Sitio 2 | `Diagnostico = 'Cardiopatía'` |
| `am_hipertension` | Sitio 3 | `Diagnostico = 'Hipertensión'` |

**Consultas a implementar (las 4 obligatorias):**

```sql
-- Consulta 1: SELECT * FROM Pacientes ORDER BY FechaNacimiento;
-- Algoritmo distribuido:
--   Paso 1: Obtener fragmentos de cada sitio en tablas temporales
--   CREATE TEMP TABLE temp_pac_a_g ON COMMIT DROP AS SELECT * FROM pac_a_g;
--   CREATE TEMP TABLE temp_pac_h_o ON COMMIT DROP AS SELECT * FROM pac_h_o;
--   CREATE TEMP TABLE temp_pac_p_z ON COMMIT DROP AS SELECT * FROM pac_p_z;
--   Paso 2: UNION ALL + ORDER BY (fusión mezclada)
--   SELECT * FROM temp_pac_a_g UNION ALL ... ORDER BY FechaNacimiento;
--   Incluir EXPLAIN ANALYZE

-- Consulta 2: SELECT DISTINCT CiudadOrigen FROM Pacientes;
-- Algoritmo distribuido: proyectar distinct de cada fragmento y luego fusionar

-- Consulta 3: SELECT Diagnostico, AVG(Edad) AS PromEdad FROM AtencionMedica GROUP BY Diagnostico;
-- Algoritmo distribuido: agrupar en cada fragmento, luego consolidar promedios ponderados

-- Consulta 4: SELECT * FROM Pacientes NATURAL JOIN AtencionMedica;
-- Algoritmo distribuido: JOIN entre fragmentos locales y remotos por DNI
```

**Requisitos:**
- Cada consulta debe documentar los pasos intermedios en comentarios
- Usar `CREATE TEMP TABLE ... ON COMMIT DROP` (se eliminan al finalizar)
- Incluir `EXPLAIN ANALYZE` con captura gráfica de pgAdmin
- ⚠️ Si P4 está mal implementado, se anula P4 y P5

#### P5: Algoritmos Distribuidos en 3 Servidores (6 pts) — `scripts/master/06_p5_algoritmos_distribuidos.sql`

Implementar las 4 consultas en la arquitectura real de 3 servidores usando `postgres_fdw`.

```sql
-- 1. Crear foreign tables en master apuntando a los workers
CREATE FOREIGN TABLE ft_pac_a_g (...) SERVER worker1_fdw OPTIONS (...);
CREATE FOREIGN TABLE ft_pac_h_o (...) SERVER worker2_fdw OPTIONS (...);
-- etc.

-- 2. Ejecutar las 4 consultas igual que P4 pero contra foreign tables
--    (el optimizador hará push-down de filtros y proyecciones)

-- 3. Incluir EXPLAIN ANALYZE que evidencie la integración de servidores
--    (deben aparecer nodos "Foreign Scan" en el plan)
```

**Distribución sugerida de fragmentos:**

| Fragmento | Ubicación |
|-----------|-----------|
| `am_diabetes` | Master (local) |
| `am_obesidad` | Master (local) |
| `am_cardiopatia` | Worker 1 |
| `am_hipertension` | Worker 2 |
| `pac_a_g` (A-G) | Master (local) |
| `pac_h_o` (H-O) | Worker 1 |
| `pac_p_z` (P-Z) | Worker 2 |

**Requisitos:**
- 1 coordinador (master) + 2 workers
- Usar `postgres_fdw` para acceso remoto
- Fragmentos distribuidos entre los 3 servidores
- Ejecutar las 4 consultas del P4
- Mostrar planes de ejecución con nodos `Foreign Scan`
- Script completamente replicable

---

## Entregable Final (Equipo completo)

El documento debe contener:
1. Explicación de resultados con capturas de pantalla relevantes
2. Script SQL unificado y replicable (de inicio a fin)
3. Flujo de ejecución:

```
Paso 1: docker-compose up -d                    (Int 1)
Paso 2: Ejecutar 03_p2_sp_dynamic.sql            (Int 2)
Paso 3: Ejecutar 05_p4_algoritmos_locales.sql    (Int 3)
Paso 4: Ejecutar 04_p3_sp_distributed.sql        (Int 2)
Paso 5: Ejecutar 06_p5_algoritmos_distribuidos.sql (Int 3)
```

---

## Consultas Rápidas de Verificación

```sql
-- 1. Conteo de registros
SELECT 'Pacientes' AS tabla, COUNT(*) FROM Pacientes
UNION ALL
SELECT 'AtencionMedica', COUNT(*) FROM AtencionMedica;

-- 2. Ver particiones existentes
SELECT
    c.relname AS tabla_padre,
    p.relname AS particion,
    pg_get_expr(p.relpartbound, p.oid) AS definicion
FROM pg_class c
JOIN pg_inherits i ON c.oid = i.inhparent
JOIN pg_class p ON i.inhrelid = p.oid
WHERE c.relname IN ('atencionmedica', 'pacientes')
ORDER BY c.relname, p.relname;

-- 3. Distribución por diagnóstico
SELECT Diagnostico, COUNT(*) FROM AtencionMedica GROUP BY Diagnostico;

-- 4. Probar dblink a worker1
SELECT * FROM dblink(
    'host=pg_worker1 dbname=minsa_worker1 user=abel password=incentivos',
    'SELECT current_database(), version()'
) AS t(db text, ver text);
```

---

## Estructura de Archivos

```
.
├── docker-compose.yml              # 3 servicios PostgreSQL 15
├── .env.example                    # Variables documentadas (copiar a .env si se requiere)
├── README.md                       # Este archivo
├── scripts/
│   ├── master/                     # Scripts para pg_master (se ejecutan al iniciar el contenedor)
│   │   ├── 01_init_master.sql      # Tablas, particiones, extensiones FDW
│   │   └── 02_data_generator.sql   # 50k Pacientes + 50k AtencionMedica
│   └── workers/                    # Scripts para pg_worker1 y pg_worker2
│       └── 02_init_workers.sql     # Extensiones + tablas base en workers
```

---

## Notas para el Equipo

### Ejecución de scripts

- **Solo `01_` y `02_` se ejecutan automáticamente** al arrancar pg_master (inicialización).
- Los scripts `03_`, `04_`, `05_`, `06_` deben ejecutarse **manualmente** en orden, conectándose al master:

```bash
docker exec -i pg_master psql -U abel -d minsa_db -f scripts/master/03_p2_sp_dynamic.sql
docker exec -i pg_master psql -U abel -d minsa_db -f scripts/master/04_p3_sp_distributed.sql
# etc.
```

O desde pgAdmin: abrir el archivo SQL y ejecutarlo.

### Orden de ejecución recomendado

```
01_init_master.sql        (automático — ya ejecutado)
02_data_generator.sql     (automático — ya ejecutado)
03_p2_sp_dynamic.sql      (manual — Integrante 2)
05_p4_algoritmos_locales.sql  (manual — Integrante 3, puede ir en paralelo con P3)
04_p3_sp_distributed.sql  (manual — Integrante 2, después de P2)
06_p5_algoritmos_distribuidos.sql (manual — Integrante 3, después de P4 y FDW listo)
```

### Reinicio completo
```bash
docker-compose down -v && docker-compose up -d
```
⚠️ `-v` elimina los volúmenes (datos incluidos). Todo vuelve al estado inicial.

### Nomenclatura de archivos
- `01_`, `02_` — Infraestructura (Integrante 1) — ejecución automática
- `03_p2_` — Procedimiento dinámico local (Integrante 2)
- `04_p3_` — SP distribuido (Integrante 2)
- `05_p4_` — Algoritmos locales (Integrante 3)
- `06_p5_` — Algoritmos distribuidos (Integrante 3)
