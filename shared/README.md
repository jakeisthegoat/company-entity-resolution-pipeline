# shared

Only code used by **more than one layer**. Code used by a single layer lives in that layer's `functions/` folder.

| File | Used by | Purpose |
|---|---|---|
| `database_connection.py` | All layers | Opens the DuckDB database file (`00_database/pipeline.duckdb`); each `with connect()` block is one transaction |
| `run_sql_files.py` | 00_database, 03_silver, 04_gold | Runs a folder's SQL step files in name order, in the caller's transaction |
