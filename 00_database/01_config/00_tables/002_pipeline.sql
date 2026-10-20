-- config.pipeline
-- One row per pipeline. Each source has its own pipelines.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.pipeline (
    pipeline_id INTEGER PRIMARY KEY,
    pipeline_name VARCHAR(100) NOT NULL UNIQUE,
    source_id INTEGER NOT NULL,  -- -> config.source
    bronze_table_name VARCHAR(200) NOT NULL,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
