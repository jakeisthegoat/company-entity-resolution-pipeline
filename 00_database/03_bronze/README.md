# 03_bronze: `bronze` schema

Every row ever received, exactly as received. Written only by the bronze load ([Bronze Design](../../02_bronze/docs/Bronze-Design.md)); read by the silver load. No seed data. Back to [database migrations](../README.md).

| Table | Source file | Source columns |
|---|---|---|
| [`inbound_company_raw`](00_tables/001_inbound_company_raw.sql) | company.csv | 17 |
| [`inbound_person_raw`](00_tables/002_inbound_person_raw.sql) | person.csv | 16 |
| [`inbound_person_company_raw`](00_tables/003_inbound_person_company_raw.sql) | persontocompany.csv | 13 |
| [`inbound_salesforce_account_raw`](00_tables/004_inbound_salesforce_account_raw.sql) | account.csv | 269 (all, including the empty ones) |

**Every table** has the same metadata columns, followed by the source columns (all VARCHAR, named exactly as in the file header):

| Column | Description |
|---|---|
| `transaction_id` | PK: `"{file_id}-{row_number}"`, one per row received; identical on a re-run |
| `file_id` | FK → `ingestion.file_ingestion_log` |
| `row_number` | Position of the data row in the file (unique with `file_id`) |
| `row_hash` | SHA-256 of the raw values |
| `inserted_at` | Load time |
| `pipeline_id`, `source_id` | FKs → `config` |

A new source file needs a new table here, named in `config.pipeline.bronze_table_name`.
