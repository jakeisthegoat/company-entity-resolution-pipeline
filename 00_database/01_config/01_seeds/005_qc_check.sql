-- Seed: config.qc_check
-- Every QC check, with the SQL it runs. Each query returns the rows that break the rule as
-- (entity_type, entity_id, related_entity_id, transaction_id, detail). transaction_id may be NULL: the runner
-- then opens the review on the related entity's first record. Explicit ids; upsert so a re-run updates rows.

INSERT INTO config.qc_check (qc_check_id, check_name, check_type, creates_review, description, check_sql, is_active)
VALUES
    (1, 'weak_company_pair', 'over_merge', true,
     'Two records in one company whose names are dissimilar (Jaro-Winkler similarity < 0.7) and share neither domain nor phone',
     $check$
SELECT 'company', a.company_id, NULL, b.transaction_id, 'weak pair: "' || ia.name || '" vs "' || ib.name || '"'
  FROM entity_resolution.company_alias a
  JOIN entity_resolution.company_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.company_alias b ON b.company_id = a.company_id AND b.transaction_id > a.transaction_id
  JOIN entity_resolution.company_match_input ib ON ib.transaction_id = b.transaction_id
 WHERE jaro_winkler_similarity(coalesce(ia.name, ''), coalesce(ib.name, '')) < 0.7
   AND ia.domain IS DISTINCT FROM ib.domain
   AND ia.phone IS DISTINCT FROM ib.phone
$check$, true),
    (2, 'weak_person_pair', 'over_merge', true,
     'Two records in one person whose names are dissimilar (Jaro-Winkler similarity < 0.7) and share neither LinkedIn nor email',
     $check$
SELECT 'person', a.person_id, NULL, b.transaction_id,
       'weak pair: "' || ia.first_name || ' ' || ia.last_name || '" vs "' || ib.first_name || ' ' || ib.last_name || '"'
  FROM entity_resolution.person_alias a
  JOIN entity_resolution.person_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.person_alias b ON b.person_id = a.person_id AND b.transaction_id > a.transaction_id
  JOIN entity_resolution.person_match_input ib ON ib.transaction_id = b.transaction_id
 WHERE jaro_winkler_similarity(concat(ia.first_name, ' ', ia.last_name), concat(ib.first_name, ' ', ib.last_name)) < 0.7
   AND ia.linkedin IS DISTINCT FROM ib.linkedin
   AND ia.email IS DISTINCT FROM ib.email
$check$, true),
    (3, 'conflicting_domains', 'over_merge', true,
     'Two records in one company with different domains',
     $check$
SELECT 'company', a.company_id, NULL, b.transaction_id, 'domains ' || ia.domain || ' vs ' || ib.domain
  FROM entity_resolution.company_alias a
  JOIN entity_resolution.company_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.company_alias b ON b.company_id = a.company_id AND b.transaction_id > a.transaction_id
  JOIN entity_resolution.company_match_input ib ON ib.transaction_id = b.transaction_id
 WHERE ia.domain <> ib.domain
$check$, true),
    (4, 'company_restatement_changed_id', 'over_merge', true,
     'Versions of one company source record that resolved to different company ids',
     $check$
SELECT 'company', max(r.company_id), min(r.company_id), max(i.transaction_id),
       i.source_record_key || ' resolved to ' || string_agg(DISTINCT r.company_id, ', ' ORDER BY r.company_id)
  FROM entity_resolution.company_match_input i
  JOIN entity_resolution.company_match_result r ON r.transaction_id = i.transaction_id
 GROUP BY i.source_record_key
HAVING count(DISTINCT r.company_id) > 1
$check$, true),
    (5, 'person_restatement_changed_id', 'over_merge', true,
     'Versions of one person source record that resolved to different person ids',
     $check$
SELECT 'person', max(r.person_id), min(r.person_id), max(i.transaction_id),
       i.source_record_key || ' resolved to ' || string_agg(DISTINCT r.person_id, ', ' ORDER BY r.person_id)
  FROM entity_resolution.person_match_input i
  JOIN entity_resolution.person_match_result r ON r.transaction_id = i.transaction_id
 GROUP BY i.source_record_key
HAVING count(DISTINCT r.person_id) > 1
$check$, true),
    (6, 'shared_domain', 'under_merge', true,
     'Two different companies with the same domain',
     $check$
SELECT DISTINCT 'company', a.company_id, b.company_id, NULL, 'shared domain ' || ia.domain
  FROM entity_resolution.company_alias a
  JOIN entity_resolution.company_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.company_match_input ib ON ib.domain = ia.domain
  JOIN entity_resolution.company_alias b ON b.transaction_id = ib.transaction_id AND b.company_id > a.company_id
$check$, true),
    (7, 'shared_phone', 'under_merge', true,
     'Two different companies with the same phone',
     $check$
SELECT DISTINCT 'company', a.company_id, b.company_id, NULL, 'shared phone ' || ia.phone
  FROM entity_resolution.company_alias a
  JOIN entity_resolution.company_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.company_match_input ib ON ib.phone = ia.phone
  JOIN entity_resolution.company_alias b ON b.transaction_id = ib.transaction_id AND b.company_id > a.company_id
$check$, true),
    (8, 'shared_name_and_state', 'under_merge', true,
     'Two different companies with the same normalized name in the same state',
     $check$
SELECT DISTINCT 'company', a.company_id, b.company_id, NULL, 'same name "' || ia.name || '" in ' || ia.state
  FROM entity_resolution.company_alias a
  JOIN entity_resolution.company_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.company_match_input ib ON ib.name = ia.name AND ib.state = ia.state
  JOIN entity_resolution.company_alias b ON b.transaction_id = ib.transaction_id AND b.company_id > a.company_id
$check$, true),
    (9, 'shared_linkedin_or_email', 'under_merge', true,
     'Two different people with the same LinkedIn URL or email',
     $check$
SELECT DISTINCT 'person', a.person_id, b.person_id, NULL, 'shared LinkedIn or email'
  FROM entity_resolution.person_alias a
  JOIN entity_resolution.person_match_input ia ON ia.transaction_id = a.transaction_id
  JOIN entity_resolution.person_match_input ib ON ib.linkedin = ia.linkedin OR ib.email = ia.email
  JOIN entity_resolution.person_alias b ON b.transaction_id = ib.transaction_id AND b.person_id > a.person_id
$check$, true),
    (10, 'end_before_start', 'cross_attribute', false,
     'An affiliation whose end_date is before its start_date',
     $check$
SELECT 'person', a.person_id, NULL, pc.transaction_id, 'start ' || pc.start_date || ', end ' || pc.end_date
  FROM silver.person_company pc
  LEFT JOIN entity_resolution.person_alias a ON a.source_record_key = pc.source_id || '-' || pc.person_id
 WHERE pc.is_latest_version AND pc.end_date < pc.start_date
$check$, true),
    (11, 'future_end_date', 'cross_attribute', false,
     'An affiliation whose end_date is in the future (gold treats it as current)',
     $check$
SELECT 'person', a.person_id, NULL, pc.transaction_id, 'end date ' || pc.end_date || ' is in the future'
  FROM silver.person_company pc
  LEFT JOIN entity_resolution.person_alias a ON a.source_record_key = pc.source_id || '-' || pc.person_id
 WHERE pc.is_latest_version AND pc.end_date > current_date
$check$, true),
    (12, 'core_vs_ss_name_conflict', 'cross_attribute', false,
     'A Salesforce account whose name and ss_company_name disagree (Jaro-Winkler similarity < 0.7)',
     $check$
SELECT 'company', a.company_id, NULL, s.transaction_id,
       'name "' || s.name || '" vs ss_company_name "' || s.ss_company_name || '"'
  FROM silver.account s
  LEFT JOIN entity_resolution.company_alias a ON a.transaction_id = s.transaction_id
 WHERE s.is_latest_version AND jaro_winkler_similarity(lower(s.name), lower(s.ss_company_name)) < 0.7
$check$, true),
    (13, 'conflicting_parent', 'cross_attribute', false,
     'A company whose provider records disagree on parent (one has none, or the names differ)',
     $check$
SELECT 'company', a.company_id, NULL, max(a.transaction_id),
       string_agg(c.name || ' -> ' || coalesce(c.parent_company, '(no parent)'), ' | ' ORDER BY c.name, c.parent_company)
  FROM entity_resolution.company_alias a
  JOIN silver.company c ON c.transaction_id = a.transaction_id
 GROUP BY a.company_id
HAVING count(DISTINCT lower(coalesce(c.parent_company, ''))) > 1
$check$, true),
    (14, 'orphan_affiliation', 'integrity', false,
     'An affiliation whose person or company has no source record',
     $check$
SELECT 'person', p.person_id, c.company_id, pc.transaction_id, 'person or company not found'
  FROM silver.person_company pc
  LEFT JOIN entity_resolution.person_alias p ON p.source_record_key = pc.source_id || '-' || pc.person_id
  LEFT JOIN entity_resolution.company_alias c ON c.source_record_key = pc.source_id || '-' || pc.company_id
 WHERE pc.is_latest_version AND (p.person_id IS NULL OR c.company_id IS NULL)
$check$, true)
ON CONFLICT (qc_check_id) DO UPDATE SET
    check_name = EXCLUDED.check_name, check_type = EXCLUDED.check_type, creates_review = EXCLUDED.creates_review,
    description = EXCLUDED.description, check_sql = EXCLUDED.check_sql, is_active = EXCLUDED.is_active,
    updated_at = now();
