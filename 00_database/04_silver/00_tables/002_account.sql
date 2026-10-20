-- silver.account
-- Salesforce accounts (inbound_salesforce_account), the 19 documented columns. Core and ss_* fields kept separately.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS silver.account (
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
    billing_city VARCHAR,
    billing_state VARCHAR,
    billing_country VARCHAR,
    phone VARCHAR,
    website VARCHAR,
    domain VARCHAR,
    ss_company_name VARCHAR,
    ss_website VARCHAR,
    ss_city VARCHAR,
    ss_state VARCHAR,
    ss_phone VARCHAR,
    ss_year_founded INTEGER,
    is_deleted BOOLEAN,
    number_of_employees INTEGER,
    created_date TIMESTAMP,
    account_source VARCHAR,
    pitchbook_id VARCHAR,
    UNIQUE (source_record_key, source_record_version)
);
