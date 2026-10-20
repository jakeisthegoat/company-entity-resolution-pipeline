"""Opens connections to the pipeline's DuckDB database. Used by every layer.

The whole database is one file, 00_database/pipeline.duckdb (created by 00_database/create_database.py).
There is no server to run and nothing to configure.

Use `connect()` as a context manager; each `with` block is one transaction:

    with connect() as conn:
        conn.execute(...)

Leaving the `with` block commits; an exception inside it rolls everything back. Layers rely on this to make each
load all-or-nothing.
"""
from contextlib import contextmanager
from pathlib import Path
from typing import Iterator

import duckdb

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DATABASE_FILE = PROJECT_ROOT / "00_database" / "pipeline.duckdb"


@contextmanager
def connect() -> Iterator[duckdb.DuckDBPyConnection]:
    """Open the database in one transaction: commit on a clean exit, roll back on an exception."""
    conn = duckdb.connect(str(DATABASE_FILE))
    conn.begin()
    try:
        yield conn
        conn.commit()
    except BaseException:
        conn.rollback()
        raise
    finally:
        conn.close()
