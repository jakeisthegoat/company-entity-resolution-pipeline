-- gold.data_quality_summary (view)
-- The data-quality summary, recomputed from the current tables every time it is queried:
--   companies, people, links: raw rows in, final rows out, and how many are pending review;
--   one row per QC check with its number of findings in the latest run (over-merge, under-merge and other checks).
-- Read it with: SELECT * FROM gold.data_quality_summary ORDER BY line;
-- Idempotent: CREATE OR REPLACE.

CREATE OR REPLACE VIEW gold.data_quality_summary AS
WITH latest_qc AS (
    SELECT qc_check_id, count(*) AS findings
      FROM qc.check_finding
     WHERE run_at = (SELECT max(run_at) FROM qc.check_finding)
     GROUP BY qc_check_id
)
SELECT 1 AS line, 'companies' AS category, 'Raw Part 1 company rows' AS metric,
       (SELECT count(*) FROM gold.crosswalk WHERE source_system = 'part1_company') AS value
UNION ALL
SELECT 2, 'companies', 'Final Part 1 companies',
       (SELECT count(*) FROM gold.part1_company)
UNION ALL
SELECT 3, 'companies', 'Raw rows merged into another company',
       (SELECT count(*) FROM gold.crosswalk WHERE source_system = 'part1_company') - (SELECT count(*) FROM gold.part1_company)
UNION ALL
SELECT 4, 'companies', 'Part 1 companies pending review',
       (SELECT count(*) FROM gold.part1_company WHERE is_pending_review)
UNION ALL
SELECT 5, 'people', 'Raw person rows',
       (SELECT count(*) FROM silver.person WHERE is_latest_version)
UNION ALL
SELECT 6, 'people', 'Final people',
       (SELECT count(*) FROM gold.person)
UNION ALL
SELECT 7, 'people', 'People pending review',
       (SELECT count(*) FROM gold.person WHERE is_pending_review)
UNION ALL
SELECT 8, 'person_company', 'Raw person-company links',
       (SELECT count(*) FROM silver.person_company WHERE is_latest_version)
UNION ALL
SELECT 9, 'person_company', 'Final person-company links',
       (SELECT count(*) FROM gold.person_company)
UNION ALL
SELECT 10, 'person_company', 'Duplicate links collapsed',
       (SELECT count(*) FROM silver.person_company WHERE is_latest_version) - (SELECT count(*) FROM gold.person_company)
UNION ALL
SELECT 10 + c.qc_check_id, c.check_type, 'QC ' || c.check_name, coalesce(f.findings, 0)
  FROM config.qc_check c
  LEFT JOIN latest_qc f ON f.qc_check_id = c.qc_check_id
 WHERE c.is_active;
