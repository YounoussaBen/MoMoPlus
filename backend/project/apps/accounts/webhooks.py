from __future__ import annotations

import base64
import binascii
import hashlib
import hmac
import time


class WebhookSignatureError(ValueError):
    """Raised when a Standard Webhooks signature cannot be trusted."""


def verify_standard_webhook(
    *,
    raw_body: bytes,
    webhook_id: str | None,
    webhook_timestamp: str | None,
    webhook_signature: str | None,
    secret: str,
    tolerance_seconds: int = 300,
    now: int | None = None,
) -> None:
    if not secret or not webhook_id or not webhook_timestamp or not webhook_signature:
        raise WebhookSignatureError("Invalid webhook signature.")

    try:
        timestamp = int(webhook_timestamp)
    except (TypeError, ValueError) as exc:
        raise WebhookSignatureError("Invalid webhook signature.") from exc

    current_time = int(time.time()) if now is None else now
    if abs(current_time - timestamp) > tolerance_seconds:
        raise WebhookSignatureError("Invalid webhook signature.")

    encoded_secret = secret.strip()
    if encoded_secret.startswith("v1,"):
        encoded_secret = encoded_secret[3:]
    if encoded_secret.startswith("whsec_"):
        encoded_secret = encoded_secret[6:]

    try:
        key = base64.b64decode(encoded_secret, validate=True)
        body_text = raw_body.decode("utf-8")
    except (binascii.Error, UnicodeDecodeError) as exc:
        raise WebhookSignatureError("Invalid webhook signature.") from exc

    signed_content = f"{webhook_id}.{webhook_timestamp}.{body_text}".encode()
    expected = base64.b64encode(hmac.new(key, signed_content, hashlib.sha256).digest()).decode()

    candidates: list[str] = []
    for part in webhook_signature.replace(",", " ").split():
        if part == "v1":
            continue
        if part.startswith("v1="):
            candidates.append(part[3:])
        else:
            candidates.append(part)

    if not any(hmac.compare_digest(expected, candidate) for candidate in candidates):
        raise WebhookSignatureError("Invalid webhook signature.")
