-- ingestion.file_ingestion_failure_log
-- One row per failed load attempt; failure history is never overwritten.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS ingestion.file_ingestion_failure_log (
    file_id BIGINT NOT NULL,  -- -> ingestion.file_ingestion_log
    attempt_number INTEGER NOT NULL,
    failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    failure_reason TEXT NOT NULL,
    PRIMARY KEY (file_id, attempt_number)
);
