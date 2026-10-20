-- Silver load, silver.person (from bronze.inbound_person_raw): step 03 of 05.
-- Log this table's business-rule warnings (from: required, valid_year, non_negative, valid_email, valid_phone). Warnings only: the value is kept.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO qc.silver_validation_warning
    (transaction_id, pipeline_id, silver_table_name, attribute_name, failure_type, rule_name, original_value, failure_reason)
SELECT s.transaction_id, s.pipeline_id, 'silver.person', 'source_record_id', 'business_rule_warning',
       'required', s.source_record_id, 'value is missing'
FROM stg s
WHERE s.source_record_id IS NULL
ON CONFLICT DO NOTHING;
