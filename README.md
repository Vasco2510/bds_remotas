## Estructura de archivos
```
.
├── docker-compose.yml          # 3 servicios: pg_master (5432), pg_worker1 (5433), pg_worker2 (5434)
├── .env.example                # Variables de entorno documentadas
├── scripts/
│   ├── master/                 # Scripts que se ejecutan SOLO en pg_master al iniciar
│   │   ├── 01_init_master.sql  # Creación de tablas AtencionMedica y Pacientes con particionamiento
│   │   └── 02_data_generator.sql # Poblado: 50k Pacientes + 50k AtencionMedica + 20 registros test P2
│   └── workers/                # Scripts que se ejecutan SOLO en pg_worker1 y pg_worker2 al iniciar
│       └── 02_init_workers.sql # Extensiones postgres_fdw, dblink y tablas base en workers
├── README.md
└── .env
```

## Inicio rápido
```bash
# 1. Clonar el repositorio
# 2. Pararse en la raíz del proyecto
# 3. Iniciar los 3 contenedores
docker-compose up -d

# 4. Verificar que los 3 contenedores estén corriendo
docker-compose ps

# 5. Conectarse al master (puerto 5432)
docker exec -it pg_master psql -U abel -d minsa_db
```
