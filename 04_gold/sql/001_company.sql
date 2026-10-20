-- Gold step 1: gold.company: one row per resolved company, from the current members (latest version of each source record).
--
-- Survivorship: each company's records are ranked once (survivor_rank): source resolution order first (Part 1
-- before Salesforce), then most recent arrival. Each attribute takes the first non-null value in that rank, so
-- Part 1 values win and Salesforce fills gaps. The address is taken as a group from the best-ranked record that
-- has one, so a company never gets a city from one record and a state from another.

INSERT INTO gold.company (
    company_id, company_name, informal_name, website, domain, phone, city, state, postal_code, country,
    founding_year, total_amount_invested, parent_company_id, parent_company_name,
    source_record_count, sources_present, is_pending_review)
WITH member AS (
    -- Provider companies
    SELECT cm.company_id, cm.transaction_id, s.source_name, coalesce(ero.resolution_order, 999) AS priority,
           i.arrival_time, i.row_number,
           c.name AS company_name, c.informal_name, c.website, c.domain, c.phone_number AS phone,
           c.city, c.state, c.postal_code, c.country, c.founding_year, c.total_amount_invested,
           c.parent_company AS parent_company_name,
           CASE WHEN c.parent_id IS NOT NULL THEN c.source_id || '-' || c.parent_id END AS parent_source_record_key
      FROM entity_resolution.company_alias cm
      JOIN entity_resolution.company_match_input i USING (transaction_id)
      JOIN config.source s ON s.source_id = cm.source_id
      LEFT JOIN config.entity_resolution_order ero ON ero.entity_type = 'company' AND ero.source_id = cm.source_id
      JOIN silver.company c USING (transaction_id)
    UNION ALL
    -- Salesforce accounts (core fields; ss_* stay in silver for QC only)
    SELECT cm.company_id, cm.transaction_id, s.source_name, coalesce(ero.resolution_order, 999),
           i.arrival_time, i.row_number,
           a.name, NULL, a.website, a.domain, a.phone,
           a.billing_city, a.billing_state, NULL, a.billing_country, a.ss_year_founded, NULL,
           NULL, NULL
      FROM entity_resolution.company_alias cm
      JOIN entity_resolution.company_match_input i USING (transaction_id)
      JOIN config.source s ON s.source_id = cm.source_id
      LEFT JOIN config.entity_resolution_order ero ON ero.entity_type = 'company' AND ero.source_id = cm.source_id
      JOIN silver.account a USING (transaction_id)
), ranked AS (
    SELECT member.*,
           row_number() OVER (PARTITION BY company_id ORDER BY priority, arrival_time DESC, row_number DESC) AS survivor_rank
      FROM member
), best AS (
    SELECT company_id,
           first(company_name          ORDER BY survivor_rank) FILTER (WHERE company_name IS NOT NULL)          AS company_name,
           first(informal_name         ORDER BY survivor_rank) FILTER (WHERE informal_name IS NOT NULL)         AS informal_name,
           first(website               ORDER BY survivor_rank) FILTER (WHERE website IS NOT NULL)               AS website,
           first(domain                ORDER BY survivor_rank) FILTER (WHERE domain IS NOT NULL)                AS domain,
           first(phone                 ORDER BY survivor_rank) FILTER (WHERE phone IS NOT NULL)                 AS phone,
           first(founding_year         ORDER BY survivor_rank) FILTER (WHERE founding_year IS NOT NULL)         AS founding_year,
           first(total_amount_invested ORDER BY survivor_rank) FILTER (WHERE total_amount_invested IS NOT NULL) AS total_amount_invested,
           first(parent_company_name   ORDER BY survivor_rank) FILTER (WHERE parent_company_name IS NOT NULL)   AS parent_company_name,
           first(parent_source_record_key ORDER BY survivor_rank) FILTER (WHERE parent_source_record_key IS NOT NULL) AS parent_source_record_key,
           count(*) AS source_record_count,
           string_agg(DISTINCT source_name, ',' ORDER BY source_name) AS sources_present
      FROM ranked
     GROUP BY company_id
), address AS (
    SELECT DISTINCT ON (company_id) company_id, city, state, postal_code, country
      FROM ranked
     WHERE coalesce(city, state, postal_code, country) IS NOT NULL
     ORDER BY company_id, survivor_rank
)
SELECT b.company_id, b.company_name, b.informal_name, b.website, b.domain, b.phone,
       a.city, a.state, a.postal_code, a.country,
       b.founding_year, b.total_amount_invested,
       parent.company_id,                      -- the parent's resolved company, if the parent is in our data
       b.parent_company_name,
       b.source_record_count, b.sources_present,
       b.company_id IN (SELECT company_id FROM entity_resolution.company_alias WHERE is_pending_review)
  FROM best b
  LEFT JOIN address a ON a.company_id = b.company_id
  LEFT JOIN entity_resolution.company_alias parent ON parent.source_record_key = b.parent_source_record_key;
