# Part 1 Write Up

## How did you detect and resolve duplicate companies? What signal(s) did you use, and what would you do differently with 100x the data?

* After being loaded into the silver layer, every company record goes through the entity matching process.
* Each record is only compared to records that share a domain, phone, or first word of the name.
* It is then matched in three steps:
  1. An exact match first (same name and same domain or phone).
  2. A weighted score from 0 to 100.
  3. A manual review queue for anything the algorithm isn't confident about.
* A fuzzy score of 90 or more is only accepted automatically if both records have the same domain or phone; otherwise it goes to manual review along with anything that scored 70 to 89, and anything lower becomes its own company with a new company_id.
* A record in manual review also gets its own new company_id and is flagged as pending review, so it still appears in the final companies table and nothing downstream waits on it until a reviewer confirms or rejects the match.
* I matched on name, domain, phone, city and state. Since names change and have different suffixes like Inc and LLC, names are compared by their words, and common words are identified and ignored.
* With 100x the data, I would generate and score the candidate pairs in DuckDB using its built-in similarity functions, which run in parallel, instead of one record at a time in a Python loop.
* I would also use the reviewed matches to tune the weights and thresholds to get more accurate scoring.

## What would you flag to the business as a data-quality risk in this feed, and how would you monitor for it going forward?

* The feed has no stable company id, so the same company comes back under new ids. That's the main reason duplicates exist.
* Phone numbers aren't unique (one number is shared by 4 unrelated companies), and 111 companies have no phone at all.
* Parent company data is inconsistent: some companies' records disagree on their parent.
* Some person-company links end before they start, and duplicate links for the same person and company are common.
* Every QC check runs on every load and stores its findings, and `gold.data_quality_summary` shows the counts after each run, so I would track those over time and alert when one jumps. The gold tests already stop a bad build from being published.

# Part 2 Write Up

## What matching logic did you use, and in what order (exact match, then fuzzy, then manual review, etc.)? Which fields ended up being reliable vs. unreliable?

* Salesforce accounts go through the same entity matching process as the Part 1 companies, but only after Part 1 has completed entity resolution, so each account is matched onto the finished Part 1 companies.
* Each account is compared to companies that share a domain, phone or first word of the name, and is matched the same way Part 1 companies are matched.
* **Reliable:** domain and phone, because they are almost always filled (no Part 1 company is missing a domain) and close to one value per company (see docs/analysis/Ad-Hoc-Analysis.md).
* **Unreliable:**
  * Names: the same company's records often had different names (only 9 of the 25 duplicate pairs sharing a domain had the same name).
  * City and state: shared by too many companies to tell them apart.
  * The ss_* fields: they disagree with the core fields.

## Which records did you leave unmatched, and how did you avoid force-matching the ones that look similar but aren't? Were there any you went back and forth on?

* Every Salesforce account was given a company id: 88 matched a Part 1 company, and the other 12 had no confident Part 1 match, so the matching process kept them unmatched as their own Salesforce-only companies instead of forcing them onto one.
* Lookalikes like Dorado Industrial Group and Dorado Industries stayed separate because their domains and phones differ, so they only scored 50%.
* The two I went back and forth on:
  * Thirteen Barrels Brewing vs Odd13 Brewing: everything matches except the name, and the matching process sent it to review at 88%.
  * Helix Intelligence Group: its ss_company_name says Centrum-AI, and the QC checks flagged it for review because it shares Centrum-AI's domain.

## How would this approach hold up at 100,000+ records per source instead of 100? What would you change about the matching strategy or the crosswalk design?

* Similar to my answer in Part 1, I would generate and score the candidate pairs in DuckDB, which runs in parallel, instead of one record at a time in a Python loop.
* The crosswalk already has one row per source record keyed on source system and source record id, so a third source only adds rows.
* I would add an id history so old crosswalk ids still resolve after two companies are merged or split.

## How would you handle low-confidence matches in production — auto-accept, auto-reject, or route to a human? Who would review them?

* Auto-accept exact matches and scores of 90 or more with a matching domain or phone.
* Auto-reject anything under 70 as its own company.
* Route everything in between, plus anything QC flags, to a human.
* While a record waits for review, it gets its own company id and is flagged as needing review, so it still appears in the crosswalk and nothing downstream waits on it.
* The reviews would be done by a data steward or whoever owns the CRM data, since they know the accounts best.
