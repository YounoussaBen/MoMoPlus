"""Background tasks for account-related integrations."""

from __future__ import annotations

import logging

from celery import shared_task

from project.integrations.sms_gateway import SmsDeliveryError, send_guarantor_otp, send_login_otp

logger = logging.getLogger(__name__)


@shared_task(name="accounts.send_login_otp")
def send_login_otp_task(*, phone: str, otp_code: str) -> None:
    """Deliver a Supabase login OTP from a Celery worker."""

    try:
        send_login_otp(phone=phone, otp_code=otp_code)
    except SmsDeliveryError:
        # Keep provider details and OTP data out of application logs. The task
        # has already left the request path, so a delivery failure must not
        # change the response Supabase receives from its hook.
        logger.warning("Background login SMS delivery failed.")
    except Exception:
        logger.exception("Unexpected background login SMS delivery failure.")


@shared_task(name="accounts.send_guarantor_otp")
def send_guarantor_otp_task(*, phone: str, otp_code: str, borrower_name: str) -> None:
    """Deliver a guarantor consent OTP from a Celery worker."""

    try:
        send_guarantor_otp(phone=phone, otp_code=otp_code, borrower_name=borrower_name)
    except SmsDeliveryError:
        logger.warning("Background guarantor consent SMS delivery failed.")
    except Exception:
        logger.exception("Unexpected background guarantor consent SMS delivery failure.")
