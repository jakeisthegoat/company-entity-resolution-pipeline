-- Silver load, silver.person_company (from bronze.inbound_person_company_raw): step 03 of 05.
-- Log this table's business-rule warnings (from: required, valid_year, non_negative, valid_email, valid_phone). Warnings only: the value is kept.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.person_company', v.attribute_name, 'business_rule_warning',
       v.rule_name, v.value, v.reason
FROM stg s
CROSS JOIN LATERAL (VALUES
    ('source_record_id', 'required', s.source_record_id, s.source_record_id IS NOT NULL, 'value is missing'),
    ('person_id',        'required', s.person_id,        s.person_id IS NOT NULL,        'value is missing'),
    ('company_id',       'required', s.company_id,       s.company_id IS NOT NULL,       'value is missing'),
    ('email', 'valid_email', s.email,
        s.email IS NULL OR regexp_matches(s.email, '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'), 'not an x@y.z address'),
    ('phone', 'valid_phone', s.phone,
        s.phone IS NULL OR regexp_matches(regexp_replace(s.phone, '\D', '', 'g'), '^1?[0-9]{10}$'), 'not 10 digits (or 11 with a leading 1)')
) AS v(attribute_name, rule_name, value, passed, reason)
WHERE NOT v.passed
ON CONFLICT DO NOTHING;
