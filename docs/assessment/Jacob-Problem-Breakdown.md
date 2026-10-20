# Problem Breakdown

## Overall Instructions

1. Graded based on judgement more than the actual code.
2. Flag doubt rather than guess
3. There are 2 parts. Part 2 depends on the completion of part 1
4. Expect follow up questions and to be able to defend design choices

## Core Problem:

1. Turn raw, imperfect data into trusted and reusable datasets
2. Identify a company across several records and created one trusted "golden" record.
3. Keep auditable mapping from every source record to it the "golden" record.

## Part 1 Breakdown

### Instructions:

1. Graded based on judgement more than the actual code.
2. Flag doubt rather than guess
3. Part 2 depends on the completion of part 1
4. Expect follow up questions and to be able to defend design choices

### Problem to Solve:

1. Detect duplicate companies and how you pick and merge fields. Parent and subsidiary companies are separate companies, not duplicates
2. Build a people table at one row per person, linked to the correct final company.
3. Write a data quality summary:
   1. How many raw company rows collapsed into how many final companies
   2. How did I verify there no accidental over-merges (two different companies merged into one) or under-merges
4. Add at least 3 data quality tests  (e.g. uniqueness on the final company id, not-null checks, a test that no domain appears twice in the final table)
5. Write up how to perform duplicate detection and what would change at 100x the data
   1. The data quality risks in the feed and how you'd monitor them.

## Part 2 Breakdown

### Instructions

1. Take the final companies table that was built in Part 1 and reconcile it against a second, independent source system. Every record must resolve to one golden company and we need an audible record of how each source record maps to it.
2. Match each salesforce row in account.csv to the correct row in your final Part 1 companies tables wherever a true match exists.
   1. Decide what signals to match one - don't assume any on field is clean enough to join on blindly
3. Produce a crosswalk table with one row per source record, covering both sources completely.
   1. Every raw company id from Part 1 and every row of account.csv
   2. Keeping one row per raw company id - a company that was two raw rows in Part 1 contributes two crosswalk rows
   3. Each row should have a:
      1. Crosswalk ID (system generated)
      2. An indicator of which systems the company is present in (both / part1_only / salesforce_only)
      3. On matched rows — your confidence and the signal(s) it rests on.
         1. Design it so a third source could be added later without changing the schema.
   4. Every account.csv row and every raw company id from Part 1 must appear in the crosswalk - including companies with no Salesforce record, and Salesforce accounts with no Part 1 counterpart
   5. Don't drop any unmmatched records and don't force a match to make the numbers looks cleaner.
   6. The graders should be able to read straight off your crosswalk how many companies we hold in both systems vs only one and which one.
   7. Write matching logic in Python
   8. Confidence and match basis apply to rows you actually matched, leave them blank for rows that have not been matched.
      1. Use a scale you like and briefly say what each match rests on
   9. Flag anything you're not confident about rather than silently guessing

### Final Write Up (5-10 Sentences)

* What matching logic did you use, and in what order (exact match, then fuzzy, then manual review, etc.)? Which fields ended up being reliable vs. unreliable?
* Which records did you leave unmatched, and how did you avoid force-matching the ones that look similar but aren't? Were there any you went back and forth on?
* How would this approach hold up at 100,000+ records per source instead of 100? What would you change about the matching strategy or the crosswalk design?
* How would you handle low-confidence matches in production — auto-accept, auto-reject, or route to a human? Who would review them?

## Provided Data Breakdown

### Part 1 Data Overview

* candidate_data.duckdb - A DuckDB database with a `raw` schema containing all three tables below. Point dbt (via a `duckdb` profile) or any SQL client at this file directly.
* `company.csv`, `person.csv`, `persontocompany.csv` — the same data as flat files, if you'd rather load them yourself (pandas, a fresh DuckDB db, etc.).

### Part 2 Data

* `account.csv` — a Salesforce-shaped account export. See the section below.

All data is a real, de-identified slice of company records plus fully synthetic people data built to mirror the shape and quirks of our actual pipeline. No real individuals' names, emails, or contact details are included anywhere in this dataset.
A note on two columns before you start: `deleted` (on `raw.person` and `raw.persontocompany`) and `nolongerinbusiness` (on `raw.company`) are present because they exist in the real feed, but in this extract every row is `false`. You don't need to reason about soft deletes here.

Column-level detail for every table is in [Data Dictionary](data_dictionary.md).
