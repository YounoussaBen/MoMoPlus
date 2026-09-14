from __future__ import annotations

import logging
import secrets
from datetime import timedelta

from django.conf import settings
from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import User
from project.apps.accounts.phone_numbers import (
    InvalidPhoneNumber,
    detect_ghana_network,
    ghana_national_phone,
    normalize_ghana_phone,
)
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
    try:
        normalized_phone = ghana_national_phone(phone_number)
    except InvalidPhoneNumber as exc:
        raise ValueError(str(exc)) from exc

    existing_wallet = _find_wallet_for_phone(user=user, normalized_phone=normalized_phone)
    if existing_wallet is not None:
        raise ValueError("This phone number is already added to your account.")

    wallet = Wallet.objects.create(
        user=user,
        phone_number=normalized_phone,
        network=network,
    )
    send_otp(wallet)
    return wallet


@transaction.atomic
def ensure_signup_wallet(*, user: User) -> Wallet | None:
    """Create or repair the wallet backed by the user's verified signup phone.

    Supabase has already verified this phone before the mobile app calls the
    backend sync endpoint, so this wallet does not need a second wallet OTP.
    """

    if not user.phone:
        return None

    try:
        phone_number = ghana_national_phone(user.phone)
        network = detect_ghana_network(user.phone)
    except InvalidPhoneNumber:
        logger.warning("Could not create signup wallet for user %s: invalid phone.", user.pk)
        return None

    if network is None:
        logger.warning("Could not create signup wallet for user %s: unknown network prefix.", user.pk)
        return None

    wallet = _find_wallet_for_phone(user=user, normalized_phone=phone_number)
    if wallet is None:
        has_verified_wallet = Wallet.objects.filter(user=user, is_verified=True).exists()
        wallet = Wallet.objects.create(
            user=user,
            phone_number=phone_number,
            network=network,
            is_verified=True,
            is_default=not has_verified_wallet,
            is_signup_wallet=True,
        )
    else:
        update_fields: list[str] = []
        if not wallet.is_signup_wallet:
            wallet.is_signup_wallet = True
            update_fields.append("is_signup_wallet")
        if not wallet.is_verified:
            wallet.is_verified = True
            update_fields.append("is_verified")
        if not Wallet.objects.filter(user=user, is_default=True).exclude(pk=wallet.pk).exists():
            if not wallet.is_default:
                wallet.is_default = True
                update_fields.append("is_default")
        if update_fields:
            update_fields.append("updated_at")
            wallet.save(update_fields=update_fields)

    # Paystack setup is best-effort here. The signup wallet is already
    # ownership-verified by the Supabase OTP, and a transient provider issue
    # must not prevent the user from completing signup. A later sync retries it.
    if wallet.is_verified and not wallet.paystack_recipient_code:
        try:
            _create_paystack_recipient(wallet)
        except Exception:
            logger.exception("Could not set up Paystack recipient for signup wallet %s.", wallet.pk)
        else:
            wallet.save(update_fields=["paystack_recipient_code", "updated_at"])

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

    if wallet.is_signup_wallet or _is_user_phone_wallet(user=user, wallet=wallet):
        raise ValueError("Your signup wallet cannot be removed.")

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


def _find_wallet_for_phone(*, user: User, normalized_phone: str) -> Wallet | None:
    """Find a user's wallet while tolerating legacy phone formats."""

    for wallet in Wallet.objects.select_for_update().filter(user=user):
        try:
            if ghana_national_phone(wallet.phone_number) == normalized_phone:
                return wallet
        except InvalidPhoneNumber:
            continue
    return None


def _is_user_phone_wallet(*, user: User, wallet: Wallet) -> bool:
    """Protect legacy signup wallets created before the flag was introduced."""

    if not user.phone:
        return False
    try:
        return ghana_national_phone(user.phone) == ghana_national_phone(wallet.phone_number)
    except InvalidPhoneNumber:
        return False
