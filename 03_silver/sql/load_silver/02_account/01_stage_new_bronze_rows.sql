-- Silver load, silver.account (from bronze.inbound_salesforce_account_raw): step 01 of 05.
-- Stage the bronze rows not yet in silver, cleaned: trimmed, empty strings to NULL (lowercased where noted). Values stay text; the temp table `stg` lasts until the connection closes.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

CREATE OR REPLACE TEMP TABLE stg AS
SELECT
    b.transaction_id, b.file_id, b.row_number, b.row_hash, b.pipeline_id, b.source_id,
    l.arrival_time,
    NULLIF(trim(b."id"), '')                  AS source_record_id,
    NULLIF(trim(b."name"), '')                AS name,
    NULLIF(trim(b."billingcity"), '')         AS billing_city,
    NULLIF(trim(b."billingstate"), '')        AS billing_state,
    NULLIF(trim(b."billingcountry"), '')      AS billing_country,
    NULLIF(trim(b."phone"), '')               AS phone,
    NULLIF(trim(b."website"), '')             AS website,
    lower(NULLIF(trim(b."domain__c"), ''))    AS domain,
    NULLIF(trim(b."ss_company_name__c"), '')  AS ss_company_name,
    NULLIF(trim(b."ss_website__c"), '')       AS ss_website,
    NULLIF(trim(b."ss_city__c"), '')          AS ss_city,
    NULLIF(trim(b."ss_state__c"), '')         AS ss_state,
    NULLIF(trim(b."ss_phone__c"), '')         AS ss_phone,
    NULLIF(trim(b."ss_year_founded__c"), '')  AS ss_year_founded,
    NULLIF(trim(b."isdeleted"), '')           AS is_deleted,
    NULLIF(trim(b."numberofemployees"), '')   AS number_of_employees,
    NULLIF(trim(b."createddate"), '')         AS created_date,
    NULLIF(trim(b."accountsource"), '')       AS account_source,
    NULLIF(trim(b."pitchbook_id__c"), '')     AS pitchbook_id
FROM bronze.inbound_salesforce_account_raw b
JOIN ingestion.file_ingestion_log l ON l.file_id = b.file_id
WHERE NOT EXISTS (SELECT 1 FROM silver.account s WHERE s.transaction_id = b.transaction_id);
