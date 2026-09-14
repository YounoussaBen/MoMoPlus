from __future__ import annotations

import re

GHANA_NETWORK_PREFIXES: dict[str, frozenset[str]] = {
    "mtn": frozenset({"024", "025", "053", "054", "055", "059"}),
    "vodafone": frozenset({"020", "050"}),
    "airteltigo": frozenset({"026", "027", "056", "057"}),
}


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


def ghana_national_phone(raw: object) -> str:
    """Return a normalized Ghana mobile number with its local trunk zero."""

    return f"0{normalize_ghana_phone(raw)[4:]}"


def detect_ghana_network(raw: object) -> str | None:
    """Infer the mobile-money network from a Ghana mobile prefix.

    This follows the supported prefix assignments used by the mobile wallet
    flow. A number with a valid Ghana mobile shape but an unknown prefix is
    returned as ``None`` so account creation is never blocked by an unmapped
    numbering-plan range.
    """

    phone = ghana_national_phone(raw)
    prefix = phone[:3]
    for network, prefixes in GHANA_NETWORK_PREFIXES.items():
        if prefix in prefixes:
            return network
    return None
