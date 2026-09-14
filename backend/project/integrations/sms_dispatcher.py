from __future__ import annotations

from celery.result import AsyncResult

from project.apps.accounts.tasks import send_login_otp_task


class SmsDispatchError(RuntimeError):
    """Raised when login SMS delivery cannot be submitted for execution."""


def dispatch_login_otp(*, phone: str, otp_code: str) -> AsyncResult:
    """Queue a login OTP for delivery by a Celery worker."""

    try:
        return send_login_otp_task.delay(phone=phone, otp_code=otp_code)
    except Exception as exc:
        raise SmsDispatchError("SMS delivery could not be dispatched.") from exc
