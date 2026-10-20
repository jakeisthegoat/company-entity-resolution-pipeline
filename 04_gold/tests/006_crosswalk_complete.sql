-- Fails on: a current company source record (every raw Part 1 company id and every Salesforce account) missing
-- from the crosswalk, a crosswalk row that is not a current company source record, or the counts not matching
-- the raw inputs (1 row per provider company id, 1 row per account id).
WITH expected AS (
    SELECT s.source_name AS source_system, coalesce(c.source_record_id, a.source_record_id) AS source_record_id
      FROM entity_resolution.company_alias cm
      JOIN config.source s ON s.source_id = cm.source_id
      LEFT JOIN silver.company c USING (transaction_id) LEFT JOIN silver.account a USING (transaction_id)
)
SELECT 'missing or extra' AS problem, e.source_system, e.source_record_id
  FROM expected e
  FULL JOIN gold.crosswalk x USING (source_system, source_record_id)
 WHERE e.source_record_id IS NULL OR x.crosswalk_id IS NULL
UNION ALL
SELECT 'count differs from raw input', 'part1_company', NULL
 WHERE (SELECT count(*) FROM gold.crosswalk WHERE source_system = 'part1_company')
    <> (SELECT count(DISTINCT source_record_key) FROM silver.company)
UNION ALL
SELECT 'count differs from raw input', 'salesforce', NULL
 WHERE (SELECT count(*) FROM gold.crosswalk WHERE source_system = 'salesforce')
    <> (SELECT count(DISTINCT source_record_key) FROM silver.account);
