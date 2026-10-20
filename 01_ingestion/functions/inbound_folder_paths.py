"""Folder layout of inbound/, where source files arrive and wait for bronze.

    inbound/
      landed/                                   files arrive here (dropped by a source system or by hand)
      <source_name>/YYYY-MM-DD/{file_id}_{name}  routed files, one folder per source (config.source.source_name)
      unmatched/YYYY-MM-DD/{file_id}_{name}      files whose name matches no configured pipeline

The date is the day the file was taken in. Every file keeps its original name, prefixed with its file_id,
so two files with the same name never collide.
"""
from datetime import date
from pathlib import Path

from shared.database_connection import PROJECT_ROOT

INBOUND_DIR = PROJECT_ROOT / "inbound"
LANDED_DIR = INBOUND_DIR / "landed"
UNMATCHED_DIR = INBOUND_DIR / "unmatched"


def routed_file_path(source_name: str, file_id: int, original_file_name: str, intake_date: date) -> Path:
    """Where a routed file is stored: inbound/<source_name>/<YYYY-MM-DD>/<file_id>_<original_file_name>."""
    return INBOUND_DIR / source_name / intake_date.isoformat() / f"{file_id}_{original_file_name}"


def unmatched_file_path(file_id: int, original_file_name: str, intake_date: date) -> Path:
    """Where an unmatched file is stored: inbound/unmatched/<YYYY-MM-DD>/<file_id>_<original_file_name>."""
    return UNMATCHED_DIR / intake_date.isoformat() / f"{file_id}_{original_file_name}"


def relative_to_project(path: Path) -> str:
    """Path as stored in ingestion.file_ingestion_log: relative to the project root, so it is portable."""
    return str(path.relative_to(PROJECT_ROOT))
