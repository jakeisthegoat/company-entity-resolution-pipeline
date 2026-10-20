"""QC: runs every active check in config.qc_check after entity resolution. Prefect flow `run-qc`.

Each check is a literal SQL query stored in config.qc_check.check_sql. It returns the rows that break the rule as
(entity_type, entity_id, related_entity_id, transaction_id, detail). Every row is written to qc.check_finding.
For checks with creates_review = true (over- and under-merges), the finding's transaction also gets a review
queue entry, unless it is already in the queue (see _open_review). Nothing is corrected automatically.

Adding, changing or switching off a check is a change to 00_database/01_config/01_seeds/005_qc_check.sql, not code.
"""
from prefect import flow, get_run_logger, task

from shared.database_connection import connect


def _open_review(conn, finding: tuple, check_name: str) -> int | None:
    """Queue a review for the finding, unless its transaction is already in the queue.

    Over-merge findings name the transaction to review, with its own entity as the candidate. Under-merge findings
    name two entities and no transaction: the review is opened on the related entity's first record, with the
    other entity as the candidate.
    """
    entity_type, entity_id, related_entity_id, transaction_id, detail = finding
    candidate = related_entity_id or entity_id
    if transaction_id is None and related_entity_id is not None:
        candidate = entity_id
        transaction_id = conn.execute(
            f"SELECT min(transaction_id) FROM entity_resolution.{entity_type}_alias WHERE {entity_type}_id = ?",
            (related_entity_id,),
        ).fetchone()[0]
    if transaction_id is None or candidate is None:
        return None
    queue = f"entity_resolution.{entity_type}_match_review_queue"
    existing = conn.execute(f"SELECT min({entity_type}_match_review_queue_id) FROM {queue} WHERE transaction_id = ?",
                            (transaction_id,)).fetchone()[0]
    if existing:
        return existing
    return conn.execute(
        f"""
        INSERT INTO {queue} (transaction_id, candidate_{entity_type}_id, candidate_rank, match_score, match_basis)
        VALUES (?, ?, 1, 0, ?)
        RETURNING {entity_type}_match_review_queue_id
        """,
        (transaction_id, candidate, f"QC {check_name}: {detail}"),
    ).fetchone()[0]


@task
def run_checks() -> dict:
    """Run every active check; record its findings (and reviews). Returns the number of findings per check."""
    logger = get_run_logger()
    counts = {}
    with connect() as conn:
        run_at = conn.execute("SELECT now()").fetchone()[0]
        checks = conn.execute(
            "SELECT qc_check_id, check_name, creates_review, check_sql FROM config.qc_check "
            "WHERE is_active ORDER BY qc_check_id"
        ).fetchall()
        for qc_check_id, check_name, creates_review, check_sql in checks:
            # Sorted, so the same data always gives the same findings in the same order (and the same reviews)
            findings = conn.execute(f"SELECT * FROM ({check_sql}) ORDER BY ALL").fetchall()
            for finding in findings:
                review_id = _open_review(conn, finding, check_name) if creates_review else None
                conn.execute(
                    """
                    INSERT INTO qc.check_finding (qc_check_id, run_at, entity_type, entity_id, related_entity_id,
                                                  transaction_id, detail, review_queue_id)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                    """,
                    (qc_check_id, run_at, *finding, review_id),
                )
            counts[check_name] = len(findings)
            logger.info("%s: %s findings", check_name, len(findings))
    return counts


@flow(name="run-qc")
def run_qc() -> dict:
    return run_checks()
