-- qc.silver_validation_warning
-- Silver load issues: transformation failures (value NULLed) and business-rule warnings (value kept). Never blocks a load.
-- Idempotent: CREATE SEQUENCE / CREATE TABLE IF NOT EXISTS.

CREATE SEQUENCE IF NOT EXISTS qc.silver_validation_warning_id_sequence;

CREATE TABLE IF NOT EXISTS qc.silver_validation_warning (
    silver_validation_warning_id BIGINT DEFAULT nextval('qc.silver_validation_warning_id_sequence') PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL,
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    silver_table_name VARCHAR(100) NOT NULL,
    attribute_name VARCHAR(100) NOT NULL,
    failure_type VARCHAR(30) NOT NULL CHECK (failure_type IN ('transformation_failure', 'business_rule_warning')),
    rule_name VARCHAR(100) NOT NULL,
    original_value TEXT,
    failure_reason TEXT,
    failed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (transaction_id, attribute_name, rule_name)
);
