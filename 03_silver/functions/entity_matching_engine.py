"""Matching engine shared by company and person resolution.

resolve(domain) gives every transaction without a result a master id, one transaction at a time, comparing it
with everything already resolved (including earlier transactions in the same run). Order: the source's
resolution_order (config.entity_resolution_order), then file arrival, then row number, so the reference source
(Part 1) is resolved among itself first and Salesforce is then matched onto it.

Every tunable value is read from config at the start of the run (load_match_settings): the id prefix, the
thresholds and the number of review candidates (config.entity_match_setting), and each attribute's weight,
comparison method, strong-identifier flag and common-word cut-off (config.entity_match_attribute). Code holds only
the logic.

For each transaction (decide()):
  1. Find candidate entities that share a blocking key (CandidatePool.candidates).
  2. Compare with each candidate (compare_with_candidates):
       - a candidate containing the record's parent or subsidiary is blocked (parent_block_reason);
       - an exact match to any member scores 100%;
       - otherwise the candidate's score is its best-scoring member.
  3. Pick a band:
       exact       exactly one exact candidate, not pending review
       auto_match  best score >= auto_match_threshold, a strong identifier agrees, and no member scores below
                   review_threshold (chaining guard)
       review      score >= review_threshold otherwise, more than one exact candidate, the best candidate is pending review,
                   or a strong match to a blocked candidate
       new         anything else
  4. exact / auto_match join the candidate; review and new get a new id (review also gets queue rows).
"""
from collections import Counter, defaultdict
from dataclasses import dataclass
from typing import Callable

from prefect import get_run_logger
from rapidfuzz.distance import JaroWinkler
from rapidfuzz.fuzz import token_set_ratio

from shared.database_connection import connect


@dataclass
class Txn:
    """One transaction's match values: attribute -> value, or None when missing (missing = no evidence)."""
    transaction_id: str
    source_record_key: str
    values: dict[str, str | None]


def same(a: str | None, b: str | None) -> bool:
    """Both values present and equal. A missing value never matches."""
    return a is not None and a == b


# Comparison methods (config.entity_match_attribute.comparison_method): two values -> similarity 0-1.
COMPARISON_METHODS: dict[str, Callable[[str, str], float]] = {
    "exact": lambda a, b: 1.0 if a == b else 0.0,
    "token_set": lambda a, b: token_set_ratio(a, b) / 100,             # word sets: company names
    "jaro_winkler": lambda a, b: JaroWinkler.normalized_similarity(a, b),  # characters: person names
}


@dataclass
class MatchDomain:
    """The logic for one entity type (company or person). Defined in resolve_company_entities / _person_."""
    name: str                                        # 'company' or 'person': table prefix, id column, config key
    input_columns: dict[str, str]                    # match attribute -> column in <name>_match_input
    is_exact: Callable[[Txn, Txn], bool]
    exact_basis: str
    blocking_keys: Callable[[Txn], set[str]]


@dataclass
class MatchAttribute:
    name: str
    weight: float
    comparison_method: str
    is_strong_identifier: bool
    common_word_pct: float | None  # ignore words found in at least this % of values (None: keep all)


@dataclass
class MatchSettings:
    """The tunable values for one entity type, from config.entity_match_setting and config.entity_match_attribute."""
    id_prefix: str
    auto_match_threshold: float
    review_threshold: float
    review_candidates: int
    attributes: list[MatchAttribute]

    def score(self, a: Txn, b: Txn) -> tuple[float, bool, str]:
        """Weighted similarity 0-100 over attributes both have; whether a strong identifier agrees; basis text."""
        numerator = denominator = 0.0
        strong = False
        basis = []
        for attribute in self.attributes:
            va, vb = a.values[attribute.name], b.values[attribute.name]
            if va is None or vb is None:
                continue  # missing on either side: no evidence either way
            similarity = COMPARISON_METHODS[attribute.comparison_method](va, vb)
            basis.append(f"{attribute.name} {'match' if similarity else 'differs'}"
                         if attribute.comparison_method == "exact"
                         else f"{attribute.name} {round(similarity * 100)}%")
            numerator += attribute.weight * similarity
            denominator += attribute.weight
            strong = strong or (attribute.is_strong_identifier and va == vb)
        return (round(100 * numerator / denominator, 2) if denominator else 0.0), strong, ", ".join(basis)


def load_match_settings(conn, domain: MatchDomain) -> MatchSettings:
    """Read this entity type's settings and attributes from config."""
    row = conn.execute(
        "SELECT id_prefix, auto_match_threshold, review_threshold, review_candidates "
        "FROM config.entity_match_setting WHERE entity_type = ?", (domain.name,)
    ).fetchone()
    if row is None:
        raise ValueError(f"No config.entity_match_setting row for {domain.name}")
    attributes = [
        MatchAttribute(name, float(weight), method, strong, None if pct is None else float(pct))
        for name, weight, method, strong, pct in conn.execute(
            "SELECT attribute_name, weight, comparison_method, is_strong_identifier, common_word_pct "
            "FROM config.entity_match_attribute WHERE entity_type = ? ORDER BY weight DESC, attribute_name", (domain.name,)
        ).fetchall()
    ]
    unknown = [a.name for a in attributes if a.name not in domain.input_columns]
    if unknown:
        raise ValueError(f"config.entity_match_attribute names {unknown}, not in {domain.name}_match_input")
    return MatchSettings(row[0], float(row[1]), float(row[2]), row[3], attributes)


def parent_block_reason(txn: Txn, entity_members: list[Txn]) -> str | None:
    """Why `txn` may not join this entity, or None. A subsidiary is its own company (the brief), so a record never
    joins an entity containing its parent (its 'parent_record_key') or its subsidiary (a member whose parent it is).
    """
    if any(same(txn.values.get("parent_record_key"), m.source_record_key) for m in entity_members):
        return "candidate contains this record's parent"
    if any(same(m.values.get("parent_record_key"), txn.source_record_key) for m in entity_members):
        return "candidate contains this record's subsidiary"
    return None


# ---------------------------------------------------------------------------------------------------------------
# Reading and writing the match input
# ---------------------------------------------------------------------------------------------------------------

def write_match_input(conn, domain: MatchDomain, rows: list[tuple]) -> None:
    """Insert one <domain>_match_input row per transaction. rows: (transaction_id, source_record_key, version,
    source_id, arrival_time, row_number, values), where values maps each match attribute to its value (or None)."""
    if not rows:
        return
    attributes = list(domain.input_columns)
    columns = ", ".join(domain.input_columns[a] for a in attributes)
    placeholders = ", ".join(["?"] * (6 + len(attributes)))
    conn.executemany(
        f"""
        INSERT INTO entity_resolution.{domain.name}_match_input
            (transaction_id, source_record_key, source_record_version, source_id, arrival_time, row_number, {columns})
        VALUES ({placeholders})
        """,
        [(*r[:6], *(r[6].get(a) for a in attributes)) for r in rows],
    )


def load_match_input(conn, domain: MatchDomain) -> dict[str, Txn]:
    """Read <domain>_match_input into Txn objects, keyed by transaction_id."""
    attributes = list(domain.input_columns)
    return {
        txn_id: Txn(txn_id, source_record_key, dict(zip(attributes, columns)))
        for txn_id, source_record_key, *columns in conn.execute(
            f"SELECT transaction_id, source_record_key, {', '.join(domain.input_columns[a] for a in attributes)} "
            f"FROM entity_resolution.{domain.name}_match_input"
        ).fetchall()
    }


def drop_common_words(txns: dict[str, Txn], attribute: MatchAttribute) -> None:
    """Remove the words found in at least common_word_pct % of this attribute's values ("inc", "llc", "the" in
    company names): they appear everywhere, so they say nothing about which entity a value names. Computed from
    the data, so no word list is kept. A value made only of common words is kept whole."""
    values = [t.values[attribute.name] for t in txns.values() if t.values[attribute.name] is not None]
    if not values:
        return
    words_per_value = Counter(w for v in values for w in set(v.split()))
    common = {w for w, n in words_per_value.items() if 100 * n / len(values) >= attribute.common_word_pct}
    for t in txns.values():
        value = t.values[attribute.name]
        if value is not None:
            t.values[attribute.name] = " ".join(w for w in value.split() if w not in common) or value


# ---------------------------------------------------------------------------------------------------------------
# Matching one transaction
# ---------------------------------------------------------------------------------------------------------------

class CandidatePool:
    """Everything already resolved: entity -> members, plus a blocking-key index to find candidates quickly.
    An entity is 'pending' while the record that created it is waiting in the review queue."""

    def __init__(self, domain: MatchDomain):
        self.domain = domain
        self.members: dict[str, list[Txn]] = defaultdict(list)
        self.entity_of: dict[str, str] = {}
        self.index: dict[str, set[str]] = defaultdict(set)
        self.pending: set[str] = set()

    def add(self, txn: Txn, entity_id: str, is_pending: bool = False) -> None:
        self.members[entity_id].append(txn)
        self.entity_of[txn.transaction_id] = entity_id
        if is_pending:
            self.pending.add(entity_id)
        for key in self.domain.blocking_keys(txn):
            self.index[key].add(txn.transaction_id)

    def candidates(self, txn: Txn) -> set[str]:
        """Entities with at least one member sharing a blocking key with txn."""
        return {self.entity_of[t] for key in self.domain.blocking_keys(txn) for t in self.index[key]}


@dataclass
class Candidate:
    entity_id: str
    score: float
    basis: str
    member: str                  # the member transaction it matched best
    strong: bool = True          # a strong identifier agrees (exact matches always do)
    weakest: float = 100.0       # lowest score against any member (chaining guard)


@dataclass
class Decision:
    band: str                    # exact / auto_match / review / new
    entity_id: str | None        # the entity joined (exact, auto_match); None means a new id
    score: float
    basis: str
    matched_transaction_id: str | None
    review_candidates: list[Candidate]


def compare_with_candidates(domain: MatchDomain, settings: MatchSettings, txn: Txn, pool: CandidatePool):
    """Compare txn with every candidate entity. Returns (exact, scored, blocked) candidate lists, best first."""
    exact, scored, blocked = [], [], []
    for entity_id in pool.candidates(txn):
        members = pool.members[entity_id]
        exact_member = next((m for m in members if domain.is_exact(txn, m)), None)
        if exact_member:
            candidate = Candidate(entity_id, 100.0, domain.exact_basis, exact_member.transaction_id)
        else:
            scores = [(settings.score(txn, m), m) for m in members]
            (best, strong, basis), best_member = max(scores, key=lambda s: s[0][0])
            candidate = Candidate(entity_id, best, basis, best_member.transaction_id, strong,
                                  min(s[0][0] for s in scores))
        reason = parent_block_reason(txn, members)
        if reason:
            candidate.basis += f"; blocked: {reason}"
            blocked.append(candidate)
        else:
            (exact if exact_member else scored).append(candidate)
    for group in (exact, scored, blocked):
        group.sort(key=lambda c: c.score, reverse=True)
    return exact, scored, blocked


def decide(domain: MatchDomain, settings: MatchSettings, txn: Txn, pool: CandidatePool) -> Decision:
    """Pick the band for one transaction (see the module docstring for the rules)."""
    exact, scored, blocked = compare_with_candidates(domain, settings, txn, pool)
    auto, review_at = settings.auto_match_threshold, settings.review_threshold
    ranked = exact + scored
    top = ranked[0] if ranked else None

    def review(basis: str, candidates: list[Candidate] = ranked) -> Decision:
        return Decision("review", None, candidates[0].score, basis, candidates[0].member, candidates)

    if len(exact) == 1 and top.entity_id not in pool.pending:
        return Decision("exact", top.entity_id, 100.0, top.basis, top.member, [])
    if exact:
        return review("exact match to more than one entity" if len(exact) > 1 else f"{top.basis}; entity is pending review")
    if top and top.entity_id in pool.pending and top.score >= review_at:
        return review(f"{top.basis}; entity is pending review")
    if top and top.score >= auto and top.strong and top.weakest >= review_at:
        return Decision("auto_match", top.entity_id, top.score, top.basis, top.member, [])
    if top and top.score >= review_at:
        reason = "" if top.score < auto else (
            "; no strong identifier agrees" if not top.strong else "; chaining guard: weak member pair")
        return review(top.basis + reason)
    if blocked and blocked[0].score >= review_at:  # strong match to a parent/subsidiary: a person decides
        return review(blocked[0].basis, blocked + ranked)
    return Decision("new", None, top.score if top else 0.0,
                    f"best candidate {top.score}%" if top else "no candidates", None, [])


# ---------------------------------------------------------------------------------------------------------------
# Resolving a domain
# ---------------------------------------------------------------------------------------------------------------

def resolve(domain: MatchDomain) -> dict:
    """Resolve every transaction of this domain that has no result yet, in one database transaction."""
    d = domain.name
    with connect() as conn:
        settings = load_match_settings(conn, domain)
        txns = load_match_input(conn, domain)
        for attribute in settings.attributes:
            if attribute.common_word_pct:
                drop_common_words(txns, attribute)

        pool = CandidatePool(domain)
        for txn_id, entity_id, is_pending in conn.execute(
            f"""
            SELECT r.transaction_id, r.{d}_id,
                   r.match_band = 'review' AND EXISTS (SELECT 1 FROM entity_resolution.{d}_match_review_queue q
                                                        WHERE q.transaction_id = r.transaction_id
                                                          AND q.review_status = 'pending')
              FROM entity_resolution.{d}_match_result r
              JOIN entity_resolution.{d}_master m ON m.{d}_id = r.{d}_id
             WHERE m.is_active
            """
        ).fetchall():
            pool.add(txns[txn_id], entity_id, is_pending)

        unresolved = [r[0] for r in conn.execute(
            f"""
            SELECT i.transaction_id
              FROM entity_resolution.{d}_match_input i
              LEFT JOIN config.entity_resolution_order o
                ON o.entity_type = ? AND o.source_id = i.source_id AND o.is_active
             WHERE NOT EXISTS (SELECT 1 FROM entity_resolution.{d}_match_result r WHERE r.transaction_id = i.transaction_id)
             ORDER BY o.resolution_order NULLS LAST, i.arrival_time, i.row_number
            """,
            (d,),
        ).fetchall()]
        next_seq = conn.execute(
            f"SELECT COALESCE(max(split_part({d}_id, '-', 2)::int), 0) + 1 FROM entity_resolution.{d}_master"
        ).fetchone()[0]

        new_ids, results, reviews, counts = [], [], [], defaultdict(int)
        for txn_id in unresolved:
            decision = decide(domain, settings, txns[txn_id], pool)
            entity_id = decision.entity_id
            if entity_id is None:  # review or new: a new master id
                entity_id = f"{settings.id_prefix}-{next_seq:06d}"
                next_seq += 1
                new_ids.append((entity_id,))
            pool.add(txns[txn_id], entity_id, is_pending=decision.band == "review")
            results.append((txn_id, entity_id, decision.score, decision.band, decision.basis,
                            decision.matched_transaction_id))
            for rank, c in enumerate(decision.review_candidates[:settings.review_candidates], start=1):
                reviews.append((txn_id, c.entity_id, c.member, rank, c.score, c.basis))
            counts[decision.band] += 1

        if new_ids:
            conn.executemany(f"INSERT INTO entity_resolution.{d}_master ({d}_id) VALUES (?)", new_ids)
        if results:
            conn.executemany(
                f"""INSERT INTO entity_resolution.{d}_match_result
                        (transaction_id, {d}_id, match_score, match_band, match_basis, matched_transaction_id)
                    VALUES (?, ?, ?, ?, ?, ?)""",
                results,
            )
        if reviews:
            conn.executemany(
                f"""INSERT INTO entity_resolution.{d}_match_review_queue
                        (transaction_id, candidate_{d}_id, candidate_transaction_id, candidate_rank, match_score, match_basis)
                    VALUES (?, ?, ?, ?, ?, ?)""",
                reviews,
            )
    get_run_logger().info("%s matching: %s", d.capitalize(), dict(counts))
    return dict(counts)
