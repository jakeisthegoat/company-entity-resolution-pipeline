"""Silver layer: clean, typed, versioned silver tables, then entity resolution and quality checks.
Prefect flow `load-silver`; the second step of the pipeline run (run_pipeline.py), after bronze.

  1. Load the silver tables from bronze, one table at a time, in folder order (sql/load_silver/):
     01_company, 02_account, 03_person, 04_person_company. Each table's step files run in order in ONE
     transaction (shared/run_sql_files.py):
       01_stage_new_bronze_rows       bronze rows not yet in silver, trimmed, '' -> NULL
       02_log_cast_failures           values that can't be cast: NULLed in silver, logged in qc.silver_validation_warning
       03_log_business_rule_warnings  rule failures: value kept, warning logged
       04_insert_typed_rows           typed rows, with source_record_key and source_record_version
       05_refresh_version_flags       is_latest_version, is_changed_from_previous_version
  2. Resolve companies (functions/resolve_company_entities.py): Part 1 first, then Salesforce onto it; in memory.
  3. Resolve people (functions/resolve_person_entities.py), using the resolved companies; in memory.
  4. Run the QC checks (functions/run_quality_control_checks.py).
Every step only processes what is new, so the flow is safe to run at any time.
"""
from pathlib import Path

from prefect import flow, get_run_logger, task

from shared.database_connection import connect
from shared.run_sql_files import run_sql_files, sql_files_in_order

from .functions.resolve_company_entities import resolve_companies
from .functions.resolve_person_entities import resolve_people
from .functions.run_quality_control_checks import run_qc

LOAD_SILVER_SQL = Path(__file__).parent / "sql" / "load_silver"


@task
def load_silver_table(table_folder: Path) -> None:
    """Run one silver table's load steps, in order, in one transaction."""
    with connect() as conn:
        run_sql_files(conn, sql_files_in_order(table_folder))
    get_run_logger().info("silver.%s loaded", table_folder.name.split("_", 1)[1])


@flow(name="load-silver")
def load_silver() -> None:
    for table_folder in sorted(p for p in LOAD_SILVER_SQL.iterdir() if p.is_dir()):
        load_silver_table(table_folder)
    resolve_companies()
    resolve_people()
    run_qc()
