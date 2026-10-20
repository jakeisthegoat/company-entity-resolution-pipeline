-- Gold step 3: gold.person, one row per resolved person.
-- Names, LinkedIn and location by survivorship (records ranked once by resolution order, then most recent:
-- each attribute takes the first non-null value in that rank); plus the primary
-- affiliation from `affiliation` (step 2): a current one first, then the latest start date.

INSERT INTO gold.person (
    person_id, first_name, middle_name, last_name, linkedin, city, state, country,
    company_id, title, email, phone, start_date, end_date, is_current, affiliation_count, is_pending_review)
WITH member AS (
    SELECT pm.person_id, pm.transaction_id, pm.is_pending_review, coalesce(ero.resolution_order, 999) AS priority, i.arrival_time, i.row_number,
           p.first_name, p.middle_name, p.last_name, p.linkedin, p.city, p.state, p.country
      FROM entity_resolution.person_alias pm
      JOIN entity_resolution.person_match_input i USING (transaction_id)
      LEFT JOIN config.entity_resolution_order ero ON ero.entity_type = 'person' AND ero.source_id = pm.source_id
      JOIN silver.person p USING (transaction_id)
), ranked AS (
    SELECT member.*,
           row_number() OVER (PARTITION BY person_id ORDER BY priority, arrival_time DESC, row_number DESC) AS survivor_rank
      FROM member
), person_values AS (
    SELECT m.person_id,
        first(m.first_name  ORDER BY m.survivor_rank) FILTER (WHERE m.first_name IS NOT NULL)  AS first_name,
        first(m.middle_name ORDER BY m.survivor_rank) FILTER (WHERE m.middle_name IS NOT NULL) AS middle_name,
        first(m.last_name   ORDER BY m.survivor_rank) FILTER (WHERE m.last_name IS NOT NULL)   AS last_name,
        first(m.linkedin    ORDER BY m.survivor_rank) FILTER (WHERE m.linkedin IS NOT NULL)    AS linkedin,
        first(m.city        ORDER BY m.survivor_rank) FILTER (WHERE m.city IS NOT NULL)        AS city,
        first(m.state       ORDER BY m.survivor_rank) FILTER (WHERE m.state IS NOT NULL)       AS state,
        first(m.country     ORDER BY m.survivor_rank) FILTER (WHERE m.country IS NOT NULL)     AS country,
        bool_or(m.is_pending_review) AS is_pending_review
      FROM ranked m
     GROUP BY m.person_id
), primary_affiliation AS (
    -- A current affiliation first, then the latest start date.
    SELECT DISTINCT ON (a.person_id) a.*
      FROM affiliation a
     ORDER BY a.person_id, a.is_current DESC, a.start_date DESC NULLS LAST, a.company_id
)
SELECT v.person_id, v.first_name, v.middle_name, v.last_name, v.linkedin, v.city, v.state, v.country,
       pa.company_id, pa.title, pa.email, pa.phone, pa.start_date, pa.end_date, pa.is_current,
       (SELECT count(*) FROM affiliation a WHERE a.person_id = v.person_id),
       v.is_pending_review
  FROM person_values v
  LEFT JOIN primary_affiliation pa ON pa.person_id = v.person_id;
