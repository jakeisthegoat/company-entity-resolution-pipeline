-- entity_resolution.company_master
-- Master id registry for companies: the only place a company id is defined (CMP-000001).
-- is_active = false once the id is retired (merged into another company by a review). Whether an id is
-- pending review is not stored here: it is derived from the review queue.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS entity_resolution.company_master (
    company_id VARCHAR(20) PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
