from __future__ import annotations

import re


class InvalidPhoneNumber(ValueError):
    """Raised when a Ghana phone number cannot be normalized safely."""


def normalize_ghana_phone(raw: object) -> str:
    """Return a Ghana number in canonical E.164 form.

    Accepted customer input forms are ``0241234567``, ``241234567`` and
    ``233241234567`` (with harmless spacing or punctuation).
    """

    if raw is None:
        raise InvalidPhoneNumber("Enter a valid Ghana phone number.")

    value = str(raw).strip()
    if not value or re.search(r"[A-Za-z]", value):
        raise InvalidPhoneNumber("Enter a valid Ghana phone number.")

    digits = re.sub(r"\D", "", value)
    if digits.startswith("233") and len(digits) == 12:
        national = digits[3:]
    elif digits.startswith("0") and len(digits) == 10:
        national = digits[1:]
    elif len(digits) == 9:
        national = digits
    else:
        raise InvalidPhoneNumber("Enter a valid Ghana phone number.")

    # Ghana mobile subscriber numbers start with 2 or 5. This deliberately
    # rejects fixed lines because the login experience requires an SMS-capable
    # number and prevents silently accepting arbitrary 9-digit values.
    if national[0] not in {"2", "5"}:
        raise InvalidPhoneNumber("Enter a valid Ghana mobile number.")

    return f"+233{national}"


def arkesel_recipient(phone: str) -> str:
    """Convert canonical E.164 to Arkesel's digits-only recipient form."""

    return normalize_ghana_phone(phone).removeprefix("+")
