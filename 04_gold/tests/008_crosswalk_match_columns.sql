-- Fails on: match confidence / basis filled on a single-source row, or missing on a row present in both systems.
SELECT source_system, source_record_id, presence, match_confidence, match_basis
  FROM gold.crosswalk
 WHERE (presence = 'both') <> (match_confidence IS NOT NULL AND match_basis IS NOT NULL);
