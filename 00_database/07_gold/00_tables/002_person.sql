-- gold.person
-- Final people table: one row per resolved person, with their primary affiliation (full refresh).
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS gold.person (
    person_id VARCHAR(20) PRIMARY KEY,
    first_name VARCHAR,
    middle_name VARCHAR,
    last_name VARCHAR,
    linkedin VARCHAR,
    city VARCHAR,
    state VARCHAR,
    country VARCHAR,
    company_id VARCHAR(20),  -- -> gold.company
    title VARCHAR,
    email VARCHAR,
    phone VARCHAR,
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN,
    affiliation_count INTEGER NOT NULL,
    is_pending_review BOOLEAN NOT NULL
);
