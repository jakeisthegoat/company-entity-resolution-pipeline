-- Seed: config.entity_match_attribute
-- Company: name 40 (token set; words in at least 2% of names, such as inc, llc, the, are ignored), domain 30,
-- phone 20, city 5, state 5; strong identifiers domain and phone.
-- Person: last name 30, first name 20 (Jaro-Winkler), LinkedIn 20, email 15, resolved company 30; strong identifiers
-- LinkedIn and email. The person company weight is 30 so namesakes at different companies stay apart.
-- Upsert by (entity_type, attribute_name).

INSERT INTO config.entity_match_attribute (entity_type, attribute_name, weight, comparison_method, is_strong_identifier, common_word_pct)
VALUES
    ('company', 'name',       40, 'token_set',    false, 2),
    ('company', 'domain',     30, 'exact',        true,  NULL),
    ('company', 'phone',      20, 'exact',        true,  NULL),
    ('company', 'city',        5, 'exact',        false, NULL),
    ('company', 'state',       5, 'exact',        false, NULL),
    ('person',  'last_name',  30, 'jaro_winkler', false, NULL),
    ('person',  'first_name', 20, 'jaro_winkler', false, NULL),
    ('person',  'linkedin',   20, 'exact',        true,  NULL),
    ('person',  'email',      15, 'exact',        true,  NULL),
    ('person',  'company',    30, 'exact',        false, NULL)
ON CONFLICT (entity_type, attribute_name) DO UPDATE SET
    weight               = EXCLUDED.weight,
    comparison_method    = EXCLUDED.comparison_method,
    is_strong_identifier = EXCLUDED.is_strong_identifier,
    common_word_pct      = EXCLUDED.common_word_pct,
    updated_at           = now();
