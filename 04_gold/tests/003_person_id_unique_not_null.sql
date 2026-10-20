-- Fails on: a NULL or duplicated person_id in gold.person.
SELECT person_id, count(*) FROM gold.person GROUP BY person_id HAVING person_id IS NULL OR count(*) > 1;
