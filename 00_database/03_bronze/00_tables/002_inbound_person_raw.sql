-- bronze.inbound_person_raw
-- Every row received from person.csv, exactly as received. 16 source columns, all VARCHAR, plus metadata.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS bronze.inbound_person_raw (
    transaction_id VARCHAR(50) PRIMARY KEY,
    file_id BIGINT NOT NULL,  -- -> ingestion.file_ingestion_log
    row_number INTEGER NOT NULL,
    row_hash CHAR(64) NOT NULL,
    inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    pipeline_id INTEGER NOT NULL,  -- -> config.pipeline
    source_id INTEGER NOT NULL,  -- -> config.source
    "id" VARCHAR,
    "firstname" VARCHAR,
    "middlename" VARCHAR,
    "lastname" VARCHAR,
    "linkedin" VARCHAR,
    "facebook" VARCHAR,
    "twitter" VARCHAR,
    "website" VARCHAR,
    "city" VARCHAR,
    "state" VARCHAR,
    "country" VARCHAR,
    "deleted" VARCHAR,
    "statecode" VARCHAR,
    "countrycode" VARCHAR,
    "modifieddate" VARCHAR,
    "loaddate" VARCHAR,
    UNIQUE (file_id, row_number)
);
