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

## Lo que NO está hecho (para Integrantes 2 y 3)

| Tarea | Responsable | Archivo sugerido |
|-------|-------------|------------------|
| **P2:** Procedimiento dinámico de creación de particiones | Integrante 2 | `scripts/master/03_sp_dynamic_partition.sql` |
| **P3:** Adaptación distribuida del SP (dblink/FDW a workers) | Integrante 2 | `scripts/master/04_sp_distributed.sql` |
| **P4:** Algoritmos distribuidos locales (tablas temporales) | Integrante 3 | `scripts/master/05_p4_local_algorithms.sql` |
| **P5:** Algoritmos distribuidos en 3 servidores (FDW) | Integrante 3 | `scripts/master/06_p5_distributed_queries.sql` |

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

- **Los scripts en `scripts/master/` se ejecutan automáticamente** al arrancar pg_master. Si agregas un script nuevo, se ejecutará en orden alfabético.
- Si necesitas reiniciar desde cero: `docker-compose down -v && docker-compose up -d`
- Los Integrantes 2 y 3 deben crear sus scripts dentro de `scripts/master/` con el naming `03_`, `04_`, etc.
