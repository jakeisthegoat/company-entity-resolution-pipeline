-- Fails on: a NULL or duplicated company_id in gold.company.
SELECT company_id, count(*) FROM gold.company GROUP BY company_id HAVING company_id IS NULL OR count(*) > 1;
