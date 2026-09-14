from __future__ import annotations

from django.conf import settings
from django.db import models
from django.db.models import Q

from project.apps.core.models import BaseModel


class KycSubmission(BaseModel):
    class IdType(models.TextChoices):
        NATIONAL_ID = "national_id", "Ghana Card"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    class VerificationMethod(models.TextChoices):
        MANUAL_REVIEW = "manual_review", "Manual review"
        GHANA_CARD_REGISTRY = "ghana_card_registry", "Ghana Card registry"

    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="kyc_submission",
    )
    status = models.CharField(max_length=10, choices=Status.choices, default=Status.PENDING)
    id_type = models.CharField(max_length=20, choices=IdType.choices)
    ghana_card_number = models.CharField(max_length=15, blank=True, db_index=True)
    verification_method = models.CharField(
        max_length=32,
        choices=VerificationMethod.choices,
        default=VerificationMethod.MANUAL_REVIEW,
    )

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
        constraints = [
            models.UniqueConstraint(
                fields=["ghana_card_number"],
                condition=Q(status="approved") & ~Q(ghana_card_number=""),
                name="unique_approved_ghana_card",
            ),
        ]

    def __str__(self) -> str:
        return f"KYC({self.user_id}, {self.status})"


class GhanaCardRecord(BaseModel):
    """Staff-managed Ghana Card registry used for automatic KYC matching."""

    card_number = models.CharField(max_length=15, unique=True)
    first_names = models.CharField(max_length=255)
    surname = models.CharField(max_length=255)
    date_of_birth = models.DateField(null=True, blank=True)
    sex = models.CharField(max_length=16, blank=True)
    card_front = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.PROTECT,
        related_name="ghana_card_front_records",
    )
    card_back = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.PROTECT,
        related_name="ghana_card_back_records",
    )
    is_active = models.BooleanField(default=True)
    created_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="created_ghana_card_records",
    )

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["is_active", "card_number"]),
            models.Index(fields=["surname", "first_names"]),
        ]

    def __str__(self) -> str:
        return f"{self.card_number} — {self.first_names} {self.surname}".strip()
