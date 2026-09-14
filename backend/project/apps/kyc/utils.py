from __future__ import annotations

import re
import unicodedata

_GHANA_CARD_NUMBER_RE = re.compile(r"^GHA\d{10}$")
_PERSON_NAME_TOKEN_RE = re.compile(r"[^\W_]+", flags=re.UNICODE)


def normalize_ghana_card_number(value: str) -> str:
    """Return a canonical Ghana Card number or raise ValueError."""
    compact = re.sub(r"[\s-]+", "", str(value or "")).upper()
    if not _GHANA_CARD_NUMBER_RE.fullmatch(compact):
        raise ValueError("Enter a valid Ghana Card number in the format GHA-XXXXXXXXX-X.")

    return f"GHA-{compact[3:12]}-{compact[12:]}"


def normalize_person_name(value: str) -> str:
    """Normalize a person's name for a strict, user-to-registry comparison."""
    decomposed = unicodedata.normalize("NFKD", str(value or ""))
    without_diacritics = "".join(char for char in decomposed if not unicodedata.combining(char))
    return " ".join(_PERSON_NAME_TOKEN_RE.findall(without_diacritics.casefold()))


def mask_ghana_card_number(value: str) -> str:
    """Mask the middle digits when displaying a Ghana Card number in a list."""
    normalized = normalize_ghana_card_number(value)
    digits = normalized.replace("-", "")
    return f"GHA-******{digits[-2:]}"
