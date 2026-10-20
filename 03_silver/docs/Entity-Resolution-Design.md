# Entity Resolution Design

Resolves every company and person transaction to a master id. Companies run first, then people (person matching uses the resolved company). Tables: `00_database/05_entity_resolution/00_tables/`. Back to [Pipeline Design](../../docs/design/Pipeline-Design.md).

Tunable values are read from config at the start of each run ([matching settings](../../00_database/01_config/README.md#matching-settings)): thresholds and review candidates from `config.entity_match_setting`; each attribute's weight, comparison method, strong-identifier flag and common-word cut-off from `config.entity_match_attribute`. Exact-match rules, blocking keys and normalization are in code.

| Code | Purpose |
|---|---|
| [normalize_match_values.py](../functions/normalize_match_values.py) | Match-only normalization |
| [entity_matching_engine.py](../functions/entity_matching_engine.py) | The matching engine shared by companies and people: exact, score, bands, chaining guard, review |
| [resolve_company_entities.py](../functions/resolve_company_entities.py) | Prefect flow `resolve-companies`: company match input + company rules |
| [resolve_person_entities.py](../functions/resolve_person_entities.py) | Prefect flow `resolve-people`: person match input + person rules |

## Inputs

Each transaction (all versions) is written to `<domain>_match_input` as one row with one value per field, from the core fields only:

| Domain | Fields | From |
|---|---|---|
| Company | `name`, `domain`, `phone`, `city`, `state`, `parent_record_key` (not scored) | `silver.company`: `name`, `domain`, `phone_number`, `city`, `state`, `parent_id`. `silver.account`: `name`, `domain`, `phone`, `billing_city`, `billing_state` |
| Person | `first_name`, `last_name`, `linkedin`, `email`, `company_id` | `silver.person`; email and resolved company (through `company_alias`) from the person's primary affiliation in `silver.person_company`: a current one first, then the latest start date |

Salesforce `ss_*` fields and the provider's `informal_name` are not matched on.

**Normalization** (match input only, never written back to silver):

| Field | Normalization |
|---|---|
| Company name | Lowercase, `&` → `and`, punctuation removed |
| Domain | URL or domain → bare domain (`https://www.Example.com/about` → `example.com`) |
| Phone | Digits only, last 10 digits; fewer than 10 → no value |
| LinkedIn | Lowercase, no scheme, `www.` or trailing slash |
| City, state, names, email | Trimmed, lowercase |

**Common words:** at the start of each run, the engine counts the share of company names each word appears in and ignores words found in at least `common_word_pct` % of names (2%) when comparing. A name made only of common words is compared whole. The stored match input keeps every word. Code: `drop_common_words`.

## Matching

Transactions are processed one at a time, each against everything already resolved (including earlier transactions in the same run).

1. **Candidates:** entities with a member that shares a blocking key with the transaction.
2. **Compare** with each candidate entity:
   - a candidate containing the record's parent or subsidiary is blocked (see below);
   - an exact match to any member scores 100%;
   - otherwise the score is the best score against any member.
3. **Band:**

| Band | Rule | Outcome |
|---|---|---|
| **Exact** | Exactly one candidate matches exactly, and it is not pending review | Gets that entity's id |
| **Auto-match** | Best score ≥ 90%, a strong identifier agrees, and no member of the entity scores below 70% (chaining guard) | Gets that entity's id |
| **Review** | Best score 70–89%; or ≥ 90% failing the strong-identifier or chaining rule; or more than one exact candidate; or the best candidate is pending review; or a blocked candidate scores ≥ 70% | New id, plus up to 3 candidates in the review queue |
| **New** | Anything else | New id |

**Score** = weighted average of attribute similarities × 100, over the attributes both records have. A missing value counts neither for nor against.

### Companies

**Exact:** same name (after common words are dropped) **and** same domain or phone.

| Attribute | Weight | Comparison | Strong identifier |
|---|---|---|---|
| Name | 40 | Token set similarity | |
| Domain | 30 | Exact | Yes |
| Phone | 20 | Exact | Yes |
| City | 5 | Exact | |
| State | 5 | Exact | |

**Blocking keys:** domain, phone, first word of the name.

### People

**Exact:** same LinkedIn URL, **or** same email, **or** same first and last name at the same resolved company.

| Attribute | Weight | Comparison | Strong identifier |
|---|---|---|---|
| Last name | 30 | Jaro-Winkler | |
| First name | 20 | Jaro-Winkler | |
| LinkedIn | 20 | Exact | Yes |
| Email | 15 | Exact | Yes |
| Resolved company | 30 | Exact | |

**Blocking keys:** LinkedIn, email, last name + first initial.

## Order

Unresolved transactions are processed by **resolution order** (`config.entity_resolution_order`), then file arrival time, then row number:

- **Companies:** the provider feed (order 1) is resolved among itself first (the Part 1 deduplication), then Salesforce (order 2) is matched onto it.
- **People:** the provider feed only.
- A source with no row for the entity type is processed last.

Transactions that already have a result are skipped, so earlier decisions are never re-scored. Restatements (new versions of a source record) go through the same process.

## Parent / subsidiary rule

Parent is not scored. It is a blocking rule, checked against every member of a candidate entity:

- a record never joins an entity that contains **its parent** (`parent_record_key` = `"{source_id}-{parent_id}"`, from the latest version);
- a record never joins an entity that contains **its subsidiary** (a member whose parent is this record).

A blocked candidate is skipped. If it scored ≥ 70%, the record goes to review with basis `blocked: candidate contains this record's parent/subsidiary`. Code: `parent_block_reason`.

## Tables (per domain; company shown, person identical)

| Table | Grain | Purpose |
|---|---|---|
| `company_master` | One row per master id | Defines each id (`CMP-000001`) and `is_active` |
| `company_match_input` | One row per transaction | Ordering fields plus one normalized value per field |
| `company_match_result` | One row per transaction | `company_id`, `match_score`, `match_band`, `match_basis`, `matched_transaction_id`, `decided_by` (`system`), `decided_at` |
| `company_match_review_queue` | One row per transaction × candidate (up to 3) | Manual review: candidate, score, basis, `review_status` (`pending` / `confirmed_match` / `confirmed_new`) |
| `company_alias` (view) | One row per source record | Source record → master id, using its latest version; `is_pending_review` while it has a pending queue row. Inactive ids excluded. Used by person matching, QC and gold |

Ids are never reused or renumbered.

## Manual review

A transaction sent to review gets its own new id and is pending until reviewed; gold flags it `is_pending_review`. A later transaction whose best candidate is pending also goes to review. QC over- and under-merge findings are added to the same queue.

Applying review decisions is not built: the pipeline writes the queue, but nothing reads `review_status` back to move or retire ids.
