-- entity_resolution.company_match_result
-- The mastering output: one current decision per company transaction.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS entity_resolution.company_match_result (
    transaction_id VARCHAR(50) PRIMARY KEY,  -- -> entity_resolution.company_match_input
    company_id VARCHAR(20) NOT NULL,  -- -> entity_resolution.company_master
    match_score NUMERIC(5,2) NOT NULL CHECK (match_score BETWEEN 0 AND 100),
    match_band VARCHAR(20) NOT NULL CHECK (match_band IN ('exact', 'auto_match', 'review', 'new')),
    match_basis VARCHAR(500),
    matched_transaction_id VARCHAR(50),
    decided_by VARCHAR(100) NOT NULL DEFAULT 'system',
    decided_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
