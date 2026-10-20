-- Silver load, silver.company (from bronze.inbound_company_raw): step 02 of 05.
-- Log values that cannot be cast to their column type. They become NULL in silver (step 04); the original value is kept in qc.silver_validation_warning.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.company', v.attribute_name, 'transformation_failure',
       'cast_to_attribute_type', v.value, 'cannot cast to ' || v.data_type
FROM stg s
CROSS JOIN LATERAL (VALUES
    ('founding_year',         s.founding_year,         'integer',  TRY_CAST(s.founding_year AS INTEGER) IS NOT NULL),
    ('company_type',          s.company_type,          'integer',  TRY_CAST(s.company_type AS INTEGER) IS NOT NULL),
    ('total_amount_invested', s.total_amount_invested, 'bigint',   TRY_CAST(s.total_amount_invested AS BIGINT) IS NOT NULL),
    ('no_longer_in_business', s.no_longer_in_business, 'boolean',  TRY_CAST(s.no_longer_in_business AS BOOLEAN) IS NOT NULL),
    ('modified_date',         s.modified_date,         'timestamp', TRY_CAST(s.modified_date AS TIMESTAMP) IS NOT NULL)
) AS v(attribute_name, value, data_type, is_castable)
WHERE v.value IS NOT NULL AND NOT v.is_castable
ON CONFLICT DO NOTHING;
