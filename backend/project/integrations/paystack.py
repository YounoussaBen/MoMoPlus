"""Paystack API integration for mobile money payments in Ghana."""

from __future__ import annotations

import hashlib
import hmac
import logging
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


def _post(path: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = httpx.post(url, json=data or {}, headers=_headers(), timeout=TIMEOUT)
    body = resp.json()
    if not body.get("status"):
        msg = body.get("message", "Paystack request failed")
        logger.error("Paystack POST %s failed: %s", path, msg)
        raise PaystackError(msg, response=body)
    return body


def _get(path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = httpx.get(url, params=params, headers=_headers(), timeout=TIMEOUT)
    body = resp.json()
    if not body.get("status"):
        msg = body.get("message", "Paystack request failed")
        logger.error("Paystack GET %s failed: %s", path, msg)
        raise PaystackError(msg, response=body)
    return body


def _put(path: str, data: dict[str, Any] | None = None) -> dict[str, Any]:
    url = f"{BASE_URL}{path}"
    resp = httpx.put(url, json=data or {}, headers=_headers(), timeout=TIMEOUT)
    body = resp.json()
    if not body.get("status"):
        msg = body.get("message", "Paystack request failed")
        logger.error("Paystack PUT %s failed: %s", path, msg)
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


def list_mobile_money_banks() -> list[dict[str, Any]]:
    """List supported mobile money providers for GHS."""
    body = _get("/bank", params={"currency": "GHS", "type": "mobile_money"})
    return body.get("data", [])


# ── Subaccounts ──────────────────────────────────────────────────────────────


def create_subaccount(
    *,
    business_name: str,
    bank_code: str,
    account_number: str,
    percentage_charge: float = 0.0,
    primary_contact_email: str = "",
    primary_contact_name: str = "",
    primary_contact_phone: str = "",
) -> dict[str, Any]:
    """Create a Paystack subaccount for a mobile money wallet.

    Returns the full response data including `subaccount_code`.

    `percentage_charge` is the main account's share of split payments.
    Use `0.0` when the subaccount should receive the full split.
    """
    payload: dict[str, Any] = {
        "business_name": business_name,
        "settlement_bank": bank_code,
        "account_number": account_number,
        "percentage_charge": percentage_charge,
    }
    if primary_contact_email:
        payload["primary_contact_email"] = primary_contact_email
    if primary_contact_name:
        payload["primary_contact_name"] = primary_contact_name
    if primary_contact_phone:
        payload["primary_contact_phone"] = primary_contact_phone

    body = _post("/subaccount", payload)
    return body["data"]


def deactivate_subaccount(subaccount_code: str) -> dict[str, Any]:
    """Deactivate a subaccount so it no longer receives settlements."""
    body = _put(f"/subaccount/{subaccount_code}", {"active": False})
    return body["data"]


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
    email: str,
    amount_pesewas: int,
    phone: str,
    provider: str,
    reference: str,
    subaccount_code: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Charge a mobile money wallet (e.g. for loan repayment).

    `provider` should be one of: mtn, vod, atl.
    `amount_pesewas` is in pesewas (GHS 10 = 1000 pesewas).
    """
    payload: dict[str, Any] = {
        "email": email,
        "amount": amount_pesewas,
        "currency": "GHS",
        "mobile_money": {
            "phone": phone,
            "provider": provider,
        },
        "reference": reference,
    }
    if subaccount_code:
        payload["subaccount"] = subaccount_code
        payload["bearer"] = "subaccount"
    if metadata:
        payload["metadata"] = metadata

    body = _post("/charge", payload)
    return body["data"]


# ── Transaction Verification ─────────────────────────────────────────────────


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
