-- Gold step 5: gold.crosswalk: one row per company source record (latest version) -> its company (crosswalk_id).
--
-- presence: which systems the company is in, from the sources of all its records.
-- match_confidence / match_basis: only when presence = 'both' (blank on part1_only / salesforce_only, as the
-- brief asks). They describe the cross-system match: the Salesforce account's match onto the Part 1 company
-- (sources with resolution_order > 1 matched onto the reference). Every row of that company shows it.
-- needs_review: the company has a pending review (from gold.company).

INSERT INTO gold.crosswalk (
    crosswalk_id, source_system, source_record_id, source_name, presence, match_confidence, match_basis, needs_review)
WITH member AS (
    SELECT cm.company_id, cm.transaction_id, s.source_name AS source_system, ero.resolution_order,
           coalesce(c.source_record_id, a.source_record_id) AS source_record_id,
           coalesce(c.name, a.name) AS source_name,
           r.match_score, r.match_band, r.match_basis
      FROM entity_resolution.company_alias cm
      JOIN config.source s ON s.source_id = cm.source_id
      LEFT JOIN config.entity_resolution_order ero ON ero.entity_type = 'company' AND ero.source_id = cm.source_id
      JOIN entity_resolution.company_match_result r USING (transaction_id)
      LEFT JOIN silver.company c USING (transaction_id)
      LEFT JOIN silver.account a USING (transaction_id)
), company AS (
    SELECT company_id,
           CASE WHEN bool_or(source_system = 'part1_company') AND bool_or(source_system = 'salesforce') THEN 'both'
                WHEN bool_or(source_system = 'part1_company') THEN 'part1_only'
                ELSE 'salesforce_only' END AS presence
      FROM member GROUP BY company_id
), cross_system_match AS (
    -- The strongest match a later-order source (Salesforce) made onto the company.
    SELECT DISTINCT ON (company_id) company_id, match_score, match_basis
      FROM member
     WHERE resolution_order > 1 AND match_band IN ('exact', 'auto_match')
     ORDER BY company_id, match_score DESC, transaction_id
)
SELECT m.company_id, m.source_system, m.source_record_id, m.source_name, c.presence,
       CASE WHEN c.presence = 'both' THEN x.match_score END,
       CASE WHEN c.presence = 'both' THEN x.match_basis END,
       g.is_pending_review
  FROM member m
  JOIN company c USING (company_id)
  LEFT JOIN cross_system_match x USING (company_id)
  JOIN gold.company g ON g.company_id = m.company_id;
