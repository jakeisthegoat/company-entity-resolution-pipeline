-- gold.person_company
-- All affiliations, one row per resolved person x resolved company (full refresh).
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS gold.person_company (
    person_id VARCHAR(20) NOT NULL,  -- -> gold.person
    company_id VARCHAR(20) NOT NULL,  -- -> gold.company
    title VARCHAR,
    email VARCHAR,
    email_confirmed BOOLEAN,
    phone VARCHAR,
    role INTEGER,
    start_date DATE,
    end_date DATE,
    is_current BOOLEAN NOT NULL,
    PRIMARY KEY (person_id, company_id)
);
