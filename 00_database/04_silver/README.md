# 04_silver: `silver` schema

Clean, typed records: one row per transaction, every version kept. Written by the silver load ([Silver Design](../../03_silver/docs/Silver-Design.md)); read by entity resolution, QC and gold. No seed data. Back to [database migrations](../README.md).

| Table | From bronze | Attributes |
|---|---|---|
| [`company`](00_tables/001_company.sql) | `inbound_company_raw` | All 17 provider columns (`source_record_id`, `name`, `domain`, `phone_number`, `parent_id`, …) |
| [`account`](00_tables/002_account.sql) | `inbound_salesforce_account_raw` | The 19 documented Salesforce columns; core and `ss_*` fields kept separately |
| [`person`](00_tables/003_person.sql) | `inbound_person_raw` | All 16 columns |
| [`person_company`](00_tables/004_person_company.sql) | `inbound_person_company_raw` | All 13 columns; one row per source link id |

**Every table** starts with the same versioning and lineage columns:

| Column | Description |
|---|---|
| `transaction_id` | PK, from bronze |
| `source_record_key` | `"{source_id}-{source_record_id}"`: the source record across all its versions |
| `source_record_version` | 1, 2, 3… per source record, by file arrival; unique with `source_record_key`; never renumbered |
| `is_latest_version` | True on the highest version (indexed) |
| `is_changed_from_previous_version` | False for an identical resend |
| `row_hash`, `file_id`, `pipeline_id`, `source_id`, `loaded_at` | Lineage |

All ids that refer to a source record (`source_record_id`, `parent_id`, `person_id`, `company_id`) are VARCHAR so any source's id format fits.
