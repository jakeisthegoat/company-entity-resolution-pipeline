-- Silver load, silver.person_company (from bronze.inbound_person_company_raw): step 04 of 05.
-- Insert the staged rows, cast to their types (uncastable values become NULL), with source_record_key and source_record_version (continuing from the highest existing version).
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO silver.person_company (
    transaction_id, source_record_key, source_record_version, is_latest_version, is_changed_from_previous_version,
    row_hash, file_id, pipeline_id, source_id,
    source_record_id, person_id, company_id, start_date, end_date, email, email_confirmed, phone, title, role,
    deleted, modified_date, load_date)
SELECT
    k.transaction_id, k.source_record_key,
    COALESCE((SELECT max(pc.source_record_version) FROM silver.person_company pc WHERE pc.source_record_key = k.source_record_key), 0)
        + row_number() OVER (PARTITION BY k.source_record_key ORDER BY k.arrival_time, k.row_number),
    false, false,
    k.row_hash, k.file_id, k.pipeline_id, k.source_id,
    k.source_record_id, k.person_id, k.company_id,
    TRY_CAST(k.start_date AS DATE),
    TRY_CAST(k.end_date AS DATE),
    k.email,
    TRY_CAST(k.email_confirmed AS BOOLEAN),
    k.phone, k.title,
    TRY_CAST(k.role AS INTEGER),
    TRY_CAST(k.deleted AS BOOLEAN),
    TRY_CAST(k.modified_date AS DATE),
    TRY_CAST(k.load_date AS DATE)
FROM (
    SELECT stg.*, COALESCE(stg.source_id || '-' || stg.source_record_id, stg.transaction_id) AS source_record_key
    FROM stg
) k;
