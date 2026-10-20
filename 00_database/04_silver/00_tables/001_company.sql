-- silver.company
-- Part 1 provider companies (inbound_company), one row per transaction, every version kept.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS silver.company (
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
    name VARCHAR,
    informal_name VARCHAR,
    website VARCHAR,
    domain VARCHAR,
    phone_number VARCHAR,
    city VARCHAR,
    state VARCHAR,
    postal_code VARCHAR,
    country VARCHAR,
    founding_year INTEGER,
    company_type INTEGER,
    parent_id VARCHAR(100),
    parent_company VARCHAR,
    total_amount_invested BIGINT,
    no_longer_in_business BOOLEAN,
    modified_date TIMESTAMP,
    UNIQUE (source_record_key, source_record_version)
);
