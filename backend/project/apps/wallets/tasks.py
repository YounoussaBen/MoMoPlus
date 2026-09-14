"""Background tasks for wallet integrations."""

from __future__ import annotations

import logging

from celery import shared_task

from project.integrations.sms_gateway import SmsDeliveryError, send_wallet_otp

logger = logging.getLogger(__name__)


@shared_task(name="wallets.send_wallet_otp")
def send_wallet_otp_task(*, phone: str, otp_code: str) -> None:
    """Deliver a wallet verification OTP from a Celery worker."""

    try:
        send_wallet_otp(phone=phone, otp_code=otp_code)
    except SmsDeliveryError:
        logger.warning("Background wallet SMS delivery failed.")
    except Exception:
        logger.exception("Unexpected background wallet SMS delivery failure.")
