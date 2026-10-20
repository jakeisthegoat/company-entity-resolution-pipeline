# 05_entity_resolution: `entity_resolution` schema

Match inputs, match decisions and master ids. Company and person each have their own normalized set of tables (company shown below; person is identical with `person_id`). Written by company and person matching ([Entity Resolution Design](../../03_silver/docs/Entity-Resolution-Design.md)); read by QC and gold. No seed data. Back to [database migrations](../README.md).

| Table / view | Grain | Purpose |
|---|---|---|
| [`company_master`](00_tables/001_company_master.sql) | One row per master id | The only place an id is defined (`CMP-000001`) and whether it is still in use: `is_active` (false once a review merges it into another id). Pending review is not stored here; it comes from the review queue |
| [`company_match_input`](00_tables/003_company_match_input.sql) | One row per transaction | What gets matched: `transaction_id`, `source_record_key`, `source_record_version`, `source_id`, `arrival_time`, `row_number`, and one normalized value per field from the core silver columns: `name`, `domain`, `phone`, `city`, `state`, plus the non-scored `parent_record_key` |
| [`company_match_result`](00_tables/005_company_match_result.sql) | One row per transaction | **The mastering output:** `company_id`, `match_score`, `match_band`, `match_basis`, `matched_transaction_id`, `decided_by`, `decided_at` |
| [`company_match_review_queue`](00_tables/007_company_match_review_queue.sql) | One row per transaction × candidate (top 3) | Manual review: candidate, score, basis, `review_status`, reviewer |
| [`company_alias`](00_tables/009_company_alias.sql) (view) | One row per source record | Raw id → master id: one row per source record with its latest version's `transaction_id`, `source_id`, `company_id` and `is_pending_review` (true while the transaction has a pending review). Inactive ids excluded. Used by person matching, QC and gold |

Person tables: [`person_master`](00_tables/002_person_master.sql), [`person_match_input`](00_tables/004_person_match_input.sql) (`first_name`, `last_name`, `linkedin`, plus `email` and `company_id` from the primary affiliation), [`person_match_result`](00_tables/006_person_match_result.sql), [`person_match_review_queue`](00_tables/008_person_match_review_queue.sql), [`person_alias`](00_tables/010_person_alias.sql).

Ids are never reused or renumbered. Views use `CREATE OR REPLACE`, so they are always rebuilt from the current tables.
