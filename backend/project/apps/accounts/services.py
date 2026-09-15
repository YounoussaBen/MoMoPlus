from __future__ import annotations

import logging
import secrets
from datetime import timedelta
from typing import Any
from uuid import UUID

from django.db import IntegrityError, transaction
from django.utils import timezone

from .models import LoanGuarantor, LoanGuarantorOtp, User
from .phone_numbers import InvalidPhoneNumber, normalize_ghana_phone
from .tasks import send_guarantor_otp_task

logger = logging.getLogger(__name__)

GUARANTOR_OTP_EXPIRY_MINUTES = 5


def sync_user_from_supabase_claims(claims: dict[str, Any]) -> User:
    supabase_user_id = _parse_supabase_user_id(claims)
    phone = _extract_phone(claims)
    email = _extract_email(claims)
    first_name, last_name = _extract_names(claims)

    if phone is None:
        raise ValueError("Supabase token is missing a verified phone identity.")

    with transaction.atomic():
        locked_users = User.objects.select_for_update()
        by_supabase = locked_users.filter(supabase_user_id=supabase_user_id).first()
        by_phone = locked_users.filter(phone=phone).first() if phone else None

        matched = {candidate.pk: candidate for candidate in (by_supabase, by_phone) if candidate}
        if len(matched) > 1:
            raise ValueError("Supabase identity conflicts with more than one local user.")
        user = next(iter(matched.values()), None)

        if user and user.supabase_user_id and user.supabase_user_id != supabase_user_id:
            raise ValueError("Supabase user ID does not match the existing Django user.")
        if user and phone and user.phone and user.phone != phone:
            raise ValueError("Verified phone does not match the existing Django user.")

        if user is None:
            user = User(
                supabase_user_id=supabase_user_id,
                phone=phone,
                email=email,
                username=_build_username(supabase_user_id),
                first_name=first_name,
                last_name=last_name,
                is_active=True,
            )
            user.set_unusable_password()
            try:
                # The nested savepoint keeps the outer transaction usable if
                # two first-login requests race on the same unique identity.
                with transaction.atomic():
                    user.save()
            except IntegrityError as exc:
                raise ValueError("Supabase identity conflicts with an existing local user.") from exc
            return user

        changed_fields: list[str] = []

        if user.supabase_user_id != supabase_user_id:
            user.supabase_user_id = supabase_user_id
            changed_fields.append("supabase_user_id")

        if phone and user.phone != phone:
            user.phone = phone
            changed_fields.append("phone")

        if email and user.email != email:
            user.email = email
            changed_fields.append("email")

        if first_name and first_name != user.first_name:
            user.first_name = first_name
            changed_fields.append("first_name")

        if last_name and last_name != user.last_name:
            user.last_name = last_name
            changed_fields.append("last_name")

        if changed_fields:
            user.save(update_fields=changed_fields + ["updated_at"])

    return user


def _parse_supabase_user_id(claims: dict[str, Any]) -> UUID:
    raw_user_id = claims.get("id") or claims.get("sub")
    if not raw_user_id:
        raise ValueError("Supabase token is missing a user identifier.")

    try:
        return UUID(str(raw_user_id))
    except (TypeError, ValueError) as exc:
        raise ValueError("Supabase user identifier is not a valid UUID.") from exc


def _extract_email(claims: dict[str, Any]) -> str | None:
    metadata = claims.get("user_metadata") or {}
    email = claims.get("email") or metadata.get("email")
    if not email:
        return None
    return str(email).strip().lower()


def _extract_phone(claims: dict[str, Any]) -> str | None:
    metadata = claims.get("user_metadata") or {}
    phone = claims.get("phone") or metadata.get("phone")
    if not phone:
        return None
    try:
        return normalize_ghana_phone(phone)
    except InvalidPhoneNumber as exc:
        raise ValueError("Supabase token contains an invalid phone number.") from exc


def _extract_names(claims: dict[str, Any]) -> tuple[str, str]:
    metadata = claims.get("user_metadata") or {}

    first_name = str(metadata.get("first_name") or metadata.get("given_name") or "").strip()
    last_name = str(metadata.get("last_name") or metadata.get("family_name") or "").strip()

    if first_name or last_name:
        return first_name, last_name

    full_name = str(metadata.get("full_name") or metadata.get("name") or "").strip()
    if not full_name:
        return "", ""

    name_parts = full_name.split(maxsplit=1)
    if len(name_parts) == 1:
        return name_parts[0], ""
    return name_parts[0], name_parts[1]


def _build_username(supabase_user_id: UUID) -> str:
    return f"sb_{supabase_user_id.hex[:24]}"


# ── Loan Guarantors ─────────────────────────────────────────────────────


@transaction.atomic
def bulk_create_guarantors(*, user: User, guarantors_data: list[dict[str, str]]) -> list[LoanGuarantor]:
    if len(guarantors_data) < 2:
        raise ValueError("At least 2 guarantors are required.")

    normalized_data = [
        {
            "name": g["name"].strip(),
            "phone_number": _validate_guarantor_phone(user=user, phone_number=g["phone_number"]),
        }
        for g in guarantors_data
    ]
    guarantors = [LoanGuarantor(user=user, **data) for data in normalized_data]
    created_guarantors = LoanGuarantor.objects.bulk_create(guarantors)
    for guarantor in created_guarantors:
        send_guarantor_otp(guarantor)
    return created_guarantors


@transaction.atomic
def add_guarantor(*, user: User, name: str, phone_number: str) -> LoanGuarantor:
    normalized_phone = _validate_guarantor_phone(user=user, phone_number=phone_number)
    guarantor = LoanGuarantor.objects.create(
        user=user,
        name=name.strip(),
        phone_number=normalized_phone,
    )
    send_guarantor_otp(guarantor)
    return guarantor


@transaction.atomic
def update_guarantor(
    *, guarantor: LoanGuarantor, name: str | None = None, phone_number: str | None = None
) -> LoanGuarantor:
    phone_changed = False
    if name is not None:
        guarantor.name = name.strip()
    if phone_number is not None:
        normalized_phone = _validate_guarantor_phone(user=guarantor.user, phone_number=phone_number)
        try:
            current_phone = normalize_ghana_phone(guarantor.phone_number)
        except InvalidPhoneNumber:
            current_phone = None
        phone_changed = current_phone != normalized_phone
        guarantor.phone_number = normalized_phone

    if phone_changed:
        guarantor.is_verified = False
        LoanGuarantorOtp.objects.filter(guarantor=guarantor, used=False).update(used=True)

    guarantor.save(update_fields=["name", "phone_number", "is_verified", "updated_at"])
    if phone_number is not None and (phone_changed or not guarantor.is_verified):
        if not phone_changed:
            LoanGuarantorOtp.objects.filter(guarantor=guarantor, used=False).update(used=True)
        send_guarantor_otp(guarantor)
    return guarantor


@transaction.atomic
def verify_guarantor(*, guarantor: LoanGuarantor, code: str) -> LoanGuarantor:
    """Confirm guarantor consent with the latest unexpired SMS code."""

    guarantor = LoanGuarantor.objects.select_for_update().get(pk=guarantor.pk)
    if guarantor.is_verified:
        raise ValueError("This guarantor is already verified.")

    otp = (
        LoanGuarantorOtp.objects.filter(
            guarantor=guarantor,
            code=code,
            used=False,
            expires_at__gt=timezone.now(),
        )
        .order_by("-created_at")
        .first()
    )
    if otp is None:
        raise ValueError("Invalid or expired OTP code.")

    otp.used = True
    otp.save(update_fields=["used", "updated_at"])
    guarantor.is_verified = True
    guarantor.save(update_fields=["is_verified", "updated_at"])
    return guarantor


@transaction.atomic
def resend_guarantor_otp(*, guarantor: LoanGuarantor) -> LoanGuarantorOtp:
    """Invalidate previous codes and send a fresh five-minute code."""

    if guarantor.is_verified:
        raise ValueError("This guarantor is already verified.")
    LoanGuarantorOtp.objects.filter(guarantor=guarantor, used=False).update(used=True)
    return send_guarantor_otp(guarantor)


def send_guarantor_otp(guarantor: LoanGuarantor) -> LoanGuarantorOtp:
    """Create a five-minute consent OTP and queue its SMS after commit."""

    code = f"{secrets.randbelow(1_000_000):06d}"
    otp = LoanGuarantorOtp.objects.create(
        guarantor=guarantor,
        code=code,
        expires_at=timezone.now() + timedelta(minutes=GUARANTOR_OTP_EXPIRY_MINUTES),
    )
    try:
        normalized_phone = normalize_ghana_phone(guarantor.phone_number)
    except InvalidPhoneNumber as exc:
        raise ValueError(str(exc)) from exc

    borrower_name = f"{guarantor.user.first_name} {guarantor.user.last_name}".strip() or "A MoMo Plus borrower"

    def enqueue_delivery() -> None:
        try:
            send_guarantor_otp_task.delay(
                phone=normalized_phone,
                otp_code=code,
                borrower_name=borrower_name,
            )
        except Exception:
            logger.exception("Could not queue background guarantor consent SMS delivery.")

    transaction.on_commit(enqueue_delivery)
    return otp


def _validate_guarantor_phone(*, user: User, phone_number: str) -> str:
    try:
        normalized_phone = normalize_ghana_phone(phone_number)
    except InvalidPhoneNumber as exc:
        raise ValueError(str(exc)) from exc

    if user.phone:
        try:
            current_user_phone = normalize_ghana_phone(user.phone)
        except InvalidPhoneNumber:
            current_user_phone = None
        if current_user_phone == normalized_phone:
            raise ValueError("You cannot add your own current phone number as a guarantor.")

    return normalized_phone


def delete_guarantor(*, guarantor: LoanGuarantor, user: User) -> None:
    remaining = user.loan_guarantors.exclude(id=guarantor.id).count()
    if remaining < 2:
        raise ValueError("Cannot remove guarantor. At least 2 guarantors are required.")
    guarantor.delete()
