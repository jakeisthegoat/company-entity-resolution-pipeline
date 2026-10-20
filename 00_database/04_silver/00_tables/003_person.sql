-- silver.person
-- Part 1 people (inbound_person), every documented column, including those empty in this extract.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS silver.person (
    transaction_id VARCHAR(50) PRIMARY KEY,
    source_record_key VARCHAR(200) NOT NULL,
    source_record_version INTEGER NOT NULL,
    is_latest_version BOOLEAN NOT NULL,
    is_changed_from_previous_version BOOLEAN NOT NULL,
    row_hash CHAR(64) NOT NULL,
    file_id BIGINT NOT NULL,  -- -> ingestion.file_ingestion_log
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    source_id INTEGER NOT NULL,  -- -> config.source
    loaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    source_record_id VARCHAR(100),
    first_name VARCHAR,
    middle_name VARCHAR,
    last_name VARCHAR,
    linkedin VARCHAR,
    facebook VARCHAR,
    twitter VARCHAR,
    website VARCHAR,
    city VARCHAR,
    state VARCHAR,
    country VARCHAR,
    deleted BOOLEAN,
    state_code VARCHAR,
    country_code VARCHAR,
    modified_date DATE,
    load_date DATE,
    UNIQUE (source_record_key, source_record_version)
);
