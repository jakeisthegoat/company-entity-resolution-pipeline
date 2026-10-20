-- Fails on: a person or affiliation pointing to a company not in gold.company.
SELECT 'person' AS source, person_id, company_id FROM gold.person
 WHERE company_id IS NOT NULL AND company_id NOT IN (SELECT company_id FROM gold.company)
UNION ALL
SELECT 'person_company', person_id, company_id FROM gold.person_company
 WHERE company_id NOT IN (SELECT company_id FROM gold.company);
