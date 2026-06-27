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


#### P5 — Algoritmos distribuidos en tres servidores (Master-Worker)

Paquete autocontenido. Levanta 1 coordinador + 2 workers, distribuye los
fragmentos de `Pacientes` y `AtencionMedica` entre los tres, y ejecuta las
4 consultas en ambiente distribuido con `EXPLAIN ANALYZE`.

**Arquitectura y distribución de fragmentos:**

| Servidor    | Puerto host | Fragmentos que almacena |
|-------------|-------------|--------------------------|
| coordinador | 5432        | AtencionMedica: Diabetes, Hipertensión · Pacientes: P–Z |
| worker1     | 5433        | AtencionMedica: Obesidad · Pacientes: A–G |
| worker2     | 5434        | AtencionMedica: Cardiopatía · Pacientes: H–O |

- `AtencionMedica` se fragmenta por `Diagnostico` (LIST).
- `Pacientes` se fragmenta por `CiudadOrigen` (RANGE, vector `["H","P"]`).
- El coordinador mantiene las tablas particionadas padre; las particiones
  remotas son tablas foráneas (`postgres_fdw`) sobre los workers.

**Requisitos:** Docker Desktop en ejecución.

**Estructura:**
```
lab13_p5/
├── docker-compose.yml
└── sql/
    ├── p5_worker1.sql      # base + tablas fisicas (worker1)
    ├── p5_worker2.sql      # base + tablas fisicas (worker2)
    ├── p5_coordinador.sql  # FDW + particiones distribuidas + datos (>=50k)
    └── p5_consultas.sql    # 4 consultas + EXPLAIN ANALYZE
```

**Ejecución manual (paso a paso):**
```bash
# 1) Levantar los 3 servidores
docker compose up -d

# 2) Tablas fisicas en los workers  (PowerShell: usar Get-Content | docker exec -i)
docker exec -i lab13_worker1 psql -U postgres < sql/p5_worker1.sql
docker exec -i lab13_worker2 psql -U postgres < sql/p5_worker2.sql

# 3) Coordinador: FDW + particiones distribuidas + carga (>=50k)
docker exec -i lab13_coordinador psql -U postgres < sql/p5_coordinador.sql

# 4) Las 4 consultas distribuidas con EXPLAIN ANALYZE
docker exec -i lab13_coordinador psql -U postgres -d lab13_p5 < sql/p5_consultas.sql
```

> En PowerShell el redireccionamiento `<` no funciona; reemplaza
> `psql ... < archivo.sql` por `Get-Content archivo.sql | docker exec -i ... psql ...`.

**Cómo leer los planes (lo que evidencia P5):**
En cada plan, los nodos `Foreign Scan` sobre `worker1`/`worker2` junto con los
`Seq Scan` locales muestran que la consulta integra los tres servidores. El
mapeo con el algoritmo distribuido (localización) es directo:

| Nodo del plan | Significado distribuido |
|---|---|
| `Foreign Scan` (worker) / `Seq Scan` (local) | proceso local + transferencia del fragmento |
| `Append` / `Merge Append` | unión `∪` de los fragmentos (localización) |
| `HashAggregate` / `Hash Join` / `Sort` | combinación final en el coordinador |

Planes esperados: Q1 `Merge Append` (2 foreign + 1 local) → orden global;
Q2 `Append` → `HashAggregate` (distinct); Q3 `Append` → `HashAggregate` (AVG);
Q4 `Hash Join` alimentado por dos `Append` (6 fragmentos de 3 servidores).

**Capturas gráficas (pgAdmin):**
Conéctate desde pgAdmin a `localhost:5432` (usuario `postgres`, contraseña
`postgres`, base `lab13_p5`) y usa el botón **Explain Analyze** sobre cada
consulta de `sql/p5_consultas.sql` para obtener el plan gráfico.

**Verificar ubicación física de los datos:**
```bash
docker exec -it lab13_worker1 psql -U postgres -d lab13_p5 -c "SELECT count(*) FROM am_obesidad;"
docker exec -it lab13_worker2 psql -U postgres -d lab13_p5 -c "SELECT count(*) FROM am_cardiopatia;"
docker exec -it lab13_worker1 psql -U postgres -d lab13_p5 -c "SELECT count(*) FROM pacientes_ag;"
```

**Reiniciar / limpiar:**
```bash
docker compose down -v   # detiene y borra los datos; vuelve a correr para reconstruir
```

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
