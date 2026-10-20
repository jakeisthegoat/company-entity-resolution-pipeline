"""Person entity resolution: every silver.person transaction gets a person id.
Prefect flow `resolve-people`, part of the pipeline run (after company resolution, which it depends on).

  1. Match input: each new silver person (all versions) is written to person_match_input: one row with one value
     per field: first name, last name, LinkedIn, and the email and resolved company id (through
     entity_resolution.company_alias) of the person's primary affiliation in silver.person_company: a current
     one first, then the latest start date (latest versions only).
  2. Matching (entity_matching_engine.resolve) with the person rules:
       exact:  same LinkedIn, or same email, or same first and last name at the same resolved company;
       score:  weights, comparison methods and strong identifiers from config.entity_match_attribute
               (seeded: last name 30, first name 20 Jaro-Winkler, LinkedIn 20, email 15, resolved company 30;
               strong: LinkedIn, email);
       blocking keys: LinkedIn, email, last name + first initial.
"""

from prefect import flow, get_run_logger, task

from shared.database_connection import connect
from . import normalize_match_values as normalize
from .entity_matching_engine import MatchDomain, Txn, resolve, same, write_match_input


def _is_exact(a: Txn, b: Txn) -> bool:
    va, vb = a.values, b.values
    return (same(va["linkedin"], vb["linkedin"]) or same(va["email"], vb["email"])
            or (same(va["first_name"], vb["first_name"]) and same(va["last_name"], vb["last_name"])
                and same(va["company"], vb["company"])))


def _blocking_keys(t: Txn) -> set[str]:
    """Candidates share a LinkedIn, an email, or the last name and first initial."""
    v = t.values
    both_names = v["last_name"] and v["first_name"]
    return {key for key in (v["linkedin"] and f"linkedin:{v['linkedin']}", v["email"] and f"email:{v['email']}",
                            both_names and f"name:{v['last_name']}|{v['first_name'][0]}") if key}


PERSON = MatchDomain(
    name="person",
    input_columns={"first_name": "first_name", "last_name": "last_name", "linkedin": "linkedin",
                   "email": "email", "company": "company_id"},
    is_exact=_is_exact,
    exact_basis="exact: same LinkedIn, email, or name at the same company",
    blocking_keys=_blocking_keys,
)


@task
def build_person_match_input() -> int:
    """Add every new silver person transaction (all versions) to the match input.
    Email and resolved company come from the person's primary affiliation (current first, then latest start)."""
    with connect() as conn:
        rows = []
        for (txn_id, key, version, source_id, arrival_time, row_number,
             first_name, last_name, linkedin, email, company_id) in conn.execute(
            """
            SELECT p.transaction_id, p.source_record_key, p.source_record_version, p.source_id, l.arrival_time,
                   split_part(p.transaction_id, '-', 2)::int,  -- transaction_id = file_id-row_number
                   p.first_name, p.last_name, p.linkedin, pa.email, pa.company_id
              FROM silver.person p
              JOIN ingestion.file_ingestion_log l ON l.file_id = p.file_id
              LEFT JOIN LATERAL (
                    SELECT pc.email, a.company_id
                      FROM silver.person_company pc
                      LEFT JOIN entity_resolution.company_alias a
                        ON a.source_record_key = pc.source_id || '-' || pc.company_id
                     WHERE pc.is_latest_version AND pc.source_id = p.source_id AND pc.person_id = p.source_record_id
                     ORDER BY (pc.end_date IS NULL OR pc.end_date > current_date) DESC,
                              pc.start_date DESC NULLS LAST, pc.transaction_id
                     LIMIT 1) pa ON true
             WHERE NOT EXISTS (SELECT 1 FROM entity_resolution.person_match_input i WHERE i.transaction_id = p.transaction_id)
            """
        ).fetchall():
            values = {
                "first_name": normalize.text(first_name),
                "last_name": normalize.text(last_name),
                "linkedin": normalize.linkedin(linkedin),
                "email": normalize.text(email),
                "company": company_id,
            }
            rows.append((txn_id, key, version, source_id, arrival_time, row_number, values))
        write_match_input(conn, PERSON, rows)
    return len(rows)


@task
def match_people() -> dict:
    return resolve(PERSON)


@flow(name="resolve-people")
def resolve_people() -> dict:
    get_run_logger().info("Person match input: %s new transactions", build_person_match_input())
    return match_people()
