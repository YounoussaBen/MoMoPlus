from __future__ import annotations

from typing import Any
from uuid import UUID

from django.db import transaction

from .models import LoanGuarantor, User


def sync_user_from_supabase_claims(claims: dict[str, Any]) -> User:
    supabase_user_id = _parse_supabase_user_id(claims)
    email = _extract_email(claims)
    first_name, last_name = _extract_names(claims)

    with transaction.atomic():
        user = User.objects.select_for_update().filter(supabase_user_id=supabase_user_id).first()
        if user is None:
            user = User.objects.select_for_update().filter(email__iexact=email).first()

        if user and user.supabase_user_id and user.supabase_user_id != supabase_user_id:
            raise ValueError("Supabase user ID does not match the existing Django user.")

        if user is None:
            user = User(
                supabase_user_id=supabase_user_id,
                email=email,
                username=_build_username(supabase_user_id),
                first_name=first_name,
                last_name=last_name,
                is_active=True,
            )
            user.set_unusable_password()
            user.save()
            return user

        changed_fields: list[str] = []

        if user.supabase_user_id != supabase_user_id:
            user.supabase_user_id = supabase_user_id
            changed_fields.append("supabase_user_id")

        if user.email != email:
            user.email = email
            changed_fields.append("email")

        if first_name != user.first_name:
            user.first_name = first_name
            changed_fields.append("first_name")

        if last_name != user.last_name:
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


def _extract_email(claims: dict[str, Any]) -> str:
    metadata = claims.get("user_metadata") or {}
    email = claims.get("email") or metadata.get("email")
    if not email:
        raise ValueError("Supabase token is missing an email address.")
    return str(email).strip().lower()


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
    guarantors = [LoanGuarantor(user=user, name=g["name"], phone_number=g["phone_number"]) for g in guarantors_data]
    return LoanGuarantor.objects.bulk_create(guarantors)


def add_guarantor(*, user: User, name: str, phone_number: str) -> LoanGuarantor:
    return LoanGuarantor.objects.create(user=user, name=name, phone_number=phone_number)


def update_guarantor(
    *, guarantor: LoanGuarantor, name: str | None = None, phone_number: str | None = None
) -> LoanGuarantor:
    if name is not None:
        guarantor.name = name
    if phone_number is not None:
        guarantor.phone_number = phone_number
    guarantor.save(update_fields=["name", "phone_number", "updated_at"])
    return guarantor


def delete_guarantor(*, guarantor: LoanGuarantor, user: User) -> None:
    remaining = user.loan_guarantors.exclude(id=guarantor.id).count()
    if remaining < 2:
        raise ValueError("Cannot remove guarantor. At least 2 guarantors are required.")
    guarantor.delete()
