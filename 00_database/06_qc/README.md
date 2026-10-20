# 06_qc: `qc` schema

Data-quality output. Nothing here blocks a load or changes a match. Back to [database migrations](../README.md).

| Table | Grain | Written by | Purpose |
|---|---|---|---|
| [`silver_validation_warning`](00_tables/001_silver_validation_warning.sql) | One row per transaction × attribute × rule | Silver load | `transformation_failure` (value NULLed) or `business_rule_warning` (value kept), with the `original_value` |
| [`check_finding`](00_tables/002_check_finding.sql) | One row per finding per run | QC checks | `qc_check_id` (→ `config.qc_check`, which holds the check's name, type and SQL), entities involved, `detail`, `review_queue_id` if a review was opened |

Designs: [Silver Design](../../03_silver/docs/Silver-Design.md) (warnings), [Quality Control Design](../../03_silver/docs/Quality-Control-Design.md) (checks).
