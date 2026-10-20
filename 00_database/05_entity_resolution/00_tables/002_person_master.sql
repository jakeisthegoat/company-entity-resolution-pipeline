-- entity_resolution.person_master
-- Master id registry for people: the only place a person id is defined (PER-000001).
-- is_active = false once the id is retired (merged into another person by a review). Whether an id is
-- pending review is not stored here: it is derived from the review queue.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS entity_resolution.person_master (
    person_id VARCHAR(20) PRIMARY KEY,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
