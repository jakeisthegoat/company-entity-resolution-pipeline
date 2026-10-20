-- Seed: config.pipeline
-- Explicit ids; upsert so a re-run brings existing rows up to date.

INSERT INTO config.pipeline (pipeline_id, pipeline_name, source_id, bronze_table_name, description, is_active)
VALUES
    (1, 'inbound_company',            1, 'bronze.inbound_company_raw',            'Provider companies (company.csv)', true),
    (2, 'inbound_person',             1, 'bronze.inbound_person_raw',             'Provider people (person.csv)', true),
    (3, 'inbound_person_company',     1, 'bronze.inbound_person_company_raw',     'Provider person-company links (persontocompany.csv)', true),
    (4, 'inbound_salesforce_account', 2, 'bronze.inbound_salesforce_account_raw', 'Salesforce accounts (account.csv)', true)
ON CONFLICT (pipeline_id) DO UPDATE SET
    pipeline_name     = EXCLUDED.pipeline_name,
    source_id         = EXCLUDED.source_id,
    bronze_table_name = EXCLUDED.bronze_table_name,
    description       = EXCLUDED.description,
    is_active         = EXCLUDED.is_active,
    updated_at        = now();
