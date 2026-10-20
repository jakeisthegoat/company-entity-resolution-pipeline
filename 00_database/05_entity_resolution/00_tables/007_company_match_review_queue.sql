-- entity_resolution.company_match_review_queue
-- Top 3 candidate matches for each company transaction sent to manual review.
-- Idempotent: CREATE SEQUENCE / CREATE TABLE IF NOT EXISTS.

CREATE SEQUENCE IF NOT EXISTS entity_resolution.company_match_review_queue_id_sequence;

CREATE TABLE IF NOT EXISTS entity_resolution.company_match_review_queue (
    company_match_review_queue_id BIGINT DEFAULT nextval('entity_resolution.company_match_review_queue_id_sequence') PRIMARY KEY,
    transaction_id VARCHAR(50) NOT NULL,  -- -> entity_resolution.company_match_input
    candidate_company_id VARCHAR(20) NOT NULL,  -- -> entity_resolution.company_master
    candidate_transaction_id VARCHAR(50),
    candidate_rank SMALLINT NOT NULL CHECK (candidate_rank BETWEEN 1 AND 3),
    match_score NUMERIC(5,2) NOT NULL,
    match_basis VARCHAR(500),
    review_status VARCHAR(20) NOT NULL DEFAULT 'pending' CHECK (review_status IN ('pending', 'confirmed_match', 'confirmed_new')),
    reviewer VARCHAR(100),
    reviewed_at TIMESTAMPTZ,
    review_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (transaction_id, candidate_rank)
);
