from __future__ import annotations

import json
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from django.conf import settings

from project.apps.accounts.phone_numbers import arkesel_recipient


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
        },
    )

    try:
        with urlopen(request, timeout=settings.ARKESEL_HTTP_TIMEOUT) as response:
            response_body = response.read()
    except (HTTPError, URLError, TimeoutError) as exc:
        raise SmsDeliveryError("SMS provider rejected the request.") from exc

    try:
        provider_response = json.loads(response_body.decode("utf-8")) if response_body else {}
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise SmsDeliveryError("SMS provider returned an invalid response.") from exc

    if provider_response.get("status") != "success":
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
