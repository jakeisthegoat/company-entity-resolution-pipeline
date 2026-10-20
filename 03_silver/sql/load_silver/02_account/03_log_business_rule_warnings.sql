-- Silver load, silver.account (from bronze.inbound_salesforce_account_raw): step 03 of 05.
-- Log this table's business-rule warnings (from: required, valid_year, non_negative, valid_email, valid_phone). Warnings only: the value is kept.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.account', v.attribute_name, 'business_rule_warning',
       v.rule_name, v.value, v.reason
FROM stg s
CROSS JOIN LATERAL (VALUES
    ('source_record_id', 'required', s.source_record_id,
        s.source_record_id IS NOT NULL, 'value is missing'),
    ('ss_year_founded', 'valid_year', s.ss_year_founded,
        s.ss_year_founded IS NULL OR regexp_matches(s.ss_year_founded, '^[0-9]{4}$'), 'not a 4-digit year'),
    ('number_of_employees', 'non_negative', s.number_of_employees,
        coalesce(TRY_CAST(s.number_of_employees AS NUMERIC) >= 0, true), 'negative value'),
    ('phone', 'valid_phone', s.phone,
        s.phone IS NULL OR regexp_matches(regexp_replace(s.phone, '\D', '', 'g'), '^1?[0-9]{10}$'), 'not 10 digits (or 11 with a leading 1)'),
    ('ss_phone', 'valid_phone', s.ss_phone,
        s.ss_phone IS NULL OR regexp_matches(regexp_replace(s.ss_phone, '\D', '', 'g'), '^1?[0-9]{10}$'), 'not 10 digits (or 11 with a leading 1)')
) AS v(attribute_name, rule_name, value, passed, reason)
WHERE NOT v.passed
ON CONFLICT DO NOTHING;
