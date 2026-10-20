-- config.pipeline_file_pattern
-- Routes an arriving file (by original file name, glob pattern) to its pipeline.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.pipeline_file_pattern (
    pipeline_file_pattern_id INTEGER PRIMARY KEY,
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    file_pattern VARCHAR(200) NOT NULL UNIQUE,
    description TEXT,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
