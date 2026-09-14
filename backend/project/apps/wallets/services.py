from __future__ import annotations

import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.apps.accounts.phone_numbers import normalize_ghana_phone
from project.integrations import paystack

from .models import Wallet, WalletOtp
from .tasks import send_wallet_otp_task

logger = logging.getLogger(__name__)

OTP_EXPIRY_MINUTES = 10


def _generate_otp_code() -> str:
    return f"{secrets.randbelow(1_000_000):06d}"


def _send_otp_message(phone_number: str, code: str) -> None:
    """Queue wallet OTP delivery after the current database transaction commits."""

    normalized_phone = normalize_ghana_phone(phone_number)

    def enqueue_delivery() -> None:
        try:
            send_wallet_otp_task.delay(phone=normalized_phone, otp_code=code)
        except Exception:
            # The wallet and OTP are already committed when this callback runs.
            # Keep the request successful and leave the failure visible to the
            # application logs so the user can request another OTP.
            logger.exception("Could not queue background wallet SMS delivery.")

    transaction.on_commit(enqueue_delivery)


def send_otp(wallet: Wallet) -> WalletOtp:
    """Generate a new wallet OTP and queue its SMS delivery."""
    code = _generate_otp_code()
    otp = WalletOtp.objects.create(
        wallet=wallet,
        code=code,
        expires_at=timezone.now() + timedelta(minutes=OTP_EXPIRY_MINUTES),
    )
    _send_otp_message(wallet.phone_number, code)
    return otp


@transaction.atomic
def add_wallet(*, user: User, phone_number: str, network: str) -> Wallet:
    """Add a new wallet and queue its verification OTP."""
    existing_wallet = Wallet.objects.filter(user=user, phone_number=phone_number).first()
    if existing_wallet is not None:
        raise ValueError("This phone number is already added to your account.")

    wallet = Wallet.objects.create(
        user=user,
        phone_number=phone_number,
        network=network,
    )
    send_otp(wallet)
    return wallet


@transaction.atomic
def verify_otp(*, wallet: Wallet, code: str) -> Wallet:
    """Verify an OTP code and mark the wallet as verified."""
    if wallet.is_verified:
        raise ValueError("This wallet is already verified.")

    now = timezone.now()
    otp = (
        WalletOtp.objects.filter(
            wallet=wallet,
            code=code,
            used=False,
            expires_at__gt=now,
        )
        .order_by("-created_at")
        .first()
    )

    if otp is None:
        raise ValueError("Invalid or expired OTP code.")

    otp.used = True
    otp.save(update_fields=["used", "updated_at"])

    wallet.is_verified = True

    # Auto-set as default if this is the user's first verified wallet
    if not Wallet.objects.filter(user=wallet.user, is_verified=True).exclude(pk=wallet.pk).exists():
        wallet.is_default = True

    # Wallet verification remains a single step: OTP ownership plus
    # successful Paystack recipient creation.
    _create_paystack_recipient(wallet)

    wallet.save(
        update_fields=[
            "is_verified",
            "is_default",
            "paystack_recipient_code",
            "updated_at",
        ]
    )
    return wallet


@transaction.atomic
def resend_otp(*, wallet: Wallet) -> WalletOtp:
    """Invalidate existing OTPs and send a new one."""
    if wallet.is_verified:
        raise ValueError("This wallet is already verified.")

    WalletOtp.objects.filter(wallet=wallet, used=False).update(used=True)
    return send_otp(wallet)


@transaction.atomic
def set_default_wallet(*, user: User, wallet: Wallet) -> Wallet:
    """Set a wallet as the user's default."""
    if wallet.user_id != user.pk:
        raise ValueError("Wallet does not belong to this user.")

    if not wallet.is_verified:
        raise ValueError("Only verified wallets can be set as default.")

    Wallet.objects.filter(user=user, is_default=True).update(is_default=False)
    wallet.is_default = True
    wallet.save(update_fields=["is_default", "updated_at"])
    return wallet


def _create_paystack_recipient(wallet: Wallet) -> None:
    """Create the Paystack transfer recipient required before wallet verification succeeds."""
    if not getattr(settings, "PAYSTACK_SECRET_KEY", ""):
        raise ValueError("Wallet verification failed: Paystack is not configured.")

    user = wallet.user
    full_name = f"{user.first_name} {user.last_name}".strip() or user.email
    paystack_wallet = paystack.mobile_money_details(
        phone=wallet.phone_number,
        network=wallet.network,
    )

    # Create the transfer recipient used for both disbursement and repayment transfers.
    try:
        recip_data = paystack.create_transfer_recipient(
            name=full_name,
            account_number=paystack_wallet.phone,
            bank_code=paystack_wallet.bank_code,
        )
        wallet.paystack_recipient_code = recip_data.get("recipient_code", "")
        logger.info("Paystack recipient created: %s for wallet %s", wallet.paystack_recipient_code, wallet.pk)
    except paystack.PaystackError as exc:
        logger.exception("Failed to create Paystack transfer recipient for wallet %s", wallet.pk)
        raise ValueError(f"Wallet verification failed: {exc}")


@transaction.atomic
def delete_wallet(*, user: User, wallet: Wallet) -> None:
    """Delete a wallet and promote another default if needed."""
    if wallet.user_id != user.pk:
        raise ValueError("Wallet does not belong to this user.")

    if wallet.is_verified:
        verified_count = Wallet.objects.filter(user=user, is_verified=True).count()
        if verified_count <= 1:
            raise ValueError(
                "You must have at least one verified wallet. Add another wallet before deleting this one."
            )

    was_default = wallet.is_default
    wallet.delete()

    if was_default:
        next_default = Wallet.objects.filter(user=user, is_verified=True).order_by("-created_at").first()
        if next_default:
            next_default.is_default = True
            next_default.save(update_fields=["is_default", "updated_at"])
