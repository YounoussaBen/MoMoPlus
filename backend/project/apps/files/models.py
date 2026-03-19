from __future__ import annotations

from pathlib import Path
from typing import Any

from django.conf import settings
from django.db import models
from django.db.models import Q
from django.utils import timezone
from django.utils.text import slugify

from project.apps.core.models import BaseModel


def file_asset_upload_to(instance: FileAsset, filename: str) -> str:
    original_path = Path(filename)
    extension = original_path.suffix.lower()
    stem = slugify(original_path.stem)[:80] or "file"
    owner_id = instance.owner_id or "unassigned"
    return f"{instance.kind}/{owner_id}/{instance.id}/{stem}{extension}"


class FileAssetQuerySet(models.QuerySet):
    def active(self):
        return self.exclude(status=FileAsset.Status.DELETED).filter(deleted_at__isnull=True)

    def owned_by(self, user: Any):
        return self.active().filter(owner=user)

    def visible_to(self, user: Any):
        if not getattr(user, "is_authenticated", False):
            return self.none()

        if getattr(user, "is_staff", False) or getattr(user, "is_superuser", False):
            return self.active()

        return self.active().filter(Q(owner=user) | Q(visibility=FileAsset.Visibility.AUTHENTICATED))


class FileAsset(BaseModel):
    class FileKind(models.TextChoices):
        PROFILE_PICTURE = "profile_picture", "Profile picture"
        PASSPORT = "passport", "Passport"
        DOCUMENT = "document", "Document"
        SELFIE = "selfie", "Selfie"
        OTHER = "other", "Other"

    class Visibility(models.TextChoices):
        PRIVATE = "private", "Private"
        AUTHENTICATED = "authenticated", "Authenticated users"

    class Status(models.TextChoices):
        UPLOADING = "uploading", "Uploading"
        READY = "ready", "Ready"
        FAILED = "failed", "Failed"
        DELETED = "deleted", "Deleted"

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="owned_file_assets",
    )
    uploaded_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="uploaded_file_assets",
        null=True,
        blank=True,
    )
    deleted_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        related_name="deleted_file_assets",
        null=True,
        blank=True,
    )
    file = models.FileField(upload_to=file_asset_upload_to, max_length=500, blank=True)
    storage_path = models.CharField(max_length=500, blank=True)
    storage_bucket = models.CharField(max_length=255, blank=True)
    kind = models.CharField(max_length=32, choices=FileKind.choices, default=FileKind.DOCUMENT)
    visibility = models.CharField(max_length=32, choices=Visibility.choices, default=Visibility.PRIVATE)
    status = models.CharField(max_length=16, choices=Status.choices, default=Status.UPLOADING)
    original_name = models.CharField(max_length=255)
    content_type = models.CharField(max_length=255, blank=True)
    size = models.PositiveBigIntegerField(default=0)
    sha256 = models.CharField(max_length=64, blank=True)
    metadata = models.JSONField(default=dict, blank=True)
    deleted_at = models.DateTimeField(null=True, blank=True)

    objects = FileAssetQuerySet.as_manager()

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["owner", "created_at"]),
            models.Index(fields=["visibility", "status"]),
            models.Index(fields=["kind", "status"]),
        ]

    def __str__(self) -> str:
        return f"{self.kind}:{self.original_name or self.storage_path or self.id}"

    @classmethod
    def default_visibility_for_kind(cls, kind: str) -> str:
        if kind == cls.FileKind.PROFILE_PICTURE:
            return str(cls.Visibility.AUTHENTICATED)
        return str(cls.Visibility.PRIVATE)

    @classmethod
    def allowed_visibility_for_kind(cls, kind: str) -> set[str]:
        if kind == cls.FileKind.PROFILE_PICTURE:
            return {str(cls.Visibility.PRIVATE), str(cls.Visibility.AUTHENTICATED)}
        return {str(cls.Visibility.PRIVATE)}

    @property
    def is_deleted(self) -> bool:
        return self.status == self.Status.DELETED or self.deleted_at is not None

    def can_view(self, user: Any) -> bool:
        if not getattr(user, "is_authenticated", False):
            return False

        if getattr(user, "is_staff", False) or getattr(user, "is_superuser", False):
            return True

        if user.pk == self.owner_id:
            return True

        return (
            self.visibility == self.Visibility.AUTHENTICATED
            and self.status == self.Status.READY
            and not self.is_deleted
        )

    def can_manage(self, user: Any) -> bool:
        if not getattr(user, "is_authenticated", False):
            return False

        if getattr(user, "is_staff", False) or getattr(user, "is_superuser", False):
            return True

        return user.pk == self.owner_id

    def mark_deleted(self, *, actor: Any) -> None:
        self.status = self.Status.DELETED
        self.deleted_at = timezone.now()
        self.deleted_by = actor
