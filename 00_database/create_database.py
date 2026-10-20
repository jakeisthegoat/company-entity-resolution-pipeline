"""Creates (or updates) the pipeline's DuckDB database: every schema, table, view and config row.

    .venv/bin/python 00_database/create_database.py           # create, or bring an existing database up to date
    .venv/bin/python 00_database/create_database.py --fresh   # delete the database file first and start empty

Runs 00_setup, then each numbered schema folder in order, 00_tables/ before 01_seeds/, files in numeric order.
Every script is idempotent (CREATE ... IF NOT EXISTS, CREATE OR REPLACE VIEW, seeds upsert), so it is safe to run
at any time. A schema change is made in the table's CREATE script; run with --fresh to apply it.
"""
import argparse
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from shared.database_connection import DATABASE_FILE, connect  # noqa: E402
from shared.run_sql_files import run_sql_files, sql_files_in_order  # noqa: E402

DATABASE_FOLDER = Path(__file__).resolve().parent


def migration_files() -> list[Path]:
    files = sql_files_in_order(DATABASE_FOLDER / "00_setup")
    for schema_folder in sorted(DATABASE_FOLDER.glob("[0-9][0-9]_*")):
        if schema_folder.name != "00_setup":
            files += sql_files_in_order(schema_folder / "00_tables") + sql_files_in_order(schema_folder / "01_seeds")
    return files


def create_database(fresh: bool = False) -> None:
    if fresh:
        DATABASE_FILE.unlink(missing_ok=True)
    with connect() as conn:
        for path in migration_files():
            print("->", path.relative_to(DATABASE_FOLDER))
            run_sql_files(conn, [path])
    print(f"Database ready: {DATABASE_FILE.relative_to(DATABASE_FOLDER.parent)}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--fresh", action="store_true", help="delete the database file first")
    create_database(parser.parse_args().fresh)
