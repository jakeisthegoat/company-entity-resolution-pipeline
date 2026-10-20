-- Silver load, silver.account (from bronze.inbound_salesforce_account_raw): step 02 of 05.
-- Log values that cannot be cast to their column type. They become NULL in silver (step 04); the original value is kept in qc.silver_validation_warning.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.account', v.attribute_name, 'transformation_failure',
       'cast_to_attribute_type', v.value, 'cannot cast to ' || v.data_type
FROM stg s
CROSS JOIN LATERAL (VALUES
    ('ss_year_founded',     s.ss_year_founded,     'integer',  TRY_CAST(s.ss_year_founded AS INTEGER) IS NOT NULL),
    ('is_deleted',          s.is_deleted,          'boolean',  TRY_CAST(s.is_deleted AS BOOLEAN) IS NOT NULL),
    ('number_of_employees', s.number_of_employees, 'integer',  TRY_CAST(s.number_of_employees AS INTEGER) IS NOT NULL),
    ('created_date',        s.created_date,        'timestamp', TRY_CAST(s.created_date AS TIMESTAMP) IS NOT NULL)
) AS v(attribute_name, value, data_type, is_castable)
WHERE v.value IS NOT NULL AND NOT v.is_castable
ON CONFLICT DO NOTHING;
