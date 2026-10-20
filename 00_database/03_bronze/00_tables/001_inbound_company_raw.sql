-- bronze.inbound_company_raw
-- Every row received from company.csv, exactly as received. 17 source columns, all VARCHAR, plus metadata.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS bronze.inbound_company_raw (
    transaction_id VARCHAR(50) PRIMARY KEY,
    file_id BIGINT NOT NULL,  -- -> ingestion.file_ingestion_log
    row_number INTEGER NOT NULL,
    row_hash CHAR(64) NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    source_id INTEGER NOT NULL,  -- -> config.source
    "id" VARCHAR,
    "name" VARCHAR,
    "informalname" VARCHAR,
    "website" VARCHAR,
    "domain" VARCHAR,
    "phonenumber" VARCHAR,
    "city" VARCHAR,
    "state" VARCHAR,
    "postalcode" VARCHAR,
    "country" VARCHAR,
    "foundingyear" VARCHAR,
    "companytype" VARCHAR,
    "parentid" VARCHAR,
    "parentcompany" VARCHAR,
    "totalamountinvested" VARCHAR,
    "nolongerinbusiness" VARCHAR,
    "modifieddate" VARCHAR,
    UNIQUE (file_id, row_number)
);
