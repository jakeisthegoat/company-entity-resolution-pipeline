"""Company entity resolution: every silver.company and silver.account transaction gets a company id.
Prefect flow `resolve-companies`, part of the pipeline run (after the silver load, before people).

  1. Match input: each new silver transaction (all versions) is written to company_match_input: one row with one
     normalized value per field (name, domain, phone, city, state, parent_record_key), from the core fields only.
     COMPANY_SOURCES says which silver column feeds each field.
  2. Matching (entity_matching_engine.resolve) with the company rules:
       exact:  same normalized name and same domain or phone -> 100%;
       score:  weights, comparison methods and strong identifiers from config.entity_match_attribute
               (seeded: name 40 token set, domain 30, phone 20, city 5, state 5; strong: domain, phone);
       blocking keys: domain, phone, first word of the name;
       parent/subsidiary rule: a record never joins an entity containing its parent (parent_id) or its subsidiary.
"""

from prefect import flow, get_run_logger, task

from shared.database_connection import connect
from . import normalize_match_values as normalize
from .entity_matching_engine import MatchDomain, Txn, resolve, same, write_match_input

# Which core silver column feeds each match field, per silver table. One value per field: Salesforce ss_* fields
# (and the provider's informal_name) are not matched on; ss_* stay in silver for QC's core-vs-ss conflict check.
# parent_record_key is not scored: it feeds the parent/subsidiary rule.
COMPANY_SOURCES = {
    "silver.company": {"name": "name", "domain": "domain", "phone": "phone_number", "city": "city",
                       "state": "state", "parent_record_key": "parent_id"},
    "silver.account": {"name": "name", "domain": "domain", "phone": "phone", "city": "billing_city",
                       "state": "billing_state"},
}

NORMALIZERS = {
    "name": normalize.company_name,
    "domain": normalize.domain,
    "phone": normalize.phone,
    "city": normalize.text,
    "state": normalize.text,
}


def _is_exact(a: Txn, b: Txn) -> bool:
    va, vb = a.values, b.values
    return same(va["name"], vb["name"]) and (same(va["domain"], vb["domain"]) or same(va["phone"], vb["phone"]))


def _blocking_keys(t: Txn) -> set[str]:
    """Candidates share a domain, a phone or the first word of the name."""
    v = t.values
    return {key for key in (v["domain"] and f"domain:{v['domain']}", v["phone"] and f"phone:{v['phone']}",
                            v["name"] and f"name:{v['name'].split()[0]}") if key}


COMPANY = MatchDomain(
    name="company",
    input_columns={"name": "name", "domain": "domain", "phone": "phone", "city": "city", "state": "state",
                   "parent_record_key": "parent_record_key"},
    is_exact=_is_exact,
    exact_basis="exact: same name and domain or phone",
    blocking_keys=_blocking_keys,
)


@task
def build_company_match_input() -> int:
    """Add every new silver company/account transaction (all versions) to the match input."""
    added = 0
    with connect() as conn:
        for table, fields in COMPANY_SOURCES.items():
            columns = list(fields.values())
            rows = []
            for txn_id, key, version, source_id, arrival_time, row_number, *raw in conn.execute(
                f"""
                SELECT s.transaction_id, s.source_record_key, s.source_record_version, s.source_id, l.arrival_time,
                       split_part(s.transaction_id, '-', 2)::int,  -- transaction_id = file_id-row_number
                       {", ".join("s." + c for c in columns)}
                  FROM {table} s
                  JOIN ingestion.file_ingestion_log l ON l.file_id = s.file_id
                 WHERE NOT EXISTS (SELECT 1 FROM entity_resolution.company_match_input i
                                    WHERE i.transaction_id = s.transaction_id)
                """
            ).fetchall():
                record = dict(zip(fields, raw))
                values = {field: NORMALIZERS[field](record[field]) for field in fields if field in NORMALIZERS}
                if record.get("parent_record_key"):
                    values["parent_record_key"] = f"{source_id}-{record['parent_record_key']}"
                rows.append((txn_id, key, version, source_id, arrival_time, row_number, values))
            write_match_input(conn, COMPANY, rows)
            added += len(rows)
    return added


@task
def match_companies() -> dict:
    return resolve(COMPANY)


@flow(name="resolve-companies")
def resolve_companies() -> dict:
    get_run_logger().info("Company match input: %s new transactions", build_company_match_input())
    return match_companies()
