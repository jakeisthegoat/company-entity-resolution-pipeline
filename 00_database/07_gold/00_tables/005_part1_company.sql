-- gold.part1_company (view)
-- The Part 1 companies table: the companies in gold.company that have at least one Part 1 (provider) record.
-- Salesforce-only companies are left out. Columns are the same as gold.company.
-- Idempotent: CREATE OR REPLACE.

CREATE OR REPLACE VIEW gold.part1_company AS
SELECT c.*
  FROM gold.company c
 WHERE c.company_id IN (SELECT crosswalk_id FROM gold.crosswalk WHERE source_system = 'part1_company');
