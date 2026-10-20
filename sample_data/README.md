# Data Engineer Assessment — Data Package

This folder contains the source data for both parts of the assessment.

**Part 1** data is provided two ways — pick whichever fits your workflow:

- `candidate_data.duckdb` — a DuckDB database with a `raw` schema containing all three tables below. Point dbt (via a `duckdb` profile) or any SQL client at this file directly.
- `company.csv`, `person.csv`, `persontocompany.csv` — the same data as flat files, if you'd rather load them yourself (pandas, a fresh DuckDB db, etc.).

**Part 2** data is a single file:

- `account.csv` — a Salesforce-shaped account export. See the section below.

All data is a real, de-identified slice of company records plus fully synthetic people data built to mirror the shape and quirks of our actual pipeline. No real individuals' names, emails, or contact details are included anywhere in this dataset.

A note on two columns before you start: `deleted` (on `raw.person` and `raw.persontocompany`) and `nolongerinbusiness` (on `raw.company`) are present because they exist in the real feed, but in this extract every row is `false`. You don't need to reason about soft deletes here.

## Part 1 tables

These three tables live in the `raw` schema of `candidate_data.duckdb`, and are also provided as the matching CSVs.

### raw.company (1,024 rows)
One row per company record as sourced. Columns: `id`, `name`, `informalname`, `website`, `domain`, `phonenumber`, `city`, `state`, `postalcode`, `country`, `foundingyear`, `companytype`, `parentid`, `parentcompany`, `totalamountinvested`, `nolongerinbusiness`, `modifieddate`.

Note: this table has not been deduplicated. The same real-world company can appear more than once under different `id` values (e.g. re-synced from source under a new record, or a legal-name variant). That's intentional — resolving this into clean, unique company records is the point of the exercise.

### raw.person (1,870 rows)
One row per person. Columns: `id`, `firstname`, `middlename`, `lastname`, `linkedin`, `facebook`, `twitter`, `website`, `city`, `state`, `country`, `deleted`, `statecode`, `countrycode`, `modifieddate`, `loaddate`. All names and LinkedIn URLs are synthetic.

### raw.persontocompany (1,983 rows)
The join between people and companies — a person can be linked to a company more than once (e.g. overlapping records from a re-sync). Columns: `id`, `personid`, `companyid`, `startdate`, `enddate` (blank = still in the role), `email`, `emailconfirmed`, `phone`, `title`, `role`, `deleted`, `modifieddate`, `loaddate`.

`title` is the free-text job title. `role` is a source-side seniority code (1, 2 or 3) whose meaning isn't documented upstream — treat it as an opaque attribute to carry through, not something to match or filter on.

## Part 2 table

### account.csv (100 rows, 269 columns)

A Salesforce-shaped account export, with the same column structure as a real Salesforce Account object export. This file is **not** in the DuckDB database — load it yourself. Only 19 of the 269 columns contain any data at all; the rest are empty, exactly as they come out of a real CRM. The columns that matter most for matching:

`id`, `name`, `billingcity`, `billingstate`, `billingcountry`, `phone`, `website`, `domain__c`, `ss_company_name__c`, `ss_website__c`, `ss_city__c`, `ss_state__c`, `ss_phone__c`, `ss_year_founded__c`

(`id` is the Salesforce account id — this is the source record id your crosswalk needs. The remaining populated columns are `isdeleted`, `numberofemployees`, `createddate`, `accountsource` and `pitchbook_id__c`; none is reliable enough to match on, but you're welcome to look.)

The `ss_*` columns are fields appended by a third-party sourcing tool. They are not always populated, and where they are they don't always agree with the core Salesforce fields next to them. Formatting is inconsistent by design: mixed casing, legal-suffix variants, trailing whitespace, `www.` on some websites and not others.

Most — but not all — of these 100 accounts correspond to a company somewhere in the Part 1 data. Working out which, and how many, is part of the exercise.

## What to build

**Part 1:** turn the three raw tables into two clean, deduplicated tables — a final `companies` table at one row per real-world company, and a final `people` table at one row per person, each linked to the right company.

**Part 2:** match `account.csv` against your final Part 1 companies table and produce a crosswalk with one row per source record, covering every raw company id and every account row.

See the main assessment document for the full task description for each part.
