"""Ingestion layer: file intake. Gets files in inbound/landed/ ready for bronze. Runs separately from the pipeline.
Prefect flow `intake-files`, started by run_file_intake.py (on demand, or every 5 minutes with --serve).

Every file in inbound/landed/, oldest first, is taken in by functions/move_and_register_landed_file.py: it gets a
new file_id, is moved to inbound/<source_name>/<YYYY-MM-DD>/ (status 'arrived') or inbound/unmatched/<YYYY-MM-DD>/
(status 'unmatched'), and is logged in ingestion.file_ingestion_log. Loading into bronze is the pipeline run's
first step. To take in an unmatched file once its pattern is configured, move it back into inbound/landed/.
"""
from prefect import flow, get_run_logger

from .functions.inbound_folder_paths import LANDED_DIR
from .functions.move_and_register_landed_file import move_and_register_landed_file


@flow(name="intake-files")
def intake_files() -> list[dict]:
    """Take in every file in inbound/landed/, oldest first. Returns one result per file."""
    logger = get_run_logger()
    files = sorted((p for p in LANDED_DIR.iterdir() if p.is_file() and not p.name.startswith(".")),
                   key=lambda p: p.stat().st_mtime)
    if not files:
        logger.info("inbound/landed is empty: nothing to take in")
    results = []
    for path in files:
        try:
            result = move_and_register_landed_file(path)
        except Exception as exc:  # the file is back in landed/; nothing was logged
            result = {"file": path.name, "status": "left in landed", "reason": str(exc)}
        logger.info("Intake: %s", result)
        results.append(result)
    return results
