-- Silver load, silver.person (from bronze.inbound_person_raw): step 01 of 05.
-- Stage the bronze rows not yet in silver, cleaned: trimmed, empty strings to NULL (lowercased where noted). Values stay text; the temp table `stg` lasts until the connection closes.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

CREATE OR REPLACE TEMP TABLE stg AS
SELECT
    b.transaction_id, b.file_id, b.row_number, b.row_hash, b.pipeline_id, b.source_id,
    l.arrival_time,
    NULLIF(trim(b."id"), '')           AS source_record_id,
    NULLIF(trim(b."firstname"), '')    AS first_name,
    NULLIF(trim(b."middlename"), '')   AS middle_name,
    NULLIF(trim(b."lastname"), '')     AS last_name,
    NULLIF(trim(b."linkedin"), '')     AS linkedin,
    NULLIF(trim(b."facebook"), '')     AS facebook,
    NULLIF(trim(b."twitter"), '')      AS twitter,
    NULLIF(trim(b."website"), '')      AS website,
    NULLIF(trim(b."city"), '')         AS city,
    NULLIF(trim(b."state"), '')        AS state,
    NULLIF(trim(b."country"), '')      AS country,
    NULLIF(trim(b."deleted"), '')      AS deleted,
    NULLIF(trim(b."statecode"), '')    AS state_code,
    NULLIF(trim(b."countrycode"), '')  AS country_code,
    NULLIF(trim(b."modifieddate"), '') AS modified_date,
    NULLIF(trim(b."loaddate"), '')     AS load_date
FROM bronze.inbound_person_raw b
JOIN ingestion.file_ingestion_log l ON l.file_id = b.file_id
WHERE NOT EXISTS (SELECT 1 FROM silver.person s WHERE s.transaction_id = b.transaction_id);
