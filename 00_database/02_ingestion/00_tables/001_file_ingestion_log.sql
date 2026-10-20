-- ingestion.file_ingestion_log
-- One row per arriving file, always holding its latest state.
-- status: arrived (taken in, waiting for bronze), unmatched (no pipeline for its name), loaded, failed.
-- row_count: data rows in the file; filled in by the bronze load, which is the only step that reads the file.
-- Idempotent: CREATE SEQUENCE / CREATE TABLE IF NOT EXISTS.

CREATE SEQUENCE IF NOT EXISTS ingestion.file_id_sequence;

CREATE TABLE IF NOT EXISTS ingestion.file_ingestion_log (
    file_id BIGINT DEFAULT nextval('ingestion.file_id_sequence') PRIMARY KEY,
    pipeline_id INTEGER,  -- -> config.pipeline
    original_file_name VARCHAR(500) NOT NULL,
    file_path VARCHAR(1000),
    file_size BIGINT,
    row_count BIGINT,
    arrival_time TIMESTAMPTZ NOT NULL DEFAULT now(),
    status VARCHAR(20) NOT NULL DEFAULT 'arrived' CHECK (status IN ('arrived', 'unmatched', 'loaded', 'failed')),
    failure_reason TEXT,
    reload_attempts INTEGER NOT NULL DEFAULT 0,
    last_attempt_at TIMESTAMPTZ,
    loaded_at TIMESTAMPTZ
);
