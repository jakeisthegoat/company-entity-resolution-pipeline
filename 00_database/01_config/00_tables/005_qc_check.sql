-- config.qc_check
-- One row per QC check. check_sql is the literal query QC runs: it returns the rows that break the rule, as
-- (entity_type, entity_id, related_entity_id, transaction_id, detail). creates_review = true opens a review queue
-- entry for the finding's transaction. Adding, changing or switching off a check is a seed change, not code.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.qc_check (
    qc_check_id INTEGER PRIMARY KEY,
    check_name VARCHAR(100) NOT NULL UNIQUE,
    check_type VARCHAR(30) NOT NULL CHECK (check_type IN ('over_merge', 'under_merge', 'cross_attribute', 'integrity')),
    creates_review BOOLEAN NOT NULL,
    description TEXT NOT NULL,
    check_sql TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
