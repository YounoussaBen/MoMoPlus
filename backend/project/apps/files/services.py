from __future__ import annotations

import hashlib
from pathlib import Path
from typing import Any

from django.conf import settings
from django.core.files.storage import Storage
from django.db import transaction

from project.storage_backends import SupabaseStorage

from .models import FileAsset


class FileAssetError(Exception):
    """Base exception for file asset workflows."""


class FileAssetAccessError(FileAssetError):
    """Raised when access to a file asset cannot be granted."""


class FileAssetUploadError(FileAssetError):
    """Raised when a direct upload cannot be initiated or completed."""


def resolve_visibility(kind: str, requested_visibility: str | None = None) -> str:
    allowed = FileAsset.allowed_visibility_for_kind(kind)
    if requested_visibility is None:
        return FileAsset.default_visibility_for_kind(kind)

    if requested_visibility not in allowed:
        allowed_values = ", ".join(sorted(allowed))
        raise ValueError(f"{kind} files only support these visibility values: {allowed_values}.")

    return requested_visibility


@transaction.atomic
def create_file_asset(
    *,
    owner: Any,
    uploaded_by: Any,
    uploaded_file: Any,
    kind: str,
    visibility: str | None = None,
    metadata: dict[str, Any] | None = None,
) -> FileAsset:
    resolved_visibility = resolve_visibility(kind, visibility)
    original_name = Path(getattr(uploaded_file, "name", "file")).name[:255] or "file"
    content_type = str(getattr(uploaded_file, "content_type", "") or "")[:255]
    size = int(getattr(uploaded_file, "size", 0) or 0)
    sha256 = calculate_sha256(uploaded_file)

    asset = FileAsset.objects.create(
        owner=owner,
        uploaded_by=uploaded_by,
        kind=kind,
        visibility=resolved_visibility,
        status=FileAsset.Status.UPLOADING,
        original_name=original_name,
        content_type=content_type,
        size=size,
        sha256=sha256,
        metadata=metadata or {},
    )

    try:
        asset.file.save(original_name, uploaded_file, save=False)
        asset.storage_path = asset.file.name
        asset.storage_bucket = _resolve_storage_bucket(asset)
        asset.status = FileAsset.Status.READY
        asset.save(update_fields=["file", "storage_path", "storage_bucket", "status", "updated_at"])
    except Exception:
        if asset.file:
            try:
                asset.file.delete(save=False)
            except Exception:
                pass
        asset.status = FileAsset.Status.FAILED
        asset.save(update_fields=["status", "updated_at"])
        raise

    return asset


@transaction.atomic
def initiate_file_asset_upload(
    *,
    owner: Any,
    uploaded_by: Any,
    original_name: str,
    content_type: str,
    size: int,
    kind: str,
    visibility: str | None = None,
    metadata: dict[str, Any] | None = None,
    sha256: str = "",
) -> tuple[FileAsset, dict[str, Any]]:
    resolved_visibility = resolve_visibility(kind, visibility)
    asset = FileAsset.objects.create(
        owner=owner,
        uploaded_by=uploaded_by,
        kind=kind,
        visibility=resolved_visibility,
        status=FileAsset.Status.UPLOADING,
        original_name=(Path(original_name).name[:255] or "file"),
        content_type=str(content_type or "")[:255],
        size=int(size),
        sha256=sha256[:64],
        metadata=metadata or {},
    )
    storage_path = file_storage_path(asset)
    storage = get_file_storage()

    if not isinstance(storage, SupabaseStorage):
        raise FileAssetUploadError("Direct upload initiation requires Supabase Storage to be configured.")

    upload_target = storage.client.create_signed_upload(storage_path)
    asset.storage_path = storage_path
    asset.storage_bucket = storage.client.bucket
    asset.save(update_fields=["storage_path", "storage_bucket", "updated_at"])

    return (
        asset,
        {
            "provider": "supabase-storage",
            "bucket": storage.client.bucket,
            "path": upload_target["path"],
            "token": upload_target["token"],
            "signed_url": upload_target.get("signed_url"),
            "expires_in": upload_target["expires_in"],
        },
    )


@transaction.atomic
def finalize_file_asset_upload(*, asset: FileAsset) -> FileAsset:
    if asset.is_deleted:
        raise FileAssetUploadError("This file has been deleted.")

    if asset.status == FileAsset.Status.READY and asset.file:
        return asset

    if not asset.storage_path:
        raise FileAssetUploadError("This file does not have a storage path.")

    storage = get_file_storage()
    if not storage.exists(asset.storage_path):
        raise FileAssetUploadError("Uploaded file was not found in storage.")

    actual_size = _get_uploaded_size(storage=storage, path=asset.storage_path)
    if asset.size and actual_size is not None and int(actual_size) != int(asset.size):
        raise FileAssetUploadError("Uploaded file size does not match the expected size.")

    asset.file = asset.storage_path
    if actual_size is not None:
        asset.size = int(actual_size)
    asset.status = FileAsset.Status.READY
    asset.save(update_fields=["file", "size", "status", "updated_at"])
    return asset


@transaction.atomic
def delete_file_asset(*, asset: FileAsset, actor: Any) -> FileAsset:
    if asset.is_deleted:
        return asset

    storage_path = asset.storage_path or (asset.file.name if asset.file else "")
    if storage_path:
        storage = get_file_storage()
        if storage.exists(storage_path):
            storage.delete(storage_path)
        if not asset.storage_path:
            asset.storage_path = storage_path
    asset.file = ""

    asset.mark_deleted(actor=actor)
    asset.save(update_fields=["file", "storage_path", "status", "deleted_at", "deleted_by", "updated_at"])
    return asset


def build_access_url(*, asset: FileAsset, request: Any) -> dict[str, Any]:
    if asset.status != FileAsset.Status.READY or asset.is_deleted or not asset.file:
        raise FileAssetAccessError("This file is not available.")

    storage = asset.file.storage
    if isinstance(storage, SupabaseStorage):
        expires_in = settings.SUPABASE_STORAGE_SIGNED_URL_EXPIRY
        return {
            "url": storage.client.signed_url(asset.file.name, expires_in=expires_in),
            "expires_in": expires_in,
        }

    return {
        "url": request.build_absolute_uri(asset.file.url),
        "expires_in": None,
    }


def calculate_sha256(uploaded_file: Any) -> str:
    hasher = hashlib.sha256()

    if hasattr(uploaded_file, "chunks"):
        for chunk in uploaded_file.chunks():
            hasher.update(chunk)
    else:
        hasher.update(uploaded_file.read())

    if hasattr(uploaded_file, "seek"):
        uploaded_file.seek(0)

    return hasher.hexdigest()


def _resolve_storage_bucket(asset: FileAsset) -> str:
    storage = asset.file.storage
    if isinstance(storage, SupabaseStorage):
        return storage.client.bucket
    return str(getattr(settings, "SUPABASE_STORAGE_BUCKET", "") or "")


def get_file_storage() -> Storage:
    return FileAsset._meta.get_field("file").storage


def file_storage_path(asset: FileAsset) -> str:
    return asset.file.field.generate_filename(asset, asset.original_name)


def _get_uploaded_size(*, storage: Storage, path: str) -> int | None:
    if isinstance(storage, SupabaseStorage):
        size = storage.client.size(path)
        return int(size) if size is not None else None

    if not hasattr(storage, "size"):
        return None

    size = storage.size(path)
    return int(size) if size is not None else None
