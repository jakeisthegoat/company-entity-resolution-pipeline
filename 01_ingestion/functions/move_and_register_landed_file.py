"""Takes in ONE landed file: reserve its file_id, route it, move it into place, then log it.
Called by 01_ingestion/intake_files.py for each file in inbound/landed/.

  1. Reserve the next file_id from ingestion.file_id_sequence (no row is written yet).
  2. Route the file by its original name (config.pipeline_file_pattern).
  3. Move it, named with the reserved file_id: matched -> inbound/<source_name>/<YYYY-MM-DD>/<file_id>_<name>;
     unmatched -> inbound/unmatched/<YYYY-MM-DD>/<file_id>_<name>.
  4. Insert its row into ingestion.file_ingestion_log pointing at that final path: status 'arrived' (with its
     pipeline_id) or 'unmatched' (with the reason).

Moved first, logged second, so a log row always points at where the file really is. If the insert fails after
the move, the file is moved back to inbound/landed/ and retried on the next run (the reserved id is unused).
"""
import shutil
from datetime import date
from pathlib import Path

from prefect import task

from shared.database_connection import connect

from .inbound_folder_paths import relative_to_project, routed_file_path, unmatched_file_path
from .match_file_name_to_pipeline import match_file_name_to_pipeline


@task
def move_and_register_landed_file(path: Path) -> dict:
    """Reserve a file_id, move the file to its source (or unmatched) folder, then log it there."""
    intake_date = date.today()
    file_size = path.stat().st_size
    with connect() as conn:
        file_id = conn.execute(
            "SELECT nextval('ingestion.file_id_sequence')"
        ).fetchone()[0]
        route, reason = match_file_name_to_pipeline(conn, path.name)
        if route:
            target = routed_file_path(route.source_name, file_id, path.name, intake_date)
        else:
            target = unmatched_file_path(file_id, path.name, intake_date)

        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(path, target)
        try:
            conn.execute(
                """
                INSERT INTO ingestion.file_ingestion_log
                    (file_id, pipeline_id, original_file_name, file_path, file_size, status, failure_reason)
                VALUES (?, ?, ?, ?, ?, ?, ?)
                """,
                (file_id, route.pipeline_id if route else None, path.name, relative_to_project(target),
                 file_size, "arrived" if route else "unmatched", reason or None),
            )
            conn.commit()
        except Exception:
            shutil.move(target, path)  # put it back so the next run retries it
            raise
    return {"file_id": file_id, "file": path.name, "status": "arrived" if route else "unmatched",
            "pipeline": route.pipeline_name if route else None, "path": relative_to_project(target),
            "reason": reason or None}
