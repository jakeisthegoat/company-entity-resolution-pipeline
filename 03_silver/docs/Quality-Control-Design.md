# Quality Control Design

Runs after entity resolution on every run: Prefect flow `run-qc` in [run_quality_control_checks.py](../functions/run_quality_control_checks.py). **Every check is configured in `config.qc_check`**: its name, type, whether it opens a review, and the **literal SQL** to run (`check_sql`). The runner just executes each active check's SQL and records what it returns, so adding, changing or switching off a check is a change to the seed file [005_qc_check.sql](../../00_database/01_config/01_seeds/005_qc_check.sql), not code. Each query returns `(entity_type, entity_id, related_entity_id, transaction_id, detail)`. Checks look at **current members** only (the latest version of each source record, via `company_alias` / `person_alias`). Tables: `00_database/06_qc/00_tables/`.

## Checks

| Check | Type | Flags | Action |
|---|---|---|---|
| `weak_company_pair` | Over-merge | Two records in one company whose names are dissimilar (Jaro-Winkler similarity < 0.7) and share neither domain nor phone | Review queue |
| `weak_person_pair` | Over-merge | Two records in one person whose names are dissimilar and share neither LinkedIn nor email | Review queue |
| `conflicting_domains` | Over-merge | A company whose members have different domains | Review queue |
| `company_restatement_changed_id`, `person_restatement_changed_id` | Over-merge | Versions of one source record that resolved to different ids | Review queue |
| `shared_domain` | Under-merge | Two companies sharing a domain | Review queue |
| `shared_phone` | Under-merge | Two companies sharing a phone | Review queue |
| `shared_name_and_state` | Under-merge | Two companies with the same normalized name in the same state | Review queue |
| `shared_linkedin_or_email` | Under-merge | Two people sharing a LinkedIn URL or email | Review queue |
| `end_before_start` | Cross-attribute | `end_date` < `start_date` | Informational |
| `future_end_date` | Cross-attribute | `end_date` in the future (treated as current in gold) | Informational |
| `core_vs_ss_name_conflict` | Cross-attribute | Salesforce `name` vs `ss_company_name` below 0.7 Jaro-Winkler similarity | Informational |
| `conflicting_parent` | Cross-attribute | A company whose provider records disagree on parent (one has none, or the names differ) | Informational |
| `orphan_affiliation` | Integrity | A link whose person or company has no source record | Informational |

Merge findings become review queue entries, unless the transaction is already in the queue. Over-merge checks name the record to review; under-merge checks name two companies (or people), and the runner opens the review on the second one's first record with the first as the candidate. Nothing is changed automatically. Findings are kept per run, so the table is a history.

## Results on the assessment data

| Check | Findings | What they are |
|---|---|---|
| `weak_company_pair`, `weak_person_pair`, `*_restatement_changed_id` | 0 | No over-merges |
| `conflicting_domains` | 3 | The 3 Salesforce domain traps: *VyMaC*, *ALIGNMT* and *Wyoming Mutual* merged correctly with their provider record on name and phone, but their Salesforce `domain` belongs to another company |
| `shared_domain` | 11 | The same 3 Salesforce domain traps from the other side (*VyMaC* / *Connor Fastener*, *ALIGNMT* / *Karp's Homebrew Shop*, *Wyoming Mutual* / *Syzygy*), *Helix* / *Centrum-AI*, and pairs already in review (*Standard*, *Vantage*, *SUNY*, *Odd13*, *Shepherd*, *Aspire*, *Neighborly*) |
| `shared_phone` | 11 | One phone shared by 4 unrelated companies (*FanBeat*, *PrimeVault*, *Sky Homes*, *Spiritual Highness*): likely a registered-agent or shared-office line; plus pairs already in review |
| `shared_name_and_state`, `shared_linkedin_or_email` | 0 | |
| `end_before_start` | 54 | Affiliations ending before they start |
| `future_end_date` | 17 | Future end dates (treated as current) |
| `core_vs_ss_name_conflict` | 2 | *Helix Intelligence Group* vs *Centrum-AI Inc.* (similarity 0.54), and *Sensorium Labs (fka OVR Tech)* vs *OVR Tech, LLC* (0.39, a renamed company) |
| `conflicting_parent` | 6 | A parent present on one sync and missing on another (*Inspirage* → *Accenture PLC*, *Shyft Group* → *Aebi Schmidt*, …), different parents (*Plastic Components*: *Trim-Tex* vs *Sports Molding*), inconsistent spelling (*King's Hawaiian Holding Co.* vs *Company*), and one record naming itself as parent (*Gold Group Enterprises dba GoMo Health* → *Gold Group Enterprises*) |
| `orphan_affiliation` | 0 | |

**Results of this run:** Part 1: 1,024 provider rows → 1,005 companies; overall 1,017 companies (88 in both systems, 917 provider only, 12 Salesforce only), 1,869 people, 104 merged entities (103 companies, 1 person), 21 transactions pending review, 1 silver validation warning. The main counts and each check's findings are in the view `gold.data_quality_summary`, which the pipeline logs at the end of every run.

Name similarity uses DuckDB's built-in `jaro_winkler_similarity(a, b)` (0–1). The 0.7 cut-off sits in a clear gap in this data: true conflicts score 0.39–0.54, matching names 0.94 and up. Findings are sorted, so the same data always opens the same reviews. Every check is a single, short query (at most 9 lines), one entity type per check.

## Tables

| Table | Grain | Purpose |
|---|---|---|
| `qc.silver_validation_warning` | One row per transaction × attribute × rule | Silver load warnings ([Silver Design](Silver-Design.md)) |
| `qc.check_finding` | One row per finding per run | `qc_check_id` (→ `config.qc_check`), `run_at`, `entity_type`, `entity_id`, `related_entity_id`, `transaction_id`, `detail`, `review_queue_id` |
