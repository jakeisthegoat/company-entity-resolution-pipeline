-- Silver load, silver.person_company (from bronze.inbound_person_company_raw): step 01 of 05.
-- Stage the bronze rows not yet in silver, cleaned: trimmed, empty strings to NULL (lowercased where noted). Values stay text; the temp table `stg` lasts until the connection closes.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

CREATE OR REPLACE TEMP TABLE stg AS
SELECT
    b.transaction_id, b.file_id, b.row_number, b.row_hash, b.pipeline_id, b.source_id,
    l.arrival_time,
    NULLIF(trim(b."id"), '')             AS source_record_id,
    NULLIF(trim(b."personid"), '')       AS person_id,
    NULLIF(trim(b."companyid"), '')      AS company_id,
    NULLIF(trim(b."startdate"), '')      AS start_date,
    NULLIF(trim(b."enddate"), '')        AS end_date,
    lower(NULLIF(trim(b."email"), ''))   AS email,
    NULLIF(trim(b."emailconfirmed"), '') AS email_confirmed,
    NULLIF(trim(b."phone"), '')          AS phone,
    NULLIF(trim(b."title"), '')          AS title,
    NULLIF(trim(b."role"), '')           AS role,
    NULLIF(trim(b."deleted"), '')        AS deleted,
    NULLIF(trim(b."modifieddate"), '')   AS modified_date,
    NULLIF(trim(b."loaddate"), '')       AS load_date
FROM bronze.inbound_person_company_raw b
JOIN ingestion.file_ingestion_log l ON l.file_id = b.file_id
WHERE NOT EXISTS (SELECT 1 FROM silver.person_company s WHERE s.transaction_id = b.transaction_id);
