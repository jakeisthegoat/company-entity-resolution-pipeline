-- Silver load, silver.person_company (from bronze.inbound_person_company_raw): step 05 of 05.
-- Refresh is_latest_version and is_changed_from_previous_version for every source record touched by this load.
-- The steps in this folder run in order, in one transaction (03_silver/load_silver.py).

UPDATE silver.person_company pc
   SET is_latest_version = (pc.source_record_version = f.max_version),
       is_changed_from_previous_version = (f.previous_hash IS NULL OR f.previous_hash <> pc.row_hash)
  FROM (
    SELECT transaction_id,
           max(source_record_version) OVER (PARTITION BY source_record_key) AS max_version,
           lag(row_hash) OVER (PARTITION BY source_record_key ORDER BY source_record_version) AS previous_hash
      FROM silver.person_company
     WHERE source_record_key IN (SELECT COALESCE(source_id || '-' || source_record_id, transaction_id) FROM stg)
  ) f
 WHERE pc.transaction_id = f.transaction_id;
