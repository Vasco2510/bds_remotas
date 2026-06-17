# Project: BD2 Lab 12 - Distributed PostgreSQL

## Overview
This project provides a Docker-based environment to simulate a distributed PostgreSQL database setup, consisting of one master node and two worker nodes for data sharding experimentation.

## Key Components
- `docker-compose.yml`: Defines the services (`pg_master`, `pg_worker1`, `pg_worker2`) using PostgreSQL 15.
- `scripts/`: Contains SQL scripts for database initialization and data population.
  - `01_init_master.sql`: Schema setup and FDW infrastructure on the master.
  - `02_init_workers.sql`: Initial configuration for remote nodes.
  - `02_data_generator.sql` (also referred to as `03_data_generator.sql` in README): Script to generate 50,000 synthetic records.

## Building and Running
- Ensure `.env` is configured correctly with necessary database credentials based on `.env.example`.
- To start the environment: `docker-compose up -d`
- To stop: `docker-compose down`

## Development Conventions
- Scripts in `scripts/` should be executed in order for a correct setup.
- Database services are mapped to ports 5432, 5433, and 5434 on the host machine.
