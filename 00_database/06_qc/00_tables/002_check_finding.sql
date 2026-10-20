-- qc.check_finding
-- One row per QC finding per run. Which check found it (and its type) is in config.qc_check.
-- Idempotent: CREATE SEQUENCE / CREATE TABLE IF NOT EXISTS.

CREATE SEQUENCE IF NOT EXISTS qc.check_finding_id_sequence;

CREATE TABLE IF NOT EXISTS qc.check_finding (
    check_finding_id BIGINT DEFAULT nextval('qc.check_finding_id_sequence') PRIMARY KEY,
    qc_check_id INTEGER NOT NULL,  -- -> config.qc_check
    run_at TIMESTAMPTZ NOT NULL,
    entity_type VARCHAR(20) CHECK (entity_type IN ('company', 'person')),
    entity_id VARCHAR(20),
    related_entity_id VARCHAR(20),
    transaction_id VARCHAR(50),
    detail TEXT,
    review_queue_id BIGINT
);
