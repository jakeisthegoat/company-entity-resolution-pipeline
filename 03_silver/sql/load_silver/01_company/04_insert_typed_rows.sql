-- Silver load, silver.company (from bronze.inbound_company_raw): step 04 of 05.
-- Insert the staged rows, cast to their types (uncastable values become NULL), with source_record_key and source_record_version (continuing from the highest existing version).
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

INSERT INTO silver.company (
    transaction_id, source_record_key, source_record_version, is_latest_version, is_changed_from_previous_version,
    row_hash, file_id, pipeline_id, source_id,
    source_record_id, name, informal_name, website, domain, phone_number, city, state, postal_code, country,
    founding_year, company_type, parent_id, parent_company, total_amount_invested, no_longer_in_business, modified_date)
SELECT
    k.transaction_id, k.source_record_key,
    COALESCE((SELECT max(c.source_record_version) FROM silver.company c WHERE c.source_record_key = k.source_record_key), 0)
        + row_number() OVER (PARTITION BY k.source_record_key ORDER BY k.arrival_time, k.row_number),
    false, false,
    k.row_hash, k.file_id, k.pipeline_id, k.source_id,
    k.source_record_id, k.name, k.informal_name, k.website, k.domain, k.phone_number, k.city, k.state, k.postal_code, k.country,
    TRY_CAST(k.founding_year AS INTEGER),
    TRY_CAST(k.company_type AS INTEGER),
    k.parent_id, k.parent_company,
    TRY_CAST(k.total_amount_invested AS BIGINT),
    TRY_CAST(k.no_longer_in_business AS BOOLEAN),
    TRY_CAST(k.modified_date AS TIMESTAMP)
FROM (
    SELECT stg.*, COALESCE(stg.source_id || '-' || stg.source_record_id, stg.transaction_id) AS source_record_key
    FROM stg
) k;
