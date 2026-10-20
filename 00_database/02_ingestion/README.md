# 02_ingestion: `ingestion` schema

The record of every file that arrived and what happened to it. Written by file intake ([01_ingestion](../../01_ingestion/docs/Ingestion-Design.md)) and the bronze load ([02_bronze](../../02_bronze/docs/Bronze-Design.md)). No seed data. Back to [database migrations](../README.md).

| Table | Grain | Purpose |
|---|---|---|
| [`file_ingestion_log`](00_tables/001_file_ingestion_log.sql) | One row per file | The file's **latest** state: `file_id` (PK), `pipeline_id`, `original_file_name`, `file_path` (where it is now), `file_size`, `row_count` (filled in by bronze), `arrival_time`, `status`, `failure_reason`, `reload_attempts`, `last_attempt_at`, `loaded_at` |
| [`file_ingestion_failure_log`](00_tables/002_file_ingestion_failure_log.sql) | One row per failed attempt | Failure history that is never overwritten: `file_id`, `attempt_number` (PK together), `failed_at`, `failure_reason` |

**Status values:** `arrived` (taken in, waiting for bronze) → `loaded` or `failed`; `unmatched` (no pipeline for the file name).

**`file_id`:** from the sequence `ingestion.file_id_sequence`. Intake reserves the next value, moves the file to `<file_id>_<name>`, then inserts the row, so a log row always points at where the file really is.
