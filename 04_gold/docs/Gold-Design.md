# Gold Design

What gets published. A **full refresh** on every run, built in SQL from the **latest version** of each source record. The layer's **orchestrator** is [load_gold.py](../load_gold.py) (Prefect flow `load-gold`): in one transaction it empties gold, runs the build steps in [sql/](../sql/) in order (one file per step: `001_company`, `002_build_affiliations`, `003_person`, `004_person_company`, `005_crosswalk`), then the tests in [tests/](../tests/). Tables: `00_database/07_gold/00_tables/`. Back to [Pipeline Design](../../docs/design/Pipeline-Design.md).

## Tables

| Table | Grain | Purpose |
|---|---|---|
| `gold.company` | One row per company | The final companies table |
| `gold.person` | One row per person | The final people table, with their primary affiliation |
| `gold.person_company` | One row per person × company | All affiliations, de-duplicated |
| `gold.crosswalk` | One row per company source record | Every raw company id and Salesforce account → its company |
| `gold.part1_company` (view) | One row per company with a Part 1 record | The Part 1 companies table: `gold.company` without the Salesforce-only companies |
| `gold.data_quality_summary` (view) | One row per metric | Rows in vs out for companies, people and links, records pending review, and each QC check's findings in the latest run. Logged at the end of every gold build |

## Join path

```
silver (is_latest_version) → <domain>_match_result ON transaction_id → <domain>_master
```

## Picking values (survivorship)

When several source records form one entity, each attribute takes the **first non-null value** by:

1. Source priority: the source's `resolution_order` in `config.entity_resolution_order` (provider feed first, then Salesforce). The order used for matching is also the order for picking values, so there is one setting, per entity type.
2. Most recent: file arrival time, then row number.

This follows from the brief's structure: Part 1 is resolved first and is the reference, so its golden record is the master and Salesforce enriches it (fills what Part 1 lacks).

**Address as a group:** `city`, `state`, `postal_code` and `country` are taken together from **one** record (the highest-priority, most recent record with any address value), so a company never gets a city from one source and a state from another.

## `gold.company`

| Column | From |
|---|---|
| `company_id` | Master id |
| `company_name` | `company.name`, `account.name` |
| `informal_name` | `company.informal_name` |
| `website`, `domain` | `company`, `account` |
| `phone` | `company.phone_number`, `account.phone` |
| `city`, `state`, `country` | `company`, `account.billing_*` |
| `postal_code`, `total_amount_invested` | `company` |
| `founding_year` | `company.founding_year`, `account.ss_year_founded` |
| `parent_company_name` | `company.parent_company` |
| `parent_company_id` | `parent_id` resolved through `company_alias` |
| `source_record_count`, `sources_present`, `is_pending_review` | Computed |

Salesforce `ss_*` fields are neither matched on nor published; they stay in silver for QC.

## `gold.person` and `gold.person_company`

**`gold.person_company`:** silver links with person and company resolved to master ids. Duplicate person × company pairs keep one row: the most complete, then the latest `modified_date`. `is_current` = `end_date` is NULL **or in the future**. People linked to a company id that was merged away automatically point to the surviving company.

**`gold.person`:** names, LinkedIn and location by survivorship, plus a **primary affiliation** (`company_id`, `title`, `email`, `phone`, `start_date`, `end_date`, `is_current`): a current one first, then the latest `start_date`. Also `affiliation_count` and `is_pending_review`.

## `gold.crosswalk`

The Part 2 crosswalk, exactly as the brief specifies: one row per **company** source record (latest version), covering both sources completely: every raw Part 1 company id and every `account.csv` row, matched or not. A company that was two raw Part 1 rows contributes two rows, which preserves the merge lineage. People are not in the crosswalk (the brief asks for companies; person lineage is in `entity_resolution.person_alias`).

| Column | Description |
|---|---|
| `crosswalk_id` | The company's master id (`CMP-…`), shared by every source record of the same real-world company; FK → `gold.company` |
| `source_system` | `part1_company` or `salesforce` (the brief's literal values) |
| `source_record_id` | That system's own record id (PK with `source_system`) |
| `source_name` | The company name as it appears in that system |
| `presence` | `both` / `part1_only` / `salesforce_only`: which systems the company is in |
| `match_confidence` | 0–100, only when `presence = both`: the Salesforce account's match onto the Part 1 company (every row of that company shows it). Blank on single-source rows |
| `match_basis` | What that match rests on, e.g. `exact: same name and domain or phone` or `name 100%, domain match, phone match, …`. Blank on single-source rows |
| `needs_review` | The company has a pending review; how uncertain records are flagged, since their confidence is blank by rule |

A third source adds rows with a new `source_system` value; the schema doesn't change. "How many companies are in both systems vs. only one, and which one" is `count(DISTINCT crosswalk_id)` by `presence`.

## Tests

Run after every build, in the same transaction: if any test returns a row, the build is rolled back and the previously published gold stays as it was.

| Test | Table |
|---|---|
| `company_id` unique and not null | `gold.company` |
| No domain appears twice, among companies not pending review (a shared domain under review is the reason for the review) | `gold.company` |
| `person_id` unique and not null | `gold.person` |
| Every `company_id` exists in `gold.company` | `gold.person`, `gold.person_company` |
| One row per person × company | `gold.person_company` |
| Every raw Part 1 company id and every Salesforce account appears exactly once, and the counts match the raw inputs | `gold.crosswalk` |
| `presence` matches the sources on each `crosswalk_id` | `gold.crosswalk` |
| Match columns blank exactly on single-source rows | `gold.crosswalk` |

## Results on the assessment data

| Table | Rows |
|---|---|
| `gold.company` | 1,017 |
| `gold.part1_company` (view) | 1,005 |
| `gold.person` | 1,869 (1,345 with a current primary affiliation) |
| `gold.person_company` | 1,870 (1,983 links minus 113 duplicate person × company pairs) |
| `gold.crosswalk` | 1,124 (1,024 Part 1 company ids + 100 Salesforce accounts) |

| Companies | Count |
|---|---|
| In both systems | 88 |
| Provider only | 917 |
| Salesforce only | 12 |

All 8 tests pass.

