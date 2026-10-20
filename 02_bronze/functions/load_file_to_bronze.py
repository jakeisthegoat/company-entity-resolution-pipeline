"""Loads ONE file into its bronze table, exactly as received. Called by 02_bronze/load_bronze.py for each file.

In one transaction:
  1. Read the CSV as text (every value stays a string; empty values stay '').
  2. Check every column in the file exists in the pipeline's bronze table (config.pipeline.bronze_table_name).
     An unexpected column fails the file immediately.
  3. Delete any rows this file_id already has in bronze (so a re-run replaces, never duplicates).
  4. Insert the rows, adding transaction_id ("{file_id}-{row_number}"), row_number, row_hash, pipeline_id, source_id.
  5. Mark the file 'loaded' and record its row_count. Bronze is the only step that reads the file, so this is
     where the count is known; intake leaves row_count empty.

row_hash: SHA-256 of the row's raw values in file order (compute_bronze_row_hash). Silver uses it to mark a resent
record as unchanged; bronze never drops a row.

Failures: each failed attempt is written to the failure history and the file is marked 'failed'
(record_file_failure). Connection-type errors are retried twice, 30 seconds apart; a bad file (ValueError) is not
retried.
"""
import csv
import hashlib
import re

from prefect import get_run_logger, task

from shared.database_connection import PROJECT_ROOT, connect

_METADATA_COLUMNS = ["transaction_id", "file_id", "row_number", "row_hash", "pipeline_id", "source_id"]


def compute_bronze_row_hash(values: list[str | None]) -> str:
    """64-character hex SHA-256 of the row's raw values. Values are joined with the ASCII unit separator (which
    can't appear in a CSV value by accident), and a missing value is written as a null marker so it differs from ''."""
    joined = "\x1f".join("\x00" if v is None else v for v in values)
    return hashlib.sha256(joined.encode("utf-8")).hexdigest()


def record_file_failure(file_id: int, reason: str) -> None:
    """Mark the file 'failed' in ingestion.file_ingestion_log and append the attempt to
    ingestion.file_ingestion_failure_log (the log keeps only the latest state; the failure log keeps every attempt).
    Uses its own connection, so the failure is recorded even though the load's own transaction rolled back."""
    with connect() as conn:
        conn.execute(
            """
            UPDATE ingestion.file_ingestion_log
               SET status = 'failed', failure_reason = $reason, last_attempt_at = now()
             WHERE file_id = $file_id
            """,
            {"file_id": file_id, "reason": reason},
        )
        conn.execute(
            """
            INSERT INTO ingestion.file_ingestion_failure_log (file_id, attempt_number, failure_reason)
            SELECT $file_id, COALESCE(MAX(attempt_number), 0) + 1, $reason
              FROM ingestion.file_ingestion_failure_log
             WHERE file_id = $file_id
            """,
            {"file_id": file_id, "reason": reason},
        )


def _quoted(name: str) -> str:
    """Quote a table or column name for SQL ('Billing City' -> '"Billing City"')."""
    return '"' + name.replace('"', '""') + '"'


def _bronze_table_identifier(qualified_name: str) -> str:
    """Turn 'bronze.inbound_company_raw' from config into a checked, quoted table name."""
    if not re.fullmatch(r"[a-z_][a-z0-9_]*\.[a-z_][a-z0-9_]*", qualified_name):
        raise ValueError(f"invalid bronze table name in config.pipeline: {qualified_name!r}")
    return ".".join(_quoted(part) for part in qualified_name.split("."))


def _retry_only_transient_errors(task, task_run, state) -> bool:
    """Prefect retry condition: retry connection-type errors, never a bad file (ValueError)."""
    return not isinstance(state.result(raise_on_failure=False), ValueError)


@task(retries=2, retry_delay_seconds=30, retry_condition_fn=_retry_only_transient_errors)
def load_file_to_bronze(file_id: int) -> int:
    """Replace this file's rows in its bronze table with the file's rows. Returns the number of rows loaded."""
    logger = get_run_logger()
    try:
        with connect() as conn:  # one transaction: delete + insert + mark loaded
            row = conn.execute(
                """
                SELECT l.file_path, p.pipeline_id, p.source_id, p.bronze_table_name
                  FROM ingestion.file_ingestion_log l
                  JOIN config.pipeline p ON p.pipeline_id = l.pipeline_id
                 WHERE l.file_id = ?
                """,
                (file_id,),
            ).fetchone()
            if row is None:
                raise ValueError(f"file_id {file_id} not found or not routed to a pipeline")
            file_path, pipeline_id, source_id, bronze_table = row

            with open(PROJECT_ROOT / file_path, newline="", encoding="utf-8-sig") as f:
                reader = csv.reader(f)
                header = next(reader)
                rows = list(reader)

            schema, table = bronze_table.split(".")
            table_columns = {r[0] for r in conn.execute(
                "SELECT column_name FROM information_schema.columns WHERE table_schema = ? AND table_name = ?",
                (schema, table),
            ).fetchall()}
            unexpected = [c for c in header if c not in table_columns]
            if unexpected:
                raise ValueError(f"columns not in {bronze_table}: {', '.join(unexpected)}")

            target = _bronze_table_identifier(bronze_table)
            conn.execute(f"DELETE FROM {target} WHERE file_id = ?", (file_id,))
            columns = ", ".join(_quoted(c) for c in _METADATA_COLUMNS + header)
            placeholders = ", ".join(["?"] * (len(_METADATA_COLUMNS) + len(header)))
            if rows:
                conn.executemany(
                    f"INSERT INTO {target} ({columns}) VALUES ({placeholders})",
                    [[f"{file_id}-{row_number}", file_id, row_number, compute_bronze_row_hash(values),
                      pipeline_id, source_id, *values]
                     for row_number, values in enumerate(rows, start=1)],
                )
            conn.execute(
                """
                UPDATE ingestion.file_ingestion_log
                   SET status = 'loaded', loaded_at = now(), last_attempt_at = now(),
                       row_count = ?, failure_reason = NULL
                 WHERE file_id = ?
                """,
                (len(rows), file_id),
            )
        logger.info("file_id %s: loaded %s rows into %s", file_id, len(rows), bronze_table)
        return len(rows)
    except Exception as exc:
        record_file_failure(file_id, f"bronze load failed: {exc}")
        raise
