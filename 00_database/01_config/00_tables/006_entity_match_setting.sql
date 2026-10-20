-- config.entity_match_setting
-- One row per entity type: its master id prefix and the matching bands. Read by the matching engine at the start
-- of every run, so tuning a threshold is a seed change, not code.
--   score >= auto_match_threshold (with an agreeing strong identifier) -> auto-match
--   score >= review_threshold                                          -> manual review (review_candidates kept)
--   below review_threshold                                             -> new id
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.entity_match_setting (
    entity_type VARCHAR(20) PRIMARY KEY CHECK (entity_type IN ('company', 'person')),
    id_prefix VARCHAR(10) NOT NULL UNIQUE,
    auto_match_threshold NUMERIC(5,2) NOT NULL CHECK (auto_match_threshold BETWEEN 0 AND 100),
    review_threshold NUMERIC(5,2) NOT NULL CHECK (review_threshold BETWEEN 0 AND 100),
    review_candidates SMALLINT NOT NULL CHECK (review_candidates BETWEEN 1 AND 3),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (review_threshold < auto_match_threshold)
);
