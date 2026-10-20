-- Gold step 4: gold.person_company: every affiliation, one row per resolved person x resolved company.
-- Uses the temp table `affiliation` built in 002_build_affiliations.sql (same transaction).

INSERT INTO gold.person_company (
    person_id, company_id, title, email, email_confirmed, phone, role, start_date, end_date, is_current)
SELECT person_id, company_id, title, email, email_confirmed, phone, role, start_date, end_date, is_current
  FROM affiliation;
