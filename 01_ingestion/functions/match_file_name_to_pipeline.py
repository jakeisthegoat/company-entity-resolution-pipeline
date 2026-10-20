"""Finds which pipeline an arriving file belongs to, from its original file name.

Routing is configured in config.pipeline_file_pattern: each active row maps a glob pattern
(e.g. `company*.csv`) to an active pipeline. Matching is case-insensitive.

A file must match exactly one pattern. No match, or matches for more than one pipeline, means the
file is unmatched: it is not guessed at.
"""
import fnmatch
from dataclasses import dataclass

import duckdb


@dataclass
class PipelineRoute:
    pipeline_id: int
    pipeline_name: str
    source_id: int
    source_name: str


def match_file_name_to_pipeline(conn: duckdb.DuckDBPyConnection, original_file_name: str) -> tuple[PipelineRoute | None, str]:
    """Return (route, "") when exactly one active pipeline matches, otherwise (None, reason)."""
    patterns = conn.execute(
        """
        SELECT fp.file_pattern, p.pipeline_id, p.pipeline_name, s.source_id, s.source_name
          FROM config.pipeline_file_pattern fp
          JOIN config.pipeline p ON p.pipeline_id = fp.pipeline_id
          JOIN config.source s ON s.source_id = p.source_id
         WHERE fp.is_active AND p.is_active AND s.is_active
        """
    ).fetchall()
    matches = {row[1]: PipelineRoute(*row[1:]) for row in patterns
               if fnmatch.fnmatch(original_file_name.lower(), row[0].lower())}
    if len(matches) == 1:
        return next(iter(matches.values())), ""
    if not matches:
        return None, "file name matches no configured pipeline"
    return None, "file name matches more than one pipeline: " + ", ".join(m.pipeline_name for m in matches.values())
