from __future__ import annotations

import json
import logging
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings

from project.apps.accounts.phone_numbers import arkesel_recipient

logger = logging.getLogger(__name__)


def _safe_provider_summary(response_body: bytes) -> dict[str, object]:
    """Return provider diagnostics without customer or credential fields."""

    if not response_body:
        return {"response": "empty"}

    try:
        payload = json.loads(response_body.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        return {"response": "invalid-json", "body_length": len(response_body)}

    if not isinstance(payload, dict):
        return {"response": "unexpected-shape"}

    summary: dict[str, object] = {}
    for key in ("status", "message", "error"):
        value = payload.get(key)
        if isinstance(value, str | int | float | bool) or value is None:
            if value is not None:
                summary[key] = str(value).replace("\n", " ")[:500]
            continue
        if isinstance(value, dict):
            nested = {
                nested_key: str(nested_value).replace("\n", " ")[:500]
                for nested_key in ("status", "code", "message", "detail")
                if isinstance((nested_value := value.get(nested_key)), str | int | float | bool)
            }
            if nested:
                summary[key] = nested

    return summary or {"response": "no-safe-diagnostic-fields"}


class SmsDeliveryError(RuntimeError):
    """Stable application error for provider failures."""


def send_sms(*, phone: str, message: str) -> None:
    """Send a transactional SMS through Arkesel V2.

    Credentials, message bodies and full provider responses are intentionally
    excluded from exceptions so callers can log failures safely.
    """

    api_key = settings.ARKESEL_API_KEY
    sender_id = settings.ARKESEL_SENDER_ID
    api_url = settings.ARKESEL_API_URL
    if not api_key or not sender_id or not api_url:
        missing_variables = [
            name
            for name, value in (
                ("ARKESEL_API_KEY", api_key),
                ("ARKESEL_SENDER_ID", sender_id),
                ("ARKESEL_API_URL", api_url),
            )
            if not value
        ]
        logger.warning(
            "Temporary Arkesel diagnostic: SMS delivery configuration missing variables=%s",
            missing_variables,
        )
        raise SmsDeliveryError("SMS delivery is not configured.")

    payload = json.dumps(
        {
            "sender": sender_id,
            "message": message,
            "recipients": [arkesel_recipient(phone)],
        }
    ).encode("utf-8")
    request = Request(
        api_url,
        method="POST",
        data=payload,
        headers={
            "api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "application/json",
            # Cloudflare blocks urllib's default Python-urllib signature.
            "User-Agent": "MoMoPlus-Backend/1.0",
        },
    )

    try:
        with urlopen(request, timeout=settings.ARKESEL_HTTP_TIMEOUT) as response:
            response_body = response.read()
    except HTTPError as exc:
        try:
            response_body = exc.read()
        except (AttributeError, OSError, ValueError):
            response_body = b""
        logger.warning(
            "Temporary Arkesel diagnostic: request rejected http_status=%s sender_id=%r provider=%s",
            exc.code,
            sender_id,
            _safe_provider_summary(response_body),
        )
        raise SmsDeliveryError("SMS provider rejected the request.") from exc
    except URLError as exc:
        logger.warning(
            "Temporary Arkesel diagnostic: request failed before response sender_id=%r reason_type=%s",
            sender_id,
            type(exc.reason).__name__,
        )
        raise SmsDeliveryError("SMS provider rejected the request.") from exc
    except TimeoutError as exc:
        logger.warning(
            "Temporary Arkesel diagnostic: request timed out sender_id=%r timeout_seconds=%s",
            sender_id,
            settings.ARKESEL_HTTP_TIMEOUT,
        )
        raise SmsDeliveryError("SMS provider rejected the request.") from exc

    try:
        provider_response = json.loads(response_body.decode("utf-8")) if response_body else {}
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        logger.warning(
            "Temporary Arkesel diagnostic: invalid provider response sender_id=%r provider=%s",
            sender_id,
            _safe_provider_summary(response_body),
        )
        raise SmsDeliveryError("SMS provider returned an invalid response.") from exc

    if not isinstance(provider_response, dict) or provider_response.get("status") != "success":
        logger.warning(
            "Temporary Arkesel diagnostic: message not accepted sender_id=%r provider=%s",
            sender_id,
            _safe_provider_summary(response_body),
        )
        raise SmsDeliveryError("SMS provider did not accept the message.")


def send_login_otp(*, phone: str, otp_code: str) -> None:
    send_sms(
        phone=phone,
        message=(
            f"MoMo Plus: Your sign-in verification code is {otp_code}. "
            "Use it to complete your sign-in. Do not share this code with anyone."
        ),
    )


def send_wallet_otp(*, phone: str, otp_code: str) -> None:
    send_sms(
        phone=phone,
        message=(f"MoMo Plus: Your wallet verification code is {otp_code}. " "Do not share this code with anyone."),
    )


def send_guarantor_otp(*, phone: str, otp_code: str, borrower_name: str) -> None:
    """Tell a proposed guarantor what sharing the OTP authorizes."""

    send_sms(
        phone=phone,
        message=(
            f"MoMo Plus: {borrower_name} added you as a loan guarantor. "
            f"Code: {otp_code}. Sharing this code confirms your consent. "
            "Do not share it if you do not agree."
        ),
    )
