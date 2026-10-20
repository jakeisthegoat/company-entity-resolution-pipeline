"""Bronze layer: loads every file that intake marked 'arrived' into its bronze table, exactly as received.
Prefect flow `load-bronze`; the first step of the pipeline run (run_pipeline.py). File intake must have run first.

Which files:
  - normal run: every file with status 'arrived' and a pipeline, oldest arrival first;
  - re-run:     one existing file_id (`python run_pipeline.py --rerun FILE_ID`), whatever its status.

Each file is loaded by functions/load_file_to_bronze.py in its own transaction (read the CSV in memory, check its
columns, replace the file's rows in one insert, record row_count). A failed file is logged and the run moves on.
"""
from prefect import flow, get_run_logger

from shared.database_connection import connect

from .functions.load_file_to_bronze import load_file_to_bronze


def _files_to_load(rerun_file_id: int | None) -> list[int]:
    """file_ids to load: every 'arrived' file, or the one being re-run (its reload_attempts is incremented)."""
    with connect() as conn:
        if rerun_file_id is not None:
            conn.execute("UPDATE ingestion.file_ingestion_log SET reload_attempts = reload_attempts + 1 WHERE file_id = ?",
                         (rerun_file_id,))
            return [rerun_file_id]
        return [r[0] for r in conn.execute(
            """
            SELECT file_id FROM ingestion.file_ingestion_log
             WHERE status = 'arrived' AND pipeline_id IS NOT NULL
             ORDER BY arrival_time, file_id
            """
        ).fetchall()]


@flow(name="load-bronze")
def load_bronze(rerun_file_id: int | None = None) -> list[dict]:
    """Load every waiting file (or re-run one file_id). Returns one result per file."""
    logger = get_run_logger()
    file_ids = _files_to_load(rerun_file_id)
    if not file_ids:
        logger.info("No files waiting for bronze")
    results = []
    for file_id in file_ids:
        try:
            results.append({"file_id": file_id, "status": "loaded", "rows": load_file_to_bronze(file_id)})
        except Exception as exc:  # the failure is already recorded by load_file_to_bronze
            results.append({"file_id": file_id, "status": "failed", "reason": str(exc)})
        logger.info("Bronze: %s", results[-1])
    return results
