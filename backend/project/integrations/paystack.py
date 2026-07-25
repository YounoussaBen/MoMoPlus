"""Paystack API integration for mobile money payments in Ghana."""

from __future__ import annotations

import hashlib
import hmac
import logging
from dataclasses import dataclass
from typing import Any

import httpx
from django.conf import settings

logger = logging.getLogger(__name__)

BASE_URL = "https://api.paystack.co"
TIMEOUT = 30


def _headers() -> dict[str, str]:
    return {
        "Authorization": f"Bearer {settings.PAYSTACK_SECRET_KEY}",
        "Content-Type": "application/json",
    }


def _error_message(body: dict[str, Any], fallback: str = "Paystack request failed") -> str:
    data = body.get("data")
    if isinstance(data, dict):
        nested_message = data.get("message")
        if isinstance(nested_message, str) and nested_message.strip():
            return nested_message.strip()

        nested_status = data.get("status")
        top_level_message = body.get("message")
        if (
            isinstance(nested_status, str)
            and nested_status.strip()
            and isinstance(top_level_message, str)
            and top_level_message.strip()
        ):
            return f"{top_level_message.strip()} ({nested_status.strip()})"

    message = body.get("message")
    if isinstance(message, str) and message.strip():
        return message.strip()

    return fallback


def _post(path: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = httpx.post(url, json=data or {}, headers=_headers(), timeout=TIMEOUT)
    body = resp.json()
    if not body.get("status"):
        msg = _error_message(body)
        logger.error("Paystack POST %s failed (%s): %s", path, resp.status_code, msg)
        raise PaystackError(msg, response=body)
    return body


def _get(path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = httpx.get(url, params=params, headers=_headers(), timeout=TIMEOUT)
    body = resp.json()
    if not body.get("status"):
        msg = _error_message(body)
        logger.error("Paystack GET %s failed (%s): %s", path, resp.status_code, msg)
        raise PaystackError(msg, response=body)
    return body


class PaystackError(Exception):
    def __init__(self, message: str, response: dict | None = None):
        super().__init__(message)
        self.response = response


# ── Banks / Providers ────────────────────────────────────────────────────────


NETWORK_TO_BANK_CODE = {
    "mtn": "MTN",
    "vodafone": "VOD",
    "airteltigo": "ATL",
}

NETWORK_TO_PROVIDER = {
    "mtn": "mtn",
    "vodafone": "vod",
    "airteltigo": "atl",
}


@dataclass(frozen=True)
class MobileMoneyDetails:
    """Paystack-facing details for a locally stored wallet."""

    phone: str
    provider: str
    bank_code: str
    is_test_override: bool = False


def mobile_money_details(*, phone: str, network: str) -> MobileMoneyDetails:
    """Resolve the details sent to Paystack without changing local wallet data.

    Paystack's Ghana test MoMo identity is an MTN number, so both the provider
    and bank code must be overridden with the phone. The override is ignored
    for live keys to make accidentally carrying the demo setting to production
    harmless.
    """
    provider = NETWORK_TO_PROVIDER.get(network, "mtn")
    bank_code = NETWORK_TO_BANK_CODE.get(network, "MTN")
    test_phone = str(getattr(settings, "PAYSTACK_TEST_MOBILE_MONEY_PHONE", "")).strip()
    secret_key = str(getattr(settings, "PAYSTACK_SECRET_KEY", "")).strip()

    if not test_phone:
        return MobileMoneyDetails(phone=phone, provider=provider, bank_code=bank_code)

    if not secret_key.startswith("sk_test_"):
        logger.warning("Ignoring PAYSTACK_TEST_MOBILE_MONEY_PHONE because the Paystack key is not a test key.")
        return MobileMoneyDetails(phone=phone, provider=provider, bank_code=bank_code)

    return MobileMoneyDetails(
        phone=test_phone,
        provider=NETWORK_TO_PROVIDER["mtn"],
        bank_code=NETWORK_TO_BANK_CODE["mtn"],
        is_test_override=True,
    )


def list_mobile_money_banks() -> list[dict[str, Any]]:
    """List supported mobile money providers for GHS."""
    body = _get("/bank", params={"currency": "GHS", "type": "mobile_money"})
    return body.get("data", [])


# ── Transfer Recipients ──────────────────────────────────────────────────────


def create_transfer_recipient(
    *,
    name: str,
    account_number: str,
    bank_code: str,
) -> dict[str, Any]:
    """Create a transfer recipient for mobile money disbursement.

    Returns the full response data including `recipient_code`.
    """
    body = _post(
        "/transferrecipient",
        {
            "type": "mobile_money",
            "name": name,
            "account_number": account_number,
            "bank_code": bank_code,
            "currency": "GHS",
        },
    )
    return body["data"]


# ── Transfers (Disbursement) ─────────────────────────────────────────────────


def initiate_transfer(
    *,
    amount_pesewas: int,
    recipient_code: str,
    reference: str,
    reason: str = "",
) -> dict[str, Any]:
    """Initiate a transfer (disbursement) to a mobile money wallet.

    `amount_pesewas` is in pesewas (GHS 10 = 1000 pesewas).
    """
    payload: dict[str, Any] = {
        "source": "balance",
        "amount": amount_pesewas,
        "recipient": recipient_code,
        "currency": "GHS",
        "reference": reference,
    }
    if reason:
        payload["reason"] = reason

    body = _post("/transfer", payload)
    return body["data"]


# ── Charges (Collection / Repayment) ─────────────────────────────────────────


def charge_mobile_money(
    *,
    amount_pesewas: int,
    phone: str,
    provider: str,
    reference: str,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Charge a mobile money wallet (e.g. for loan repayment).

    `provider` should be one of: mtn, vod, atl.
    `amount_pesewas` is in pesewas (GHS 10 = 1000 pesewas).
    """
    payload: dict[str, Any] = {
        "email": settings.PAYSTACK_PAYMENT_EMAIL,
        "amount": amount_pesewas,
        "currency": "GHS",
        "mobile_money": {
            "phone": phone,
            "provider": provider,
        },
        "reference": reference,
    }
    if metadata:
        payload["metadata"] = metadata

    body = _post("/charge", payload)
    return body["data"]


# ── Transaction Verification ─────────────────────────────────────────────────


def get_balances() -> list[dict[str, Any]]:
    """Return all Paystack balances."""
    body = _get("/balance")
    data = body.get("data", [])
    return data if isinstance(data, list) else []


def verify_transaction(reference: str) -> dict[str, Any]:
    """Verify a transaction by reference."""
    body = _get(f"/transaction/verify/{reference}")
    return body["data"]


# ── Webhook Verification ─────────────────────────────────────────────────────


def verify_webhook_signature(*, payload: bytes, signature: str) -> bool:
    """Verify that a webhook payload was signed by Paystack."""
    expected = hmac.new(
        settings.PAYSTACK_SECRET_KEY.encode(),
        payload,
        hashlib.sha512,
    ).hexdigest()
    return hmac.compare_digest(expected, signature)
