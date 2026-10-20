-- Seed: config.source
-- Explicit ids; upsert so a re-run brings existing rows up to date.

INSERT INTO config.source (source_id, source_name, description, is_active)
VALUES
    (1, 'part1_company', 'Third-party data provider feed (company, person, persontocompany)', true),
    (2, 'salesforce',    'Salesforce Account export', true)
ON CONFLICT (source_id) DO UPDATE SET
    source_name           = EXCLUDED.source_name,
    description           = EXCLUDED.description,
    is_active             = EXCLUDED.is_active,
    updated_at            = now();
