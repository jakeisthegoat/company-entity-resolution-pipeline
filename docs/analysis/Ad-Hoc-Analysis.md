# Ad Hoc Analysis

The queries I used to check the data and make the matching decisions, and what they returned on the assessment data.

To run them, open DuckDB from the repository root and attach the two databases first. Salesforce accounts aren't in the provided DuckDB file, so those queries read `sample_data/account.csv` directly.

```sql
ATTACH 'sample_data/candidate_data.duckdb' AS candidate (READ_ONLY);  -- the raw data as provided
ATTACH '00_database/pipeline.duckdb' AS pipeline (READ_ONLY);          -- the pipeline's output
```

## Part 1 companies

### Shared domains

Counted how many domains appear on more than one Part 1 company, to see how much of the duplication domain would catch.

```sql
SELECT count(*) AS shared_domains
  FROM (SELECT lower(trim(domain)) FROM candidate.raw.company
         WHERE nullif(trim(domain), '') IS NOT NULL GROUP BY 1 HAVING count(*) > 1);
```

**Result:**

| shared_domains |
|---|
| 25 |

### Companies sharing a domain

Listed the companies behind each shared domain to see how their names differ (suffixes, "dba", renames).

```sql
SELECT lower(trim(domain)) AS domain, count(*) AS rows, string_agg(name, ' | ' ORDER BY name) AS names
  FROM candidate.raw.company
 WHERE nullif(trim(domain), '') IS NOT NULL
 GROUP BY 1
HAVING count(*) > 1
 ORDER BY 1
 LIMIT 10;
```

**Result:**

| domain | rows | names |
|---|---|---|
| aspiresoftware.com | 2 | Aspire Software \| Aspire Software (Canada) |
| baudville.com | 2 | Baudville, Inc. \| Baudville, Inc. |
| brandedbull.com | 2 | Branded Bull, Inc. \| Branded Bull, LLC |
| celerityrisk.com | 2 | Celerity Risk \| Celerity Risk |
| encorelabs.com | 2 | Encore Labs \| Encore Labs, LLC |
| foxinnovation.com | 2 | Fox Innovation & Technologies \| Fox Innovation & Technologies, Inc. |
| gomohealth.com | 2 | GoMo Health \| Gold Group Enterprises, Inc. dba GoMo Health |
| grillos.com | 2 | Grillo's Pickles, Inc. \| Grillo's Pickles, Inc. |
| hoardscreamery.com | 2 | Hoard's Dairyman Farm Creamery \| Hoard's Dairyman Farm Creamery |
| infinityinternet.com | 2 | Pacifier Online Data Service dba Infinity Internet, Inc. \| Pacifier Online Data Service dba Infinity Internet, Inc. |

### How unique each match field is

Counted filled, missing and distinct values for each match field, to see which fields tell one company from another.

```sql
SELECT field,
       count(value) AS filled,
       count(*) - count(value) AS missing,
       count(DISTINCT value) AS distinct_values,
       round(100.0 * count(DISTINCT value) / count(value), 1) AS pct_distinct
  FROM (SELECT 'domain' AS field, nullif(lower(trim(domain)), '') AS value FROM candidate.raw.company
        UNION ALL SELECT 'phone', nullif(right(regexp_replace(phonenumber, '[^0-9]', '', 'g'), 10), '') FROM candidate.raw.company
        UNION ALL SELECT 'name', nullif(lower(trim(name)), '') FROM candidate.raw.company
        UNION ALL SELECT 'city', nullif(lower(trim(city)), '') FROM candidate.raw.company
        UNION ALL SELECT 'state', nullif(lower(trim(state)), '') FROM candidate.raw.company)
 GROUP BY field
 ORDER BY pct_distinct DESC;
```

**Result:**

| field | filled | missing | distinct_values | pct_distinct |
|---|---|---|---|---|
| name | 1024 | 0 | 1015 | 99.1 |
| phone | 913 | 111 | 895 | 98.0 |
| domain | 1024 | 0 | 999 | 97.6 |
| city | 1024 | 0 | 617 | 60.3 |
| state | 1024 | 0 | 58 | 5.7 |

### How often a company's records agree

Compared the records of each company that shares a domain field by field, to see which fields stay the same across a company's records.

```sql
WITH pairs AS (
    SELECT a.*, b.name AS b_name, b.phonenumber AS b_phone, b.city AS b_city, b.state AS b_state
      FROM candidate.raw.company a
      JOIN candidate.raw.company b ON lower(trim(a.domain)) = lower(trim(b.domain)) AND a.id < b.id
)
SELECT count(*) AS same_domain_pairs,
       count(*) FILTER (WHERE lower(trim(name)) = lower(trim(b_name))) AS same_name,
       count(*) FILTER (WHERE right(regexp_replace(phonenumber, '[^0-9]', '', 'g'), 10)
                            = right(regexp_replace(b_phone, '[^0-9]', '', 'g'), 10)) AS same_phone,
       count(*) FILTER (WHERE phonenumber IS NULL OR b_phone IS NULL) AS phone_missing_on_one,
       count(*) FILTER (WHERE lower(trim(city)) = lower(trim(b_city))) AS same_city,
       count(*) FILTER (WHERE lower(trim(state)) = lower(trim(b_state))) AS same_state
  FROM pairs;
```

**Result:**

| same_domain_pairs | same_name | same_phone | phone_missing_on_one | same_city | same_state |
|---|---|---|---|---|---|
| 25 | 9 | 13 | 6 | 21 | 22 |

### Missing match fields

Checked how often each match field is empty, to see which fields can be relied on.

```sql
SELECT count(*) AS rows,
       count(*) FILTER (WHERE nullif(trim(domain), '') IS NULL)      AS no_domain,
       count(*) FILTER (WHERE nullif(trim(phonenumber), '') IS NULL) AS no_phone,
       count(*) FILTER (WHERE nullif(trim(city), '') IS NULL)        AS no_city,
       count(*) FILTER (WHERE nullif(trim(state), '') IS NULL)       AS no_state
  FROM candidate.raw.company;
```

**Result:**

| rows | no_domain | no_phone | no_city | no_state |
|---|---|---|---|---|
| 1024 | 0 | 111 | 0 | 0 |

### Phones shared by different companies

Looked for phone numbers used by companies with different domains, to check whether phone can be trusted on its own.

```sql
SELECT right(regexp_replace(phonenumber, '[^0-9]', '', 'g'), 10) AS phone,
       count(DISTINCT lower(domain)) AS domains,
       string_agg(DISTINCT name, ' | ') AS names
  FROM candidate.raw.company
 WHERE length(regexp_replace(phonenumber, '[^0-9]', '', 'g')) >= 10
 GROUP BY 1
HAVING count(DISTINCT lower(domain)) > 1
 ORDER BY domains DESC;
```

**Result:**

| phone | domains | names |
|---|---|---|
| 4806242599 | 4 | PrimeVault \| Spiritual Highness, LLC \| Sky Homes \| FanBeat, Inc. |
| 4806242505 | 2 | AM Enterprise Solutions, LLC dba Pretty Pipe Shop \| Humic Products Trade Association, Inc. (HPTA) |
| 8556461390 | 2 | AH Ventures \| Easy Dental Solutions |

### Common words in company names

Measured the share of company names each word appears in, to pick the cut-off for ignoring common words like inc and llc.

```sql
WITH names AS (
    SELECT name FROM candidate.raw.company
    UNION ALL
    SELECT name FROM read_csv('sample_data/account.csv', all_varchar = true)
), words AS (
    SELECT DISTINCT n.name, w.word
      FROM names n,
           unnest(string_split(trim(regexp_replace(lower(replace(n.name, '&', ' and ')), '[^a-z0-9 ]', ' ', 'g')), ' ')) AS w(word)
     WHERE w.word <> ''
)
SELECT word, count(*) AS names, round(100.0 * count(*) / (SELECT count(*) FROM names), 1) AS pct
  FROM words
 GROUP BY 1
 ORDER BY names DESC
 LIMIT 15;
```

**Result:**

| word | names | pct |
|---|---|---|
| inc | 367 | 32.7 |
| llc | 282 | 25.1 |
| and | 94 | 8.4 |
| dba | 67 | 6.0 |
| group | 46 | 4.1 |
| solutions | 38 | 3.4 |
| services | 37 | 3.3 |
| s | 32 | 2.8 |
| co | 29 | 2.6 |
| the | 27 | 2.4 |
| of | 25 | 2.2 |
| corp | 24 | 2.1 |
| ltd | 23 | 2.0 |
| associates | 17 | 1.5 |
| consulting | 17 | 1.5 |

### Parent ids

Checked whether parent ids point to companies in the data, to decide how to apply the parent/subsidiary rule.

```sql
SELECT count(*) AS rows_with_parent,
       count(DISTINCT parentid) AS distinct_parents,
       count(*) FILTER (WHERE parentid IN (SELECT id FROM candidate.raw.company)) AS parent_in_data
  FROM candidate.raw.company
 WHERE parentid IS NOT NULL;
```

**Result:**

| rows_with_parent | distinct_parents | parent_in_data |
|---|---|---|
| 66 | 62 | 0 |

## Salesforce accounts

### Salesforce core fields vs ss_* fields

Compared each account's core name, website and city to its ss_* copies, to decide whether to match on the ss_* fields.

```sql
SELECT name, ss_company_name__c, website, ss_website__c, billingcity, ss_city__c
  FROM read_csv('sample_data/account.csv', all_varchar = true)
 WHERE lower(regexp_replace(name, '[^a-zA-Z0-9]', '', 'g'))
           <> lower(regexp_replace(ss_company_name__c, '[^a-zA-Z0-9]', '', 'g'))
    OR regexp_replace(lower(website), '^https?://(www\.)?|/.*$', '', 'g')
           <> regexp_replace(lower(ss_website__c), '^https?://(www\.)?|/.*$', '', 'g')
    OR lower(trim(billingcity)) <> lower(trim(ss_city__c));
```

**Result:**

| name | ss_company_name__c | website | ss_website__c | billingcity | ss_city__c |
|---|---|---|---|---|---|
| VyMaC Corp. | VyMaC Corp. | https://connorfasteners.com | https://vymac.com | Fort Atkinson | Fort Atkinson |
| Helix Intelligence Group | Centrum-AI Inc. | https://www.centrum-ai.com | https://centrum-ai.com | San Francisco | San Francisco |
| Wyoming Mutual Telephone Co.  | Wyoming Mutual Telephone Co. | https://syzygy-tech.com | https://wyomingtel.com | Wyoming | Wyoming |
| Bateman Labs | Bateman Labs | https://www.batemanlabs.com | https://batemanlabs.com | Calgary | North Vancouver |
| ALIGNMT LLC | ALIGNMT LLC | https://homebrewshop.com | https://alignmt.com | Irvine | Irvine |
| Sanskar Culture Society | Sanskar Culture Society | https://sanskarusa.org | https://sanskarusa.org | Providence | Foxborough |
| Full Canopy Tree Care | Full Canopy Tree Care, LLC |  |  | Austin | Austin |
| Sensorium Labs (fka OVR Tech) | OVR Tech, LLC | https://ovrtechnology.com | https://ovrtechnology.com | Burlington | Burlington |
| GP Consulting | GP Consulting, LLC | https://consult-gp.com | https://consult-gp.com | Monroe | Monroe |
| Encore Labs | Encore Labs, LLC | https://encorelabs.com | https://encorelabs.com | Pasadena | Pasadena |

### Salesforce domains that belong to another company

Found accounts whose domain matches a Part 1 company with a different name, to check whether domain alone can be trusted.

```sql
SELECT a.name AS account_name, lower(a.domain__c) AS account_domain, c.name AS part1_company_with_that_domain
  FROM read_csv('sample_data/account.csv', all_varchar = true) a
  JOIN candidate.raw.company c ON lower(trim(c.domain)) = lower(trim(a.domain__c))
 WHERE split_part(lower(regexp_replace(a.name, '[^a-zA-Z0-9 ]', '', 'g')), ' ', 1)
       <> split_part(lower(regexp_replace(c.name, '[^a-zA-Z0-9 ]', '', 'g')), ' ', 1);
```

**Result:**

| account_name | account_domain | part1_company_with_that_domain |
|---|---|---|
| Thirteen Barrels Brewing Co. | odd13brewing.com | Odd13 Brewing, Inc. |
| VyMaC Corp. | connorfasteners.com | Connor Fastener, Inc. |
| ALIGNMT LLC | homebrewshop.com | Karp's Homebrew Shop |
| Wyoming Mutual Telephone Co.  | syzygy-tech.com | Syzygy Technologies, Inc. |
| Sensorium Labs (fka OVR Tech) | ovrtechnology.com | OVR Tech, LLC |
| Helix Intelligence Group | centrum-ai.com | Centrum-AI Inc. |

### Name similarity of name vs ss_company_name

Scored each account's name against its ss_company_name with Jaro-Winkler, to pick the QC cut-off for name conflicts.

```sql
SELECT round(jaro_winkler_similarity(lower(name), lower(ss_company_name__c)), 2) AS score, name, ss_company_name__c
  FROM read_csv('sample_data/account.csv', all_varchar = true)
 WHERE nullif(trim(ss_company_name__c), '') IS NOT NULL
 ORDER BY score
 LIMIT 6;
```

**Result:**

| score | name | ss_company_name__c |
|---|---|---|
| 0.39 | Sensorium Labs (fka OVR Tech) | OVR Tech, LLC |
| 0.54 | Helix Intelligence Group | Centrum-AI Inc. |
| 0.94 | GP Consulting | GP Consulting, LLC |
| 0.94 | Encore Labs | Encore Labs, LLC |
| 0.96 | Full Canopy Tree Care | Full Canopy Tree Care, LLC |
| 0.99 | Infigo Audio, Inc.  | Infigo Audio, Inc. |

## People and links

### People with the same name

Counted groups of people with the same first and last name, to see whether names can identify a person.

```sql
SELECT count(*) AS same_name_groups,
       count(*) FILTER (WHERE with_linkedin > distinct_linkedins) AS groups_sharing_a_linkedin
  FROM (SELECT lower(firstname), lower(lastname), count(*) AS people,
               count(linkedin) AS with_linkedin, count(DISTINCT lower(linkedin)) AS distinct_linkedins
          FROM candidate.raw.person
         GROUP BY 1, 2
        HAVING count(*) > 1);
```

**Result:**

| same_name_groups | groups_sharing_a_linkedin |
|---|---|
| 192 | 1 |

### People sharing a LinkedIn URL

Looked for LinkedIn URLs used by more than one person, to find true duplicates.

```sql
SELECT lower(linkedin) AS linkedin, count(*) AS rows, string_agg(firstname || ' ' || lastname, ' | ') AS people
  FROM candidate.raw.person
 WHERE nullif(trim(linkedin), '') IS NOT NULL
 GROUP BY 1
HAVING count(*) > 1;
```

**Result:**

| linkedin | rows | people |
|---|---|---|
| https://www.linkedin.com/in/sarah-reed-38 | 2 | Sarah Reed \| Sarah Reed |

### Duplicate person-company links

Counted person and company pairs that appear more than once, to size the duplicate links to collapse.

```sql
SELECT count(*) AS duplicated_pairs, sum(rows - 1) AS extra_rows
  FROM (SELECT personid, companyid, count(*) AS rows
          FROM candidate.raw.persontocompany
         GROUP BY 1, 2
        HAVING count(*) > 1);
```

**Result:**

| duplicated_pairs | extra_rows |
|---|---|
| 113 | 113 |

### Links with end dates

Checked how many links have an end date, an end date in the future, or an end date before the start date, to decide how to treat them.

```sql
SELECT count(*) AS links,
       count(enddate)                                  AS with_end_date,
       count(*) FILTER (WHERE enddate > current_date)  AS future_end_date,
       count(*) FILTER (WHERE enddate < startdate)     AS end_before_start
  FROM candidate.raw.persontocompany;
```

**Result:**

| links | with_end_date | future_end_date | end_before_start |
|---|---|---|---|
| 1983 | 541 | 17 | 54 |

## Matching results

### Match results by source

Counted how each company record was decided (exact, auto-match, review, new), split by source.

```sql
SELECT s.source_name, r.match_band, count(*) AS records
  FROM pipeline.entity_resolution.company_match_result r
  JOIN pipeline.entity_resolution.company_match_input i USING (transaction_id)
  JOIN pipeline.config.source s USING (source_id)
 GROUP BY ALL
 ORDER BY 1, 2;
```

**Result:**

| source_name | match_band | records |
|---|---|---|
| part1_company | auto_match | 3 |
| part1_company | exact | 16 |
| part1_company | new | 999 |
| part1_company | review | 6 |
| salesforce | auto_match | 1 |
| salesforce | exact | 87 |
| salesforce | new | 11 |
| salesforce | review | 1 |

### Matches sent to review

Listed the company matches sent to review with their score, basis and best candidate, to check each one by hand.

```sql
SELECT i.name, r.match_score, r.match_basis,
       (SELECT name FROM pipeline.entity_resolution.company_match_input
         WHERE transaction_id = r.matched_transaction_id) AS best_candidate
  FROM pipeline.entity_resolution.company_match_result r
  JOIN pipeline.entity_resolution.company_match_input i USING (transaction_id)
 WHERE r.match_band = 'review'
 ORDER BY r.match_score DESC;
```

**Result:**

| name | match_score | match_basis | best_candidate |
|---|---|---|---|
| neighborly company | 88.89 | name 72%, domain match, phone match, city match, state match | neighborly assetco llc dba neighborly co |
| thirteen barrels brewing co | 88.00 | name 70%, domain match, phone match, city match, state match | odd13 brewing inc |
| the standard hotels | 87.83 | name 70%, domain match, phone match, city match, state match | standard international management llc |
| vantage creative group | 80.43 | name 61%, domain match, city match, state match | vantage innovation lab |
| state university of new york at plattsburgh | 80.00 | name 100%, domain match, phone differs, city match, state match | state university of new york at plattsburgh suny plattsburgh |
| shepherd veterinary software llc dba shepherd veterinary solutions | 80.00 | name 100%, domain match, phone differs, city match, state match | shepherd veterinary software llc |
| aspire software canada | 75.00 | name 100%, domain match, phone differs, city differs, state match | aspire software |

### Companies by system

Counted companies in both systems, Part 1 only and Salesforce only from the crosswalk.

```sql
SELECT presence, count(DISTINCT crosswalk_id) AS companies
  FROM pipeline.gold.crosswalk
 GROUP BY 1
 ORDER BY 1;
```

**Result:**

| presence | companies |
|---|---|
| both | 88 |
| part1_only | 917 |
| salesforce_only | 12 |
