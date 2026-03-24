from __future__ import annotations

import logging
import random
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.integrations import paystack

from .models import Wallet, WalletOtp

logger = logging.getLogger(__name__)

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
    existing_wallet = Wallet.objects.filter(phone_number=phone_number).first()
    if existing_wallet is not None:
        if existing_wallet.user_id == user.pk:
            raise ValueError("This phone number is already added to your account.")
        raise ValueError(
            "This phone number is already linked to another account. Remove it there before adding it here."
        )

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

    # Create Paystack subaccount and transfer recipient for this wallet
    _create_paystack_accounts(wallet)

    wallet.save(
        update_fields=[
            "is_verified",
            "is_default",
            "paystack_subaccount_code",
            "paystack_recipient_code",
            "updated_at",
        ]
    )
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


def _create_paystack_accounts(wallet: Wallet) -> None:
    """Create the Paystack records required before a wallet is considered verified."""
    if not getattr(settings, "PAYSTACK_SECRET_KEY", ""):
        logger.info("Paystack secret key not configured; skipping subaccount creation for wallet %s", wallet.pk)
        return

    user = wallet.user
    bank_code = paystack.NETWORK_TO_BANK_CODE.get(wallet.network, "MTN")
    full_name = f"{user.first_name} {user.last_name}".strip() or user.email
    account_number = wallet.phone_number
    subaccount_code = ""

    # 1. Create subaccount (so money can be routed TO this wallet)
    try:
        sub_data = paystack.create_subaccount(
            business_name=f"{full_name} - {wallet.phone_number}",
            bank_code=bank_code,
            account_number=account_number,
            percentage_charge=0.0,
            primary_contact_email=user.email,
            primary_contact_name=full_name,
            primary_contact_phone=wallet.phone_number,
        )
        subaccount_code = sub_data.get("subaccount_code", "")
        wallet.paystack_subaccount_code = subaccount_code
        logger.info("Paystack subaccount created: %s for wallet %s", wallet.paystack_subaccount_code, wallet.pk)
    except paystack.PaystackError as exc:
        logger.exception("Failed to create Paystack subaccount for wallet %s", wallet.pk)
        raise ValueError(f"Wallet verification failed: {exc}")

    # 2. Create transfer recipient (so money can be SENT to this wallet)
    try:
        recip_data = paystack.create_transfer_recipient(
            name=full_name,
            account_number=account_number,
            bank_code=bank_code,
        )
        wallet.paystack_recipient_code = recip_data.get("recipient_code", "")
        logger.info("Paystack recipient created: %s for wallet %s", wallet.paystack_recipient_code, wallet.pk)
    except paystack.PaystackError as exc:
        logger.exception("Failed to create Paystack transfer recipient for wallet %s", wallet.pk)
        if subaccount_code:
            try:
                paystack.deactivate_subaccount(subaccount_code)
            except paystack.PaystackError:
                logger.exception(
                    "Failed to deactivate Paystack subaccount %s after recipient setup failure", subaccount_code
                )
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

    if getattr(settings, "PAYSTACK_SECRET_KEY", "") and wallet.paystack_subaccount_code:
        try:
            paystack.deactivate_subaccount(wallet.paystack_subaccount_code)
        except paystack.PaystackError as exc:
            raise ValueError(f"Failed to remove wallet from Paystack: {exc}")

    was_default = wallet.is_default
    wallet.delete()

    if was_default:
        next_default = Wallet.objects.filter(user=user, is_verified=True).order_by("-created_at").first()
        if next_default:
            next_default.is_default = True
            next_default.save(update_fields=["is_default", "updated_at"])
