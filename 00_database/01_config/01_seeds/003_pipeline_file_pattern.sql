-- Seed: config.pipeline_file_pattern
-- Glob patterns matched against the ORIGINAL file name. A file must match exactly one active pattern.
-- `person.csv` is exact on purpose: `person*.csv` would also match persontocompany.csv.
-- Explicit ids; upsert so a re-run brings existing rows up to date.

INSERT INTO config.pipeline_file_pattern (pipeline_file_pattern_id, pipeline_id, file_pattern, description, is_active)
VALUES
    (1, 1, 'company*.csv',         'Provider company files', true),
    (2, 2, 'person.csv',           'Provider person file', true),
    (3, 3, 'persontocompany*.csv', 'Provider person-company link files', true),
    (4, 4, 'account*.csv',         'Salesforce account exports', true)
ON CONFLICT (pipeline_file_pattern_id) DO UPDATE SET
    pipeline_id  = EXCLUDED.pipeline_id,
    file_pattern = EXCLUDED.file_pattern,
    description  = EXCLUDED.description,
    is_active    = EXCLUDED.is_active,
    updated_at   = now();
