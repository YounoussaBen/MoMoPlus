from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import KycStatus, User
from project.apps.files.models import FileAsset
from project.apps.files.services import delete_file_asset

from .models import GhanaCardRecord, KycSubmission
from .utils import normalize_ghana_card_number


def _get_ready_asset(user: User, asset_id: str, expected_kind: str) -> FileAsset:
    try:
        asset = FileAsset.objects.get(id=asset_id, owner=user, status=FileAsset.Status.READY)
    except FileAsset.DoesNotExist:
        raise ValueError(f"File {asset_id} is not available. Upload it first and ensure it is ready.")
    if asset.kind != expected_kind:
        raise ValueError(f"Expected a '{expected_kind}' file but got '{asset.kind}'.")
    return asset


@transaction.atomic
def submit_kyc(
    *,
    user: User,
    ghana_card_number: str,
    id_front_id: str,
    id_back_id: str,
    selfie_id: str,
    proof_of_address_id: str,
) -> KycSubmission:
    try:
        normalized_card_number = normalize_ghana_card_number(ghana_card_number)
    except ValueError as exc:
        raise ValueError(str(exc)) from exc

    existing = KycSubmission.objects.filter(user=user).select_for_update().first()

    if existing and existing.status == KycSubmission.Status.PENDING:
        raise ValueError("A KYC submission is already pending review.")

    if existing and existing.status == KycSubmission.Status.APPROVED:
        raise ValueError("KYC is already approved.")

    id_front_asset = _get_ready_asset(user, id_front_id, str(FileAsset.FileKind.GHANA_CARD))
    id_back_asset = _get_ready_asset(user, id_back_id, str(FileAsset.FileKind.GHANA_CARD))
    selfie_asset = _get_ready_asset(user, selfie_id, str(FileAsset.FileKind.SELFIE))
    proof_asset = _get_ready_asset(user, proof_of_address_id, str(FileAsset.FileKind.DOCUMENT))

    # Lock the registry row while matching so two accounts cannot be auto-approved
    # concurrently with the same registered card.
    registry_record = (
        GhanaCardRecord.objects.select_for_update().filter(card_number=normalized_card_number, is_active=True).first()
    )
    if (
        KycSubmission.objects.filter(
            ghana_card_number=normalized_card_number,
            status=KycSubmission.Status.APPROVED,
        )
        .exclude(user=user)
        .exists()
    ):
        raise ValueError("This Ghana Card is already linked to another account.")

    matched_registry = registry_record is not None
    new_status = KycSubmission.Status.APPROVED if matched_registry else KycSubmission.Status.PENDING
    verification_method = (
        KycSubmission.VerificationMethod.GHANA_CARD_REGISTRY
        if matched_registry
        else KycSubmission.VerificationMethod.MANUAL_REVIEW
    )
    reviewed_at = timezone.now() if matched_registry else None

    # Collect old file assets to delete after the new submission is saved
    old_assets: list[FileAsset] = []
    if existing:
        for attr in ("id_front", "id_back", "selfie", "proof_of_address"):
            asset = getattr(existing, attr, None)
            if asset is not None:
                old_assets.append(asset)

    if existing:
        existing.id_type = KycSubmission.IdType.NATIONAL_ID
        existing.ghana_card_number = normalized_card_number
        existing.verification_method = verification_method
        existing.status = new_status
        existing.id_front = id_front_asset
        existing.id_back = id_back_asset
        existing.selfie = selfie_asset
        existing.proof_of_address = proof_asset
        existing.rejection_reason = ""
        existing.reviewed_by = None
        existing.reviewed_at = reviewed_at
        existing.save()
        submission = existing
    else:
        submission = KycSubmission.objects.create(
            user=user,
            id_type=KycSubmission.IdType.NATIONAL_ID,
            ghana_card_number=normalized_card_number,
            verification_method=verification_method,
            status=new_status,
            id_front=id_front_asset,
            id_back=id_back_asset,
            selfie=selfie_asset,
            proof_of_address=proof_asset,
        )

    user.kyc_status = KycStatus.APPROVED if matched_registry else KycStatus.PENDING
    user.save(update_fields=["kyc_status", "updated_at"])

    # Clean up old assets after new ones are saved
    for asset in old_assets:
        delete_file_asset(asset=asset, actor=user)

    return submission


@transaction.atomic
def approve_kyc(*, submission: KycSubmission, reviewer: User) -> KycSubmission:
    if submission.status != KycSubmission.Status.PENDING:
        raise ValueError("Only pending submissions can be approved.")

    if (
        submission.ghana_card_number
        and KycSubmission.objects.filter(
            ghana_card_number=submission.ghana_card_number,
            status=KycSubmission.Status.APPROVED,
        )
        .exclude(pk=submission.pk)
        .exists()
    ):
        raise ValueError("This Ghana Card is already linked to another account.")

    submission.status = KycSubmission.Status.APPROVED
    submission.reviewed_by = reviewer
    submission.reviewed_at = timezone.now()
    submission.verification_method = KycSubmission.VerificationMethod.MANUAL_REVIEW
    submission.rejection_reason = ""
    submission.save(
        update_fields=[
            "status",
            "reviewed_by",
            "reviewed_at",
            "verification_method",
            "rejection_reason",
            "updated_at",
        ]
    )

    user = submission.user
    user.kyc_status = KycStatus.APPROVED
    user.save(update_fields=["kyc_status", "updated_at"])

    return submission


@transaction.atomic
def reject_kyc(*, submission: KycSubmission, reviewer: User, reason: str) -> KycSubmission:
    if submission.status != KycSubmission.Status.PENDING:
        raise ValueError("Only pending submissions can be rejected.")

    if not reason or not reason.strip():
        raise ValueError("A rejection reason is required.")

    submission.status = KycSubmission.Status.REJECTED
    submission.reviewed_by = reviewer
    submission.reviewed_at = timezone.now()
    submission.verification_method = KycSubmission.VerificationMethod.MANUAL_REVIEW
    submission.rejection_reason = reason.strip()
    submission.save(
        update_fields=[
            "status",
            "reviewed_by",
            "reviewed_at",
            "verification_method",
            "rejection_reason",
            "updated_at",
        ]
    )

    user = submission.user
    user.kyc_status = KycStatus.REJECTED
    user.save(update_fields=["kyc_status", "updated_at"])

    return submission


@transaction.atomic
def create_ghana_card_record(
    *,
    actor: User,
    card_number: str,
    first_names: str,
    surname: str,
    date_of_birth,
    sex: str,
    card_front_id: str,
    card_back_id: str,
) -> GhanaCardRecord:
    try:
        normalized_card_number = normalize_ghana_card_number(card_number)
    except ValueError as exc:
        raise ValueError(str(exc)) from exc

    front_asset = _get_ready_asset(actor, card_front_id, str(FileAsset.FileKind.GHANA_CARD))
    back_asset = _get_ready_asset(actor, card_back_id, str(FileAsset.FileKind.GHANA_CARD))
    if front_asset.id == back_asset.id:
        raise ValueError("Upload separate front and back Ghana Card images.")

    if GhanaCardRecord.objects.filter(card_number=normalized_card_number).exists():
        raise ValueError("A Ghana Card with this number is already registered.")

    return GhanaCardRecord.objects.create(
        card_number=normalized_card_number,
        first_names=first_names.strip(),
        surname=surname.strip(),
        date_of_birth=date_of_birth,
        sex=sex.strip().upper(),
        card_front=front_asset,
        card_back=back_asset,
        created_by=actor,
    )
