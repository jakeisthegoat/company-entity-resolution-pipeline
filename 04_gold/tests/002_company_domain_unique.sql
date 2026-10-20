-- Fails on: a domain on more than one company. Companies pending review are excluded:
-- a shared domain there is the reason for the review, not a published error.
SELECT domain, string_agg(company_id, ', ') FROM gold.company
 WHERE domain IS NOT NULL AND NOT is_pending_review
 GROUP BY domain HAVING count(*) > 1;
