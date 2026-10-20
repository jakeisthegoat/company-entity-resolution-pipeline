-- gold.company
-- Final companies table: one row per resolved company (full refresh).
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS gold.company (
    company_id VARCHAR(20) PRIMARY KEY,
    company_name VARCHAR,
    informal_name VARCHAR,
    website VARCHAR,
    domain VARCHAR,
    phone VARCHAR,
    city VARCHAR,
    state VARCHAR,
    postal_code VARCHAR,
    country VARCHAR,
    founding_year INTEGER,
    total_amount_invested BIGINT,
    parent_company_id VARCHAR(20),
    parent_company_name VARCHAR,
    source_record_count INTEGER NOT NULL,
    sources_present VARCHAR(200) NOT NULL,
    is_pending_review BOOLEAN NOT NULL
);
