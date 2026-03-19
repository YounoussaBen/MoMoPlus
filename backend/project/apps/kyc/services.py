from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from project.apps.accounts.models import KycStatus, User
from project.apps.files.models import FileAsset
from project.apps.files.services import delete_file_asset

from .models import KycSubmission


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
    id_type: str,
    id_front_id: str,
    id_back_id: str,
    selfie_id: str,
    proof_of_address_id: str,
) -> KycSubmission:
    existing = KycSubmission.objects.filter(user=user).select_for_update().first()

    if existing and existing.status == KycSubmission.Status.PENDING:
        raise ValueError("A KYC submission is already pending review.")

    if existing and existing.status == KycSubmission.Status.APPROVED:
        raise ValueError("KYC is already approved.")

    id_front_asset = _get_ready_asset(user, id_front_id, str(FileAsset.FileKind.PASSPORT))
    id_back_asset = _get_ready_asset(user, id_back_id, str(FileAsset.FileKind.PASSPORT))
    selfie_asset = _get_ready_asset(user, selfie_id, str(FileAsset.FileKind.SELFIE))
    proof_asset = _get_ready_asset(user, proof_of_address_id, str(FileAsset.FileKind.DOCUMENT))

    # Collect old file assets to delete after the new submission is saved
    old_assets: list[FileAsset] = []
    if existing:
        for attr in ("id_front", "id_back", "selfie", "proof_of_address"):
            asset = getattr(existing, attr, None)
            if asset is not None:
                old_assets.append(asset)

    if existing:
        existing.id_type = id_type
        existing.status = KycSubmission.Status.PENDING
        existing.id_front = id_front_asset
        existing.id_back = id_back_asset
        existing.selfie = selfie_asset
        existing.proof_of_address = proof_asset
        existing.rejection_reason = ""
        existing.reviewed_by = None
        existing.reviewed_at = None
        existing.save()
        submission = existing
    else:
        submission = KycSubmission.objects.create(
            user=user,
            id_type=id_type,
            status=KycSubmission.Status.PENDING,
            id_front=id_front_asset,
            id_back=id_back_asset,
            selfie=selfie_asset,
            proof_of_address=proof_asset,
        )

    user.kyc_status = KycStatus.PENDING
    user.save(update_fields=["kyc_status", "updated_at"])

    # Clean up old assets after new ones are saved
    for asset in old_assets:
        delete_file_asset(asset=asset, actor=user)

    return submission


@transaction.atomic
def approve_kyc(*, submission: KycSubmission, reviewer: User) -> KycSubmission:
    if submission.status != KycSubmission.Status.PENDING:
        raise ValueError("Only pending submissions can be approved.")

    submission.status = KycSubmission.Status.APPROVED
    submission.reviewed_by = reviewer
    submission.reviewed_at = timezone.now()
    submission.rejection_reason = ""
    submission.save(update_fields=["status", "reviewed_by", "reviewed_at", "rejection_reason", "updated_at"])

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
    submission.rejection_reason = reason.strip()
    submission.save(update_fields=["status", "reviewed_by", "reviewed_at", "rejection_reason", "updated_at"])

    user = submission.user
    user.kyc_status = KycStatus.REJECTED
    user.save(update_fields=["kyc_status", "updated_at"])

    return submission
