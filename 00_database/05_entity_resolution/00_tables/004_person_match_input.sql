-- entity_resolution.person_match_input
-- One row per person transaction to be matched (every version), with one normalized value per match field.
-- email and company_id come from the person's primary affiliation in silver.person_company (latest versions):
-- a current one first, then the latest start date. company_id is the resolved company id (CMP-…).
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS entity_resolution.person_match_input (
    transaction_id VARCHAR(50) PRIMARY KEY,
    source_record_key VARCHAR(200) NOT NULL,
    source_record_version INTEGER NOT NULL,
    source_id INTEGER NOT NULL,  -- -> config.source
    arrival_time TIMESTAMPTZ NOT NULL,
    row_number INTEGER NOT NULL,
    first_name VARCHAR,
    last_name VARCHAR,
    linkedin VARCHAR,
    email VARCHAR,
    company_id VARCHAR(20),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
