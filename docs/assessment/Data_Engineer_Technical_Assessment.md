**LLR Partners**

**Data Engineer — Technical Assessment**

*Take-home exercise · budget 2 hours total · open-book*

# Overview

This assessment mirrors real work on our team: turning raw, imperfect data into trusted, reusable datasets. It has two parts:

  - Part 1 — Company & People Data Modeling (SQL / dbt-style modeling) — about 60 minutes

  - Part 2 — Company Crosswalk & Entity Resolution (Python-centric) — about 60 minutes

Use whatever tools you're comfortable with — dbt, raw SQL against DuckDB or Postgres, or a Python/pandas/polars script. There is no single "correct" tech choice; we care about your reasoning, your data-quality instincts, and how you'd explain trade-offs to a non-technical stakeholder. You're welcome to use AI coding assistants — just come ready to walk through your own logic afterward.

## What to submit

  - Your code (SQL files, dbt models, a DuckDB file, or Python files) for each part.

  - A short written response for each part (bullet points are fine — no need for prose).

  - Send back as a zip or a link to a git repo (public or private with access for us).

## Provided data

A separate data package accompanies this document. For Part 1: candidate_data.duckdb (a DuckDB file with a raw schema) plus the same tables as flat CSVs (company.csv, person.csv, persontocompany.csv). For Part 2: account.csv, the Salesforce-shaped export described below. The README in the package describes each file and the columns that matter. This is a real, de-identified slice of roughly 1,000 company records from our actual sourcing pipeline — company records are real (just a small sample, not deduplicated), and all people data (names, emails, LinkedIn URLs) is fully synthetic. No real individuals appear anywhere in this dataset.

# Part 1 — Company & People Data Modeling

Context: Our sourcing pipeline pulls company data from a third-party data provider on a recurring sync. Because the same company can be re-synced under a new source record (a legal-name change, a re-scrape, a duplicate submission), the same real-world company can show up more than once in our raw tables under different IDs — and it does, in the data attached. People (contacts, executives) are linked to companies through a join table that has its own overlap issues. Right now this all lives exactly as pulled from source, with no deduplication applied. We want a clean, trusted companies table and people table that the rest of the firm can rely on without re-litigating which record is the "real" one.

## raw.company, raw.person, raw.persontocompany

See the README in the data package for full column definitions. In short: raw.company is one row per company record as sourced (not deduplicated); raw.person is one row per person; raw.persontocompany links people to companies and can itself contain overlapping/duplicate link rows for the same person-company pair.

## Your task

Build a small modeling pipeline (as dbt models — bronze / silver / gold — or equivalent plain SQL views/CTEs) that produces:

  - A final companies table with one row per real-world company. Decide how you detect duplicates, and how you pick or merge field values when two raw rows represent the same company. Treat parent/subsidiary relationships (parentid, parentcompany) as out of scope — a subsidiary is its own company here, not a duplicate of its parent.

  - A final people table at one row per person, linking each person to the correct final company — including people who were originally linked to whichever raw company id got merged away. Also handle any duplicate/overlapping persontocompany rows for the same person-company pair (e.g. pick the most recent, or the one with the more complete data), and say what you decided to do with links that have an enddate.

  - A brief data-quality summary: how many raw company rows collapsed into how many final companies, and how you'd verify there are no accidental over-merges (two genuinely different companies merged into one) or under-merges (a duplicate you missed).

  - At least three data-quality tests you'd add (e.g. uniqueness on the final company id, not-null checks, a test that no domain appears twice in the final table) — as a dbt schema.yml snippet or just a described list if you're not using dbt.

## Write-up (5–10 sentences)

  - How did you detect and resolve duplicate companies? What signal(s) did you use, and what would you do differently with 100x the data?

  - What would you flag to the business as a data-quality risk in this feed, and how would you monitor for it going forward?

# Part 2 — Company Crosswalk & Entity Resolution

Context: The same company shows up differently in every system we touch. This part picks up right where Part 1 left off: you'll take the final companies table you built in Part 1 and reconcile it against a second, independent source system with its own (very real) shape and messiness — a Salesforce account export. Before we can report “how many companies are we tracking,” every record across every system has to resolve to one golden company, and we need an auditable record of how each source record maps to it.

## account.csv

A Salesforce-shaped account export — the same column structure as a real Salesforce Account object export. 269 columns, of which only 19 contain any data at all, and 100 rows. It was built the way real CRM data actually looks: inconsistent casing, legal-suffix variants, trailing whitespace, "www." on some websites and not others, and a mix of populated vs. blank fields row to row. The columns that matter most for matching: id (the Salesforce account id — this is the source record id your crosswalk needs), name, billingcity, billingstate, billingcountry, phone, website, and domain__c.

*Most, but not all, of these 100 rows correspond to a real company somewhere in your Part 1 companies table (sometimes an exact match, sometimes not). The rest are genuine Salesforce-only accounts with no counterpart anywhere in the Part 1 data. You don't get told which is which, or how many of each — that's the exercise.*

## Your task

  - Match each row in account.csv to the correct row in your final Part 1 companies table wherever a true match exists. Decide what signal(s) to match on (domain is the strongest single field, but company names, phone numbers, and locations can all help or mislead you) — don't assume any one field is clean enough to join on blindly, because none of them is.

  - Produce a crosswalk table (a file or a table in your database) with one row per source record, covering both sources completely: every raw company id from Part 1, and every row of account.csv. Keeping one row per raw company id (rather than per merged company) preserves the merge lineage, so a company that was two raw rows in Part 1 contributes two crosswalk rows. Each row should carry: a crosswalk id you generate (shared by every record that resolves to the same real-world company), the source system the record came from (use the literal values part1_company and salesforce), that system's own record id, the company name as it appears in that system, an indicator of which systems the company is present in (both / part1_only / salesforce_only), and — on matched rows — your confidence and the signal(s) it rests on. Design it so a third source could be added later without changing the schema.

  - Every account.csv row and every raw company id from Part 1 must appear in the crosswalk — including Part 1 companies with no Salesforce record, and Salesforce accounts with no Part 1 counterpart. Don't drop unmatched records and don't force a match to make the numbers look cleaner. We should be able to read straight off your crosswalk how many companies we hold in both systems versus only one, and which one.

  - Write your matching logic in Python (pandas/polars, fuzzy-matching or entity resolution libraries are fair game, or your own similarity functions) — this part should be Python-centric rather than pure SQL.

  - Confidence and match basis apply to rows you actually matched; leave them blank on Part 1-only and Salesforce-only rows. Use whatever scale you like (high/medium/low, or a numeric score) and briefly say what each match rests on. Flag anything you're not confident about rather than silently guessing — some of these records genuinely conflict with each other, and we would rather see that surfaced than smoothed over.

## Write-up (5–10 sentences)

  - What matching logic did you use, and in what order (exact match, then fuzzy, then manual review, etc.)? Which fields ended up being reliable vs. unreliable?

  - Which records did you leave unmatched, and how did you avoid force-matching the ones that look similar but aren't? Were there any you went back and forth on?

  - How would this approach hold up at 100,000+ records per source instead of 100? What would you change about the matching strategy or the crosswalk design?

  - How would you handle low-confidence matches in production — auto-accept, auto-reject, or route to a human? Who would review them?
