-- silver.person_company
-- Part 1 person-company links (inbound_person_company), one per source link id; pairs are de-duplicated in gold.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS silver.person_company (
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
    person_id VARCHAR(100),
    company_id VARCHAR(100),
    start_date DATE,
    end_date DATE,
    email VARCHAR,
    email_confirmed BOOLEAN,
    phone VARCHAR,
    title VARCHAR,
    role INTEGER,
    deleted BOOLEAN,
    modified_date DATE,
    load_date DATE,
    UNIQUE (source_record_key, source_record_version)
);
