# 07_gold: `gold` schema

What gets published. Rebuilt in full on every run, in one transaction with its tests: if any test fails, nothing is published ([Gold Design](../../04_gold/docs/Gold-Design.md)). No seed data. Back to [database migrations](../README.md).

| Table | Grain | Key | Purpose |
|---|---|---|---|
| [`company`](00_tables/001_company.sql) | One row per resolved company | `company_id` | The final companies table (survivorship: Part 1 values first, Salesforce fills gaps; address taken as a group) |
| [`person`](00_tables/002_person.sql) | One row per resolved person | `person_id` | The final people table with each person's primary affiliation (`company_id` FK → `company`) |
| [`person_company`](00_tables/003_person_company.sql) | One row per person × company | (`person_id`, `company_id`) | Every affiliation, de-duplicated, with `is_current` |
| [`crosswalk`](00_tables/004_crosswalk.sql) | One row per company source record | (`source_system`, `source_record_id`) | Every raw Part 1 company id and every Salesforce account → its company (`crosswalk_id`), with `presence` (`both` / `part1_only` / `salesforce_only`), `match_confidence` and `match_basis` on `both` rows, and `needs_review` |
| [`part1_company`](00_tables/005_part1_company.sql) (view) | One row per company with a Part 1 record | `company_id` | The Part 1 companies table: `company` without the Salesforce-only companies |
| [`data_quality_summary`](00_tables/006_data_quality_summary.sql) (view) | One row per metric | `line` | Raw rows in vs final rows out for companies, people and links, records pending review, and each QC check's findings in the latest run |

Created (and emptied in reverse) in this order: `person` and `crosswalk` refer to `company`, `person_company` to `person` and `company`. Test 004 checks these links on every build.
