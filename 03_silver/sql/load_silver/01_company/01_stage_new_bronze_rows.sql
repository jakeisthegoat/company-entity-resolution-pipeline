-- Silver load, silver.company (from bronze.inbound_company_raw): step 01 of 05.
-- Stage the bronze rows not yet in silver, cleaned: trimmed, empty strings to NULL (lowercased where noted). Values stay text; the temp table `stg` lasts until the connection closes.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

CREATE OR REPLACE TEMP TABLE stg AS
SELECT
    b.transaction_id, b.file_id, b.row_number, b.row_hash, b.pipeline_id, b.source_id,
    l.arrival_time,
    NULLIF(trim(b."id"), '')                  AS source_record_id,
    NULLIF(trim(b."name"), '')                AS name,
    NULLIF(trim(b."informalname"), '')        AS informal_name,
    NULLIF(trim(b."website"), '')             AS website,
    lower(NULLIF(trim(b."domain"), ''))       AS domain,
    NULLIF(trim(b."phonenumber"), '')         AS phone_number,
    NULLIF(trim(b."city"), '')                AS city,
    NULLIF(trim(b."state"), '')               AS state,
    NULLIF(trim(b."postalcode"), '')          AS postal_code,
    NULLIF(trim(b."country"), '')             AS country,
    NULLIF(trim(b."foundingyear"), '')        AS founding_year,
    NULLIF(trim(b."companytype"), '')         AS company_type,
    NULLIF(trim(b."parentid"), '')            AS parent_id,
    NULLIF(trim(b."parentcompany"), '')       AS parent_company,
    NULLIF(trim(b."totalamountinvested"), '') AS total_amount_invested,
    NULLIF(trim(b."nolongerinbusiness"), '')  AS no_longer_in_business,
    NULLIF(trim(b."modifieddate"), '')        AS modified_date
FROM bronze.inbound_company_raw b
JOIN ingestion.file_ingestion_log l ON l.file_id = b.file_id
WHERE NOT EXISTS (SELECT 1 FROM silver.company s WHERE s.transaction_id = b.transaction_id);
