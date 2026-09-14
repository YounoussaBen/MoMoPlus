import pytest

from project.apps.accounts.phone_numbers import (
    InvalidPhoneNumber,
    arkesel_recipient,
    detect_ghana_network,
    ghana_national_phone,
    normalize_ghana_phone,
)


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("0241234567", "+233241234567"),
        ("241234567", "+233241234567"),
        ("233241234567", "+233241234567"),
        ("+233 24 123 4567", "+233241234567"),
        ("055-123-4567", "+233551234567"),
    ],
)
def test_normalizes_supported_ghana_mobile_formats(raw, expected):
    assert normalize_ghana_phone(raw) == expected


@pytest.mark.parametrize("raw", [None, "", "abc", "123", "+233301234567", "02412345678"])
def test_rejects_invalid_or_non_mobile_numbers(raw):
    with pytest.raises(InvalidPhoneNumber):
        normalize_ghana_phone(raw)


def test_arkesel_recipient_is_digits_only():
    assert arkesel_recipient("+233241234567") == "233241234567"


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("+233241234567", "0241234567"),
        ("0551234567", "0551234567"),
    ],
)
def test_returns_normalized_local_ghana_number(raw, expected):
    assert ghana_national_phone(raw) == expected


@pytest.mark.parametrize(
    ("raw", "expected"),
    [
        ("0241234567", "mtn"),
        ("0501234567", "vodafone"),
        ("0271234567", "airteltigo"),
        ("+233 59 123 4567", "mtn"),
    ],
)
def test_detects_supported_ghana_mobile_network(raw, expected):
    assert detect_ghana_network(raw) == expected


def test_returns_none_for_valid_but_unmapped_mobile_prefix():
    assert detect_ghana_network("0281234567") is None
