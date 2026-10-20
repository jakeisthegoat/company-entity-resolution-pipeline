-- Fails on: a presence value that disagrees with the source systems actually on that crosswalk_id.
WITH sources AS (
    SELECT crosswalk_id, string_agg(DISTINCT source_system, ',' ORDER BY source_system) AS present
      FROM gold.crosswalk GROUP BY crosswalk_id
)
SELECT x.crosswalk_id, x.presence, s.present
  FROM gold.crosswalk x JOIN sources s USING (crosswalk_id)
 WHERE x.presence <> CASE s.present WHEN 'part1_company,salesforce' THEN 'both'
                                    WHEN 'part1_company' THEN 'part1_only'
                                    WHEN 'salesforce' THEN 'salesforce_only' END;
