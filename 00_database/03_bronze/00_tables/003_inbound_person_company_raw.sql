-- bronze.inbound_person_company_raw
-- Every row received from persontocompany.csv, exactly as received. 13 source columns, all VARCHAR, plus metadata.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS bronze.inbound_person_company_raw (
    transaction_id VARCHAR(50) PRIMARY KEY,
    file_id BIGINT NOT NULL,  -- -> ingestion.file_ingestion_log
    row_number INTEGER NOT NULL,
    row_hash CHAR(64) NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    source_id INTEGER NOT NULL,  -- -> config.source
    "id" VARCHAR,
    "personid" VARCHAR,
    "companyid" VARCHAR,
    "startdate" VARCHAR,
    "enddate" VARCHAR,
    "email" VARCHAR,
    "emailconfirmed" VARCHAR,
    "phone" VARCHAR,
    "title" VARCHAR,
    "role" VARCHAR,
    "deleted" VARCHAR,
    "modifieddate" VARCHAR,
    "loaddate" VARCHAR,
    UNIQUE (file_id, row_number)
);
