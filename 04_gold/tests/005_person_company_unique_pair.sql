-- Fails on: more than one row for the same person x company.
SELECT person_id, company_id, count(*) FROM gold.person_company GROUP BY 1, 2 HAVING count(*) > 1;
