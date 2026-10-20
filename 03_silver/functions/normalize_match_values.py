"""Match-only normalization: turns raw silver values into the comparable values stored in
entity_resolution.<domain>_match_input (one value per column). Never written back to silver, so silver keeps
display values.

  - company_name:  lowercase, '&' -> 'and', punctuation removed. Every word is kept: legal forms (Inc, LLC) and
                   extra words are absorbed by token set similarity, not stripped by a word list.
                   "X dba Y" stays one name; token set similarity already scores it high against "X" or "Y".
  - domain:        URL or domain -> bare domain ("https://www.Example.com/about" -> "example.com").
  - phone:         digits only, last 10 digits (fewer than 10 digits -> no value).
  - linkedin:      lowercase URL without scheme, "www." or trailing slash.
  - text:          trimmed and lowercased (names, city, state, email).
Each function returns None when there is nothing usable.
"""

import re


def company_name(raw: str | None) -> str | None:
    """'The Shyft Group, Inc.' -> 'the shyft group inc'; 'Jordahl & Sliter, PLLC' -> 'jordahl and sliter pllc'."""
    if not raw:
        return None
    return " ".join(re.sub(r"[^a-z0-9 ]", " ", raw.lower().replace("&", " and ")).split()) or None


def domain(raw: str | None) -> str | None:
    """URL or domain -> bare domain: 'https://www.Example.com/about' -> 'example.com'."""
    if not raw:
        return None
    value = re.sub(r"^[a-z]+://", "", raw.strip().lower())
    value = re.sub(r"^www\.", "", value)
    value = re.split(r"[/?#:]", value)[0]
    return value or None


def phone(raw: str | None) -> str | None:
    """Last 10 digits; None if fewer than 10."""
    digits = re.sub(r"\D", "", raw or "")
    return digits[-10:] if len(digits) >= 10 else None


def text(raw: str | None) -> str | None:
    value = (raw or "").strip().lower()
    return value or None


def linkedin(raw: str | None) -> str | None:
    """'https://www.LinkedIn.com/in/jane-doe-12/' -> 'linkedin.com/in/jane-doe-12'."""
    if not raw:
        return None
    value = re.sub(r"^[a-z]+://", "", raw.strip().lower())
    value = re.sub(r"^www\.", "", value)
    value = re.split(r"[?#]", value)[0].rstrip("/")
    return value or None
