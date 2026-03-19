from __future__ import annotations

from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class KycSubmission(BaseModel):
    class IdType(models.TextChoices):
        NATIONAL_ID = "national_id", "Ghana Card"
        PASSPORT = "passport", "Passport"
        DRIVERS_LICENSE = "drivers_license", "Driver's License"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="kyc_submission",
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    id_type = models.CharField(max_length=20, choices=IdType.choices)

    id_front = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="kyc_id_front",
    )
    id_back = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="kyc_id_back",
    )
    selfie = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="kyc_selfie",
    )
    proof_of_address = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="kyc_proof_of_address",
    )

    rejection_reason = models.TextField(blank=True)
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="kyc_reviews",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["status", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"KYC({self.user_id}, {self.status})"
