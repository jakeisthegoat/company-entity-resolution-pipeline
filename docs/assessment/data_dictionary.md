# Data Dictionary

Every column of the four provided tables. Overview of the data and the problem: [Problem Breakdown](Jacob-Problem-Breakdown.md).

**Sources**

- **Description:** from `sample_data/README.md`. Where the README says nothing about a column, the cell reads *Not documented*.
- **Data type:** from the DuckDB schema (`information_schema.columns`, schema `raw`) for Part 1. For `account.csv`, inferred by DuckDB `read_csv_auto`, because a CSV has no declared types.
- **Key:** logical keys from the README. DuckDB declares no primary or foreign key constraints, and every column is nullable. `id` was checked and is unique in every table.

---

## Part 1 Tables

### `raw.company` — 1,024 rows

One row per company record as sourced. **Not deduplicated.** The same real-world company can appear more than once under different `id` values (re-synced under a new record, or a legal-name variant). The README calls resolving this "the point of the exercise".

| Column | Description | Data type | Key |
|---|---|---|---|
| `id` | Source company record id | BIGINT | PK (unique per raw record, **not** per real-world company) |
| `name` | Company name | VARCHAR | |
| `informalname` | Informal or short company name | VARCHAR | |
| `website` | Company website URL | VARCHAR | |
| `domain` | Company web domain | VARCHAR | |
| `phonenumber` | Company phone number | VARCHAR | |
| `city` | City | VARCHAR | |
| `state` | State | VARCHAR | |
| `postalcode` | Postal code | VARCHAR | |
| `country` | Country | VARCHAR | |
| `foundingyear` | Year founded | BIGINT | |
| `companytype` | *Not documented* (numeric code) | BIGINT | |
| `parentid` | Id of the parent company | BIGINT | Self-reference → `company.id` (out of scope per assessment) |
| `parentcompany` | Parent company name | VARCHAR | |
| `totalamountinvested` | Total amount invested | BIGINT | |
| `nolongerinbusiness` | Out-of-business flag (always `false` in this extract) | BOOLEAN | |
| `modifieddate` | Last modified timestamp | TIMESTAMP | |

### `raw.person` — 1,870 rows

One row per person. Names and LinkedIn URLs are synthetic.

| Column | Description | Data type | Key |
|---|---|---|---|
| `id` | Person id | BIGINT | PK |
| `firstname` | First name | VARCHAR | |
| `middlename` | Middle name | VARCHAR | |
| `lastname` | Last name | VARCHAR | |
| `linkedin` | LinkedIn URL | VARCHAR | |
| `facebook` | Facebook URL | VARCHAR | |
| `twitter` | Twitter URL | VARCHAR | |
| `website` | Personal website | VARCHAR | |
| `city` | City | VARCHAR | |
| `state` | State | VARCHAR | |
| `country` | Country | VARCHAR | |
| `deleted` | Soft-delete flag (always `false` in this extract) | BOOLEAN | |
| `statecode` | State code | VARCHAR | |
| `countrycode` | Country code | VARCHAR | |
| `modifieddate` | Last modified date | DATE | |
| `loaddate` | Load date | DATE | |

### `raw.persontocompany` — 1,983 rows

Join table between people and companies. **A person can be linked to the same company more than once** (e.g. overlapping records from a re-sync).

| Column | Description | Data type | Key |
|---|---|---|---|
| `id` | Link record id | BIGINT | PK |
| `personid` | Person in the link | BIGINT | FK → `person.id` |
| `companyid` | Company in the link | BIGINT | FK → `company.id` (raw id; may point to a record that gets merged away) |
| `startdate` | Role start date | DATE | |
| `enddate` | Role end date. **Blank = still in the role** | DATE | |
| `email` | Work email | VARCHAR | |
| `emailconfirmed` | Whether the email is confirmed | BOOLEAN | |
| `phone` | Work phone | VARCHAR | |
| `title` | Free-text job title | VARCHAR | |
| `role` | Source-side seniority code (1, 2 or 3). Meaning undocumented upstream. **Carry through as an opaque attribute; do not match or filter on it** | BIGINT | |
| `deleted` | Soft-delete flag (always `false` in this extract) | BOOLEAN | |
| `modifieddate` | Last modified date | DATE | |
| `loaddate` | Load date | DATE | |

---

## Part 2 Table

### `account.csv` — 100 rows, 269 columns

A Salesforce-shaped Account export. **Not in the DuckDB file; it has to be loaded separately.** Only 19 of the 269 columns contain any data; the rest are empty, as they come out of a real CRM. Only the 19 populated columns are listed below. The "Populated" column (non-blank rows out of 100) comes from profiling the file, not the README.

- `ss_*` columns are appended by a third-party sourcing tool. They are not always populated, and where they are, they don't always agree with the core Salesforce fields next to them.
- Formatting is inconsistent by design: mixed casing, legal-suffix variants, trailing whitespace, `www.` on some websites only.
- Most, but not all, accounts correspond to a Part 1 company. Working out which, and how many, is part of the exercise.

| Column | Description | Data type | Key | Populated | Matching use (per README) |
|---|---|---|---|---|---|
| `id` | Salesforce account id. The source record id the crosswalk needs | VARCHAR | PK | 100 | Record id |
| `name` | Account name | VARCHAR | | 100 | Matters most |
| `billingcity` | Billing city | VARCHAR | | 100 | Matters most |
| `billingstate` | Billing state | VARCHAR | | 100 | Matters most |
| `billingcountry` | Billing country | VARCHAR | | 100 | Matters most |
| `phone` | Phone | VARCHAR | | 94 | Matters most |
| `website` | Website URL | VARCHAR | | 91 | Matters most |
| `domain__c` | Custom domain field | VARCHAR | | 96 | Matters most |
| `ss_company_name__c` | Sourcing-tool company name | VARCHAR | | 73 | Matters most (may disagree with `name`) |
| `ss_website__c` | Sourcing-tool website | VARCHAR | | 82 | Matters most (may disagree with `website`) |
| `ss_city__c` | Sourcing-tool city | VARCHAR | | 85 | Matters most (may disagree with `billingcity`) |
| `ss_state__c` | Sourcing-tool state | VARCHAR | | 85 | Matters most (may disagree with `billingstate`) |
| `ss_phone__c` | Sourcing-tool phone | VARCHAR | | 79 | Matters most (may disagree with `phone`) |
| `ss_year_founded__c` | Sourcing-tool founding year | BIGINT | | 85 | Matters most |
| `isdeleted` | Salesforce soft-delete flag | BOOLEAN | | 100 | Not reliable for matching |
| `numberofemployees` | Employee count | BIGINT | | 53 | Not reliable for matching |
| `createddate` | Account created timestamp | TIMESTAMP | | 100 | Not reliable for matching |
| `accountsource` | Lead / account source | VARCHAR | | 79 | Not reliable for matching |
| `pitchbook_id__c` | PitchBook id | VARCHAR | | 20 | Not reliable for matching |
