# 00_setup

Runs first. [001_create_schemas.sql](001_create_schemas.sql) creates the seven schemas (`CREATE SCHEMA IF NOT EXISTS`), so every later script can assume its schema exists. Back to [database migrations](../README.md).

| Schema | Holds | Tables created by |
|---|---|---|
| `config` | Sources, pipelines, file routing, entity resolution order, matching settings, QC checks | [01_config](../01_config/README.md) |
| `ingestion` | File log and failure history | [02_ingestion](../02_ingestion/README.md) |
| `bronze` | Raw rows, exactly as received | [03_bronze](../03_bronze/README.md) |
| `silver` | Clean, typed, versioned rows | [04_silver](../04_silver/README.md) |
| `entity_resolution` | Match inputs, decisions, master ids, review queues | [05_entity_resolution](../05_entity_resolution/README.md) |
| `qc` | Validation warnings, check findings, run summaries | [06_qc](../06_qc/README.md) |
| `gold` | Published companies, people, affiliations, crosswalk | [07_gold](../07_gold/README.md) |
