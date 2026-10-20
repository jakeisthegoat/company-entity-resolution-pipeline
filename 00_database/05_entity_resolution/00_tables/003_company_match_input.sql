-- entity_resolution.company_match_input
-- One row per company transaction to be matched (every version), with one normalized value per match field,
-- taken from the core fields only (provider: name, domain, phone_number, city, state; Salesforce: name, domain,
-- phone, billing_city, billing_state). Salesforce ss_* fields are not matched on; they stay in silver for QC.
-- Values are match-only normalization (lowercase, no punctuation, bare domain, last 10 phone digits) and are
-- never written back to silver.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS entity_resolution.company_match_input (
    transaction_id VARCHAR(50) PRIMARY KEY,
    source_record_key VARCHAR(200) NOT NULL,
    source_record_version INTEGER NOT NULL,
    source_id INTEGER NOT NULL,  -- -> config.source
    arrival_time TIMESTAMPTZ NOT NULL,
    row_number INTEGER NOT NULL,
    name VARCHAR,
    domain VARCHAR,
    phone VARCHAR(10),
    city VARCHAR,
    state VARCHAR,
    parent_record_key VARCHAR(200),  -- not scored: feeds the parent/subsidiary rule
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
