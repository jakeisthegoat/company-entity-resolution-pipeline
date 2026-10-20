-- config.entity_resolution_order
-- Which sources take part in resolving each entity type, and in what order.
-- resolution_order 1 is the reference: its records are resolved first (among themselves); sources with a
-- higher order are then matched onto what is already resolved. A source with no row for an entity type takes
-- no part in resolving it (e.g. person-company links, or a pure lookup feed).
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.entity_resolution_order (
    entity_type VARCHAR(20) NOT NULL CHECK (entity_type IN ('company', 'person')),
    source_id INTEGER NOT NULL,  -- -> config.source
    resolution_order INTEGER NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (entity_type, source_id)
);
