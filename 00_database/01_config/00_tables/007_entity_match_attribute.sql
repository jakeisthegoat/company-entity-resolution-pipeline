-- config.entity_match_attribute
-- One row per entity type x match attribute: how much it counts in the 0-100 score, how it is compared, and
-- whether it is a strong identifier (one must agree for an auto-match). An attribute's value comes from
-- <entity_type>_match_input.
--   comparison_method: exact (equal or not), token_set (word-set similarity, for company names),
--                      jaro_winkler (character similarity, for person names)
--   common_word_pct: words found in at least this % of the attribute's values are ignored when comparing (for
--                    company names: inc, llc, the, group, ...). Computed from the data on every run, so no word
--                    list is kept. A value made only of common words is compared whole. NULL = keep every word.
-- Idempotent: CREATE TABLE IF NOT EXISTS.

CREATE TABLE IF NOT EXISTS config.entity_match_attribute (
    entity_type VARCHAR(20) NOT NULL,  -- -> config.entity_match_setting
    attribute_name VARCHAR(50) NOT NULL,
    weight NUMERIC(5,2) NOT NULL CHECK (weight > 0),
    comparison_method VARCHAR(20) NOT NULL CHECK (comparison_method IN ('exact', 'token_set', 'jaro_winkler')),
    is_strong_identifier BOOLEAN NOT NULL DEFAULT false,
    common_word_pct NUMERIC(5,2) CHECK (common_word_pct > 0 AND common_word_pct <= 100),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (entity_type, attribute_name)
);
