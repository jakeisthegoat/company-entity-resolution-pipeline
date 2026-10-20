-- gold.crosswalk
-- The Part 2 crosswalk: one row per company source record (latest version), covering both sources completely,
-- every raw Part 1 company id and every Salesforce account. A company that was two raw rows has two rows here.
-- crosswalk_id is the company's master id, shared by every source record of the same real-world company.
-- match_confidence / match_basis are filled only when the company is present in both systems; needs_review flags
-- companies with a pending review. A third source is new rows with a new source_system value: no schema change.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS gold.crosswalk (
    crosswalk_id VARCHAR(20) NOT NULL,  -- -> gold.company
    source_system VARCHAR(100) NOT NULL,
    source_record_id VARCHAR(100) NOT NULL,
    source_name VARCHAR,
    presence VARCHAR(20) NOT NULL CHECK (presence IN ('both', 'part1_only', 'salesforce_only')),
    match_confidence NUMERIC(5,2) CHECK (match_confidence BETWEEN 0 AND 100),
    match_basis VARCHAR(500),
    needs_review BOOLEAN NOT NULL,
    PRIMARY KEY (source_system, source_record_id)
);
