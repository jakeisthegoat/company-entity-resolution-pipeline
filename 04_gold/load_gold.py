"""Gold layer: rebuilds the published tables from scratch, then tests them. Prefect flow `load-gold`; the last
step of the pipeline run (run_pipeline.py).

Everything runs in ONE transaction:
  1. Empty the gold tables.
  2. Run the build steps in sql/, in order (shared/run_sql_files.py):
       001_company               gold.company: survivorship by resolution order, then most recent; address as a group
       002_build_affiliations    temp table `affiliation`: links on resolved ids, duplicate pairs removed
       003_person                gold.person, with each person's primary affiliation
       004_person_company        gold.person_company from `affiliation`
       005_crosswalk             gold.crosswalk: every raw company id and Salesforce account -> its company
  3. Run every test in tests/. A test is a query returning the rows that break a rule.
  4. If any test returns rows, raise GoldTestFailure: the transaction rolls back and the previously published
     gold tables stay exactly as they were.
  5. Log the data-quality summary (the view gold.data_quality_summary: rows in vs out, and QC findings per check).
"""
from pathlib import Path

from prefect import flow, get_run_logger, task

from shared.database_connection import connect
from shared.run_sql_files import run_sql_files, sql_files_in_order

BUILD_SQL = Path(__file__).parent / "sql"
TESTS_SQL = Path(__file__).parent / "tests"
GOLD_TABLES = ["gold.company", "gold.person", "gold.person_company", "gold.crosswalk"]  # in build order


class GoldTestFailure(Exception):
    """One or more gold tests failed; the build was rolled back."""


@task
def build_and_test_gold() -> dict:
    """Rebuild every gold table and run every test, in one transaction. Raises GoldTestFailure on a failing test."""
    logger = get_run_logger()
    with connect() as conn:
        for table in reversed(GOLD_TABLES):
            conn.execute(f"DELETE FROM {table}")
        run_sql_files(conn, sql_files_in_order(BUILD_SQL))
        counts = {t: conn.execute(f"SELECT count(*) FROM {t}").fetchone()[0] for t in GOLD_TABLES}

        failures = {}
        for test in sql_files_in_order(TESTS_SQL):
            rows = conn.execute(test.read_text()).fetchall()
            logger.info("Test %s: %s", test.stem, "FAILED" if rows else "passed")
            if rows:
                failures[test.stem] = rows[:5]
        if failures:
            raise GoldTestFailure(f"gold not published; failing tests: {failures}")
    logger.info("Gold published: %s", counts)
    log_data_quality_summary()
    return counts


def log_data_quality_summary() -> None:
    """Log every line of gold.data_quality_summary."""
    logger = get_run_logger()
    with connect() as conn:
        rows = conn.execute("SELECT category, metric, value FROM gold.data_quality_summary ORDER BY line").fetchall()
    for category, metric, value in rows:
        logger.info("Data quality | %-15s | %-40s | %s", category, metric, value)


@flow(name="load-gold")
def load_gold() -> dict:
    return build_and_test_gold()
