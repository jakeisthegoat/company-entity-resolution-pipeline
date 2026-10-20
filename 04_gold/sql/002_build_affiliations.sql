-- Gold step 2: build the de-duplicated affiliations as the temp table `affiliation` (lasts until the connection closes).
-- Latest-version links with person and company resolved to master ids (through person_alias / company_alias).
-- Duplicate person x company pairs keep the most complete row, then the latest modified_date.
-- is_current: no end date, or an end date in the future. Used by steps 3 (primary affiliation) and 4.

CREATE OR REPLACE TEMP TABLE affiliation AS
SELECT DISTINCT ON (pm.person_id, cm.company_id)
       pm.person_id, cm.company_id, pc.title, pc.email, pc.email_confirmed, pc.phone, pc.role,
       pc.start_date, pc.end_date,
       (pc.end_date IS NULL OR pc.end_date > current_date) AS is_current
  FROM silver.person_company pc
  JOIN entity_resolution.person_alias pm ON pm.source_record_key = pc.source_id || '-' || pc.person_id
  JOIN entity_resolution.company_alias cm ON cm.source_record_key = pc.source_id || '-' || pc.company_id
 WHERE pc.is_latest_version
 ORDER BY pm.person_id, cm.company_id,
          (pc.title IS NOT NULL)::int + (pc.email IS NOT NULL)::int + (pc.phone IS NOT NULL)::int
            + (pc.role IS NOT NULL)::int + (pc.start_date IS NOT NULL)::int + (pc.end_date IS NOT NULL)::int DESC,  -- most complete
          pc.modified_date DESC NULLS LAST, pc.transaction_id DESC;
