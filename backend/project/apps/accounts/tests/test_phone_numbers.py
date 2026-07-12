import pytest

from project.apps.accounts.phone_numbers import InvalidPhoneNumber, arkesel_recipient, normalize_ghana_phone


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
