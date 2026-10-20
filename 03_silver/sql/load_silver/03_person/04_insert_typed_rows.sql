-- Silver load, silver.person (from bronze.inbound_person_raw): step 04 of 05.
-- Insert the staged rows, cast to their types (uncastable values become NULL), with source_record_key and source_record_version (continuing from the highest existing version).
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO silver.person (
    transaction_id, source_record_key, source_record_version, is_latest_version, is_changed_from_previous_version,
    row_hash, file_id, pipeline_id, source_id,
    source_record_id, first_name, middle_name, last_name, linkedin, facebook, twitter, website,
    city, state, country, deleted, state_code, country_code, modified_date, load_date)
SELECT
    k.transaction_id, k.source_record_key,
    COALESCE((SELECT max(p.source_record_version) FROM silver.person p WHERE p.source_record_key = k.source_record_key), 0)
        + row_number() OVER (PARTITION BY k.source_record_key ORDER BY k.arrival_time, k.row_number),
    false, false,
    k.row_hash, k.file_id, k.pipeline_id, k.source_id,
    k.source_record_id, k.first_name, k.middle_name, k.last_name, k.linkedin, k.facebook, k.twitter, k.website,
    k.city, k.state, k.country,
    TRY_CAST(k.deleted AS BOOLEAN),
    k.state_code, k.country_code,
    TRY_CAST(k.modified_date AS DATE),
    TRY_CAST(k.load_date AS DATE)
FROM (
    SELECT stg.*, COALESCE(stg.source_id || '-' || stg.source_record_id, stg.transaction_id) AS source_record_key
    FROM stg
) k;
