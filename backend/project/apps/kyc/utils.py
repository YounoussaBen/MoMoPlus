from __future__ import annotations

import re

_GHANA_CARD_NUMBER_RE = re.compile(r"^GHA\d{10}$")


def normalize_ghana_card_number(value: str) -> str:
    """Return a canonical Ghana Card number or raise ValueError."""
    compact = re.sub(r"[\s-]+", "", str(value or "")).upper()
    if not _GHANA_CARD_NUMBER_RE.fullmatch(compact):
        raise ValueError("Enter a valid Ghana Card number in the format GHA-XXXXXXXXX-X.")

    return f"GHA-{compact[3:12]}-{compact[12:]}"


def mask_ghana_card_number(value: str) -> str:
    """Mask the middle digits when displaying a Ghana Card number in a list."""
    normalized = normalize_ghana_card_number(value)
    digits = normalized.replace("-", "")
    return f"GHA-******{digits[-2:]}"
