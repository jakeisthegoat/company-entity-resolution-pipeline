-- entity_resolution.company_alias (view)
-- Raw id -> master id: one row per source record, using its latest version's transaction and match result.
-- These are the current members of each company: inactive (retired) ids are excluded. is_pending_review is true
-- while the transaction has a pending row in the review queue.
-- Used by person matching (resolved company ids), QC checks and gold.
-- Idempotent: CREATE OR REPLACE.

CREATE OR REPLACE VIEW entity_resolution.company_alias AS
SELECT DISTINCT ON (i.source_record_key)
    i.source_record_key,
    i.transaction_id,
    i.source_id,
    r.company_id,
    EXISTS (SELECT 1 FROM entity_resolution.company_match_review_queue q
             WHERE q.transaction_id = i.transaction_id AND q.review_status = 'pending') AS is_pending_review
FROM entity_resolution.company_match_input i
JOIN entity_resolution.company_match_result r ON r.transaction_id = i.transaction_id
JOIN entity_resolution.company_master m ON m.company_id = r.company_id
WHERE m.is_active
ORDER BY i.source_record_key, i.source_record_version DESC;
