-- Silver load, silver.account (from bronze.inbound_salesforce_account_raw): step 04 of 05.
-- Insert the staged rows, cast to their types (uncastable values become NULL), with source_record_key and source_record_version (continuing from the highest existing version).
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO silver.account (
    transaction_id, source_record_key, source_record_version, is_latest_version, is_changed_from_previous_version,
    row_hash, file_id, pipeline_id, source_id,
    source_record_id, name, billing_city, billing_state, billing_country, phone, website, domain,
    ss_company_name, ss_website, ss_city, ss_state, ss_phone, ss_year_founded,
    is_deleted, number_of_employees, created_date, account_source, pitchbook_id)
SELECT
    k.transaction_id, k.source_record_key,
    COALESCE((SELECT max(a.source_record_version) FROM silver.account a WHERE a.source_record_key = k.source_record_key), 0)
        + row_number() OVER (PARTITION BY k.source_record_key ORDER BY k.arrival_time, k.row_number),
    false, false,
    k.row_hash, k.file_id, k.pipeline_id, k.source_id,
    k.source_record_id, k.name, k.billing_city, k.billing_state, k.billing_country, k.phone, k.website, k.domain,
    k.ss_company_name, k.ss_website, k.ss_city, k.ss_state, k.ss_phone,
    TRY_CAST(k.ss_year_founded AS INTEGER),
    TRY_CAST(k.is_deleted AS BOOLEAN),
    TRY_CAST(k.number_of_employees AS INTEGER),
    TRY_CAST(k.created_date AS TIMESTAMP),
    k.account_source, k.pitchbook_id
FROM (
    SELECT stg.*, COALESCE(stg.source_id || '-' || stg.source_record_id, stg.transaction_id) AS source_record_key
    FROM stg
) k;
