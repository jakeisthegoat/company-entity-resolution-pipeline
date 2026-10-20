-- Seed: config.entity_match_setting
-- Bands calibrated on the assessment data (see 03_silver/docs/Entity-Resolution-Design.md). Upsert by entity_type.

INSERT INTO config.entity_match_setting (entity_type, id_prefix, auto_match_threshold, review_threshold, review_candidates)
VALUES
    ('company', 'CMP', 90, 70, 3),
    ('person',  'PER', 90, 70, 3)
ON CONFLICT (entity_type) DO UPDATE SET
    id_prefix            = EXCLUDED.id_prefix,
    auto_match_threshold = EXCLUDED.auto_match_threshold,
    review_threshold     = EXCLUDED.review_threshold,
    review_candidates    = EXCLUDED.review_candidates,
    updated_at           = now();
