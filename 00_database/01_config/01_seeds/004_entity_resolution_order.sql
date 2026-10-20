-- Seed: config.entity_resolution_order
-- Companies: the provider feed (Part 1) is the reference and is resolved first; Salesforce accounts are then
-- matched onto the resolved Part 1 companies. People: only the provider feed.
-- Explicit keys; upsert so a re-run brings existing rows up to date.

INSERT INTO config.entity_resolution_order (entity_type, source_id, resolution_order, is_active)
VALUES
    ('company', 1, 1, true),   -- part1_company: reference
    ('company', 2, 2, true),   -- salesforce: matched onto Part 1
    ('person',  1, 1, true)    -- part1_company
ON CONFLICT (entity_type, source_id) DO UPDATE SET
    resolution_order = EXCLUDED.resolution_order,
    is_active        = EXCLUDED.is_active,
    updated_at       = now();
