-- Silver load, silver.person (from bronze.inbound_person_raw): step 02 of 05.
-- Log values that cannot be cast to their column type. They become NULL in silver (step 04); the original value is kept in qc.silver_validation_warning.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.person', v.attribute_name, 'transformation_failure',
       'cast_to_attribute_type', v.value, 'cannot cast to ' || v.data_type
FROM stg s
CROSS JOIN LATERAL (VALUES
    ('deleted',       s.deleted,       'boolean',  TRY_CAST(s.deleted AS BOOLEAN) IS NOT NULL),
    ('modified_date', s.modified_date, 'date',     TRY_CAST(s.modified_date AS DATE) IS NOT NULL),
    ('load_date',     s.load_date,     'date',     TRY_CAST(s.load_date AS DATE) IS NOT NULL)
) AS v(attribute_name, value, data_type, is_castable)
WHERE v.value IS NOT NULL AND NOT v.is_castable
ON CONFLICT DO NOTHING;
