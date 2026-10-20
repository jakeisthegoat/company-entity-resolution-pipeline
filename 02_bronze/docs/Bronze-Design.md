# Bronze Design

Every row ever received, exactly as received. The first step of the pipeline run: loads every file that intake marked `arrived`. Code: [load_bronze.py](../load_bronze.py) (**orchestrator**, Prefect flow `load-bronze`: picks the files), [load_file_to_bronze.py](../functions/load_file_to_bronze.py) (loads one file, including its row hash and failure recording). Tables: `00_database/03_bronze/00_tables/`. Back to [Pipeline Design](../../docs/design/Pipeline-Design.md).

## Tables

One table per pipeline, `bronze.<pipeline_name>_raw` (named in `config.pipeline.bronze_table_name`):

| Table | Source file | Source columns |
|---|---|---|
| `bronze.inbound_company_raw` | company.csv | 17 |
| `bronze.inbound_person_raw` | person.csv | 16 |
| `bronze.inbound_person_company_raw` | persontocompany.csv | 13 |
| `bronze.inbound_salesforce_account_raw` | account.csv | 269 (all, including the 250 empty ones) |

Source columns are **all VARCHAR**, stored exactly as received: no trimming, empty strings stay `''`. Typing and cleaning happen in silver.

Metadata columns on every table:

| Column | Description |
|---|---|
| `transaction_id` | `"{file_id}-{row_number}"` (PK). Unique per row received; identical on a re-run |
| `file_id` | FK → `ingestion.file_ingestion_log` |
| `row_number` | Position of the data row in the file (from 1) |
| `row_hash` | SHA-256 over the raw values in file column order, with an explicit null marker. Flags identical rows across files; rows are never dropped |
| `inserted_at` | Load time |
| `pipeline_id`, `source_id` | FKs to config |

## Load

In one transaction: delete the file's existing rows, insert the new ones, mark the file `loaded` and record its `row_count` (bronze is the only step that reads the file, so the count is taken here). A file with a column the bronze table doesn't have fails immediately. Connection-type errors are retried twice (30 s apart); every failed attempt is logged in the failure history.
