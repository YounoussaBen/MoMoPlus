from __future__ import annotations

import logging
from concurrent.futures import Future, ThreadPoolExecutor

from project.integrations.sms_gateway import SmsDeliveryError, send_login_otp

logger = logging.getLogger(__name__)

# Supabase HTTP hooks must finish within five seconds, while Arkesel can take
# longer to acknowledge an SMS it has already dispatched. Keep login delivery
# off the hook response path until a durable Celery worker is deployed.
_executor = ThreadPoolExecutor(max_workers=2, thread_name_prefix="login-sms")


class SmsDispatchError(RuntimeError):
    """Raised when login SMS delivery cannot be submitted for execution."""


def dispatch_login_otp(*, phone: str, otp_code: str) -> Future[None]:
    try:
        return _executor.submit(_deliver_login_otp, phone=phone, otp_code=otp_code)
    except RuntimeError as exc:
        raise SmsDispatchError("SMS delivery could not be dispatched.") from exc


def _deliver_login_otp(*, phone: str, otp_code: str) -> None:
    try:
        send_login_otp(phone=phone, otp_code=otp_code)
    except SmsDeliveryError:
        logger.warning("Background login SMS delivery failed.")
    except Exception:
        logger.exception("Unexpected background login SMS delivery failure.")
