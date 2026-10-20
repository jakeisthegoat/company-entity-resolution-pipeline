# Database migrations

DuckDB scripts that create every schema, table, view and configuration row. Running them on an empty database creates everything; running them again is safe (tables are created only if missing, views are replaced, seeds upsert).

## Run order

[create_database.py](create_database.py) runs `00_setup`, then each numbered schema folder in order, `00_tables/` before `01_seeds/` (where a schema has seeds), files in numeric order. Each folder has a README describing its tables:

| Folder | Schema | Tables |
|---|---|---|
| [`00_setup`](00_setup/README.md) | all | Creates the seven schemas |
| [`01_config`](01_config/README.md) | `config` | `source`, `pipeline`, `pipeline_file_pattern`, `entity_resolution_order`, `qc_check`, `entity_match_setting`, `entity_match_attribute` (+ seeds) |
| [`02_ingestion`](02_ingestion/README.md) | `ingestion` | `file_ingestion_log`, `file_ingestion_failure_log` |
| [`03_bronze`](03_bronze/README.md) | `bronze` | `inbound_company_raw`, `inbound_person_raw`, `inbound_person_company_raw`, `inbound_salesforce_account_raw` |
| [`04_silver`](04_silver/README.md) | `silver` | `company`, `account`, `person`, `person_company` |
| [`05_entity_resolution`](05_entity_resolution/README.md) | `entity_resolution` | `company_master`, `person_master`, match inputs, match results, review queues, `company_alias` / `person_alias` views |
| [`06_qc`](06_qc/README.md) | `qc` | `silver_validation_warning`, `check_finding` |
| [`07_gold`](07_gold/README.md) | `gold` | `company`, `person`, `person_company`, `crosswalk` |

```bash
.venv/bin/python 00_database/create_database.py           # create, or update an existing database
.venv/bin/python 00_database/create_database.py --fresh   # delete pipeline.duckdb first and start empty
```

## Conventions

- **One file per table**, named `NNN_<table>.sql`; the number is the creation order. A column that refers to another table says so in a comment (`-- -> config.source`); DuckDB does not enforce foreign keys across schemas, so the gold tests check the links that matter.
- **Ids:** generated ids use a sequence (`CREATE SEQUENCE` + `DEFAULT nextval(...)`).
- **Tables:** `CREATE TABLE IF NOT EXISTS` with all columns and constraints. Nothing here has been deployed, so a schema change is made directly in the table's CREATE script (no `ALTER TABLE` migrations); to apply it, run `create_database.py --fresh`.
- **Views:** `CREATE OR REPLACE VIEW`.
- **Seeds:** explicit ids, `INSERT … ON CONFLICT (id) DO UPDATE`, so a re-run updates rows in place. Only `config` has seed data, so only `01_config` has a `01_seeds/` folder.
- **Bronze columns** are all VARCHAR and copied from the source file headers (all 269 Salesforce columns).
