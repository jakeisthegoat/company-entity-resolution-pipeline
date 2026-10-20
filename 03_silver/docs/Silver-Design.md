# Silver Design

Everything in `03_silver` runs in this order, as part of the pipeline run:

| Step | Code | Design |
|---|---|---|
| 1. Load silver tables from bronze | [sql/load_silver/](../sql/load_silver/) (one folder per table, one file per step) | This document |
| 2. Company matching | [resolve_company_entities.py](../functions/resolve_company_entities.py) | [Entity Resolution Design](Entity-Resolution-Design.md) |
| 3. Person matching | [resolve_person_entities.py](../functions/resolve_person_entities.py) | [Entity Resolution Design: People](Entity-Resolution-Design.md#people) |
| 4. QC checks | [run_quality_control_checks.py](../functions/run_quality_control_checks.py) | [Quality Control Design](Quality-Control-Design.md) |

Company and person matching share one engine, [entity_matching_engine.py](../functions/entity_matching_engine.py), with their weights and thresholds in config tables ([matching settings](../../00_database/01_config/README.md#matching-settings)).

## Loading silver

Clean, typed records: one row per transaction, every version kept. The layer's **orchestrator** is [load_silver.py](../load_silver.py) (Prefect flow `load-silver`): it runs the four steps below in order. Tables: `00_database/04_silver/00_tables/`. Back to [Pipeline Design](../../docs/design/Pipeline-Design.md). Matching and QC run on silver: [Entity Resolution Design](Entity-Resolution-Design.md), [Quality Control Design](Quality-Control-Design.md).

## Tables

| Silver table | From bronze | Notes |
|---|---|---|
| `silver.company` | `inbound_company_raw` | All 17 columns |
| `silver.account` | `inbound_salesforce_account_raw` | The 19 documented columns; core and `ss_*` fields kept separately |
| `silver.person` | `inbound_person_raw` | All 16 columns, including those empty in this extract |
| `silver.person_company` | `inbound_person_company_raw` | All 13 columns; one row per source link id |

Column names stay close to the source (`billingcity` → `billing_city`, `ss_company_name__c` → `ss_company_name`); the source's id is always `source_record_id`. All `*_id` columns that reference a source record are VARCHAR so any source's id format fits.

## Versioning

| Column | Description |
|---|---|
| `transaction_id` | PK, from bronze. Silver merges on it |
| `source_record_key` | `"{source_id}-{source_record_id}"`; the row's `transaction_id` if the source id is missing |
| `source_record_version` | 1, 2, 3… per `source_record_key`, ordered by file arrival time then row number. Assigned once, never renumbered |
| `is_latest_version` | True on the highest version; turned off on the previous one when a new version loads |
| `is_changed_from_previous_version` | False when the row hash equals the previous version's (a resend with identical content) |
| `row_hash`, `file_id`, `pipeline_id`, `source_id`, `loaded_at` | Lineage |

A source resending a record is a **restatement**: a new version, not a replacement. Gold reads only the latest version.

## Load steps

Each silver table has a folder in [sql/load_silver/](../sql/load_silver/) (`01_company`, `02_account`, `03_person`, `04_person_company`), with **one SQL file per step**, run in order in **one transaction** per table:

| File | Step |
|---|---|
| `01_stage_new_bronze_rows.sql` | Bronze rows not yet in silver, trimmed, `''` → NULL, into temp table `stg` |
| `02_log_cast_failures.sql` | Values that can't be cast: NULLed in silver, logged with the original value |
| `03_log_business_rule_warnings.sql` | Rule failures: value kept, warning logged |
| `04_insert_typed_rows.sql` | Typed rows, with `source_record_key` and `source_record_version` |
| `05_refresh_version_flags.sql` | `is_latest_version`, `is_changed_from_previous_version` |

Only bronze rows **not yet in silver** are processed, so the load is safe to run at any time; a re-run file has identical content, so nothing is missed.

For each attribute, in SQL:

1. `btrim`, then `''` → NULL.
2. Lowercase `domain` and `email`. Everything else is kept as received (phones are not reformatted).
3. Cast to the column type. A value that can't be cast (`TRY_CAST` returns NULL) becomes **NULL** and is logged as a `transformation_failure`.
4. Business checks, **warnings only** (the value is kept), logged as `business_rule_warning`:

| Rule | Applies to | Checks |
|---|---|---|
| `required` | `source_record_id`; `person_id`, `company_id` on `person_company` | Not NULL |
| `valid_year` | `founding_year`, `ss_year_founded` | 4-digit year |
| `non_negative` | `total_amount_invested`, `number_of_employees` | ≥ 0 |
| `valid_email` | `email` | `x@y.z` format |
| `valid_phone` | All phone columns | 10 digits, or 11 with a leading 1 |

5. Assign `source_record_key`, `source_record_version`, `is_latest_version`, `is_changed_from_previous_version`.
6. Merge into the silver table on `transaction_id`.

A value that fails its cast **and** a business rule (e.g. founding year `abc`) is logged under both.

**No row is ever rejected**, and warnings don't affect any later step. Cross-column checks (e.g. end date before start date) are QC checks.

**`qc.silver_validation_warning`**: one row per transaction × attribute × rule, with `failure_type`, `rule_name`, `original_value`, `failure_reason`.

## Salesforce core vs. `ss_*` fields

Salesforce sends two values for name, website, city, state and phone: the core field and a copy from a sourcing tool (`ss_*`). They sometimes disagree (`name` "Helix Intelligence Group" vs `ss_company_name` "Centrum-AI Inc."). Both are kept in silver. Matching uses the **core** fields only; the `ss_*` copies are kept for QC, which flags records where they disagree (`core_vs_ss_name_conflict`).

## Duplicate person-company links

Silver keeps every link. Duplicate person × company pairs are resolved in gold, after company matching, because more pairs collapse once merged companies share one id.
