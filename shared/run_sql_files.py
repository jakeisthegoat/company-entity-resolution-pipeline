"""Runs SQL step files in order on one connection. Used by 00_database (create the database), 03_silver (load
steps) and 04_gold (build steps and tests).

Files run in name order (01_…, 02_…), so a folder's numbering is its execution order. They share the caller's
transaction, so a temp table created by one step (e.g. silver's `stg`, gold's `affiliation`) is visible to the
next, and any failure rolls every step back.
"""
from pathlib import Path

import duckdb


def sql_files_in_order(folder: Path) -> list[Path]:
    """The .sql files in `folder`, in execution (name) order."""
    return sorted(folder.glob("*.sql"))


def run_sql_files(conn: duckdb.DuckDBPyConnection, files: list[Path]) -> None:
    """Execute each file, in the given order, on `conn` (no commit: the caller owns the transaction)."""
    for path in files:
        conn.execute(path.read_text())
