from __future__ import annotations

import random
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User

from .models import Wallet, WalletOtp

OTP_EXPIRY_MINUTES = 10


def _generate_otp_code() -> str:
    return f"{random.randint(0, 999999):06d}"


def _send_otp_message(phone_number: str, code: str) -> None:
    """Placeholder for real SMS delivery. Prints OTP to console."""
    print(f"\n{'=' * 40}")
    print(f"  OTP for {phone_number}: {code}")
    print(f"{'=' * 40}\n")


def send_otp(wallet: Wallet) -> WalletOtp:
    """Generate and send a new OTP for a wallet."""
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
    """Add a new wallet and send OTP for verification."""
    if Wallet.objects.filter(user=user, phone_number=phone_number).exists():
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

    wallet.save(update_fields=["is_verified", "is_default", "updated_at"])
    return wallet


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


@transaction.atomic
def delete_wallet(*, user: User, wallet: Wallet) -> None:
    """Delete a wallet and promote another default if needed."""
    if wallet.user_id != user.pk:
        raise ValueError("Wallet does not belong to this user.")

    was_default = wallet.is_default
    wallet.delete()

    if was_default:
        next_default = Wallet.objects.filter(user=user, is_verified=True).order_by("-created_at").first()
        if next_default:
            next_default.is_default = True
            next_default.save(update_fields=["is_default", "updated_at"])
