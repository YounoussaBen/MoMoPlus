from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class AgentType(models.TextChoices):
    CERTIFIED = "certified", "Certified"
    SELF_ENROLLED = "self_enrolled", "Self Enrolled"


class AgentProfile(BaseModel):
    user = models.OneToOneField(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="agent_profile",
    )
    latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    is_available = models.BooleanField(default=False)
    max_amount = models.DecimalField(max_digits=10, decimal_places=2, null=True, blank=True)
    min_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    service_radius_km = models.DecimalField(max_digits=5, decimal_places=2, default=5.00)
    bio = models.TextField(blank=True, default="")
    rating = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_ratings = models.PositiveIntegerField(default=0)
    agent_type = models.CharField(
        max_length=15,
        choices=AgentType.choices,
        default=AgentType.SELF_ENROLLED,
    )

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["is_available"]),
            models.Index(fields=["latitude", "longitude"]),
        ]

    def __str__(self):
        return f"AgentProfile({self.user.email})"

    @property
    def has_location(self) -> bool:
        return self.latitude is not None and self.longitude is not None

    @property
    def is_certified(self) -> bool:
        return self.agent_type == AgentType.CERTIFIED


class CertificationStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class CertificationApplication(BaseModel):
    agent_profile = models.ForeignKey(
        AgentProfile,
        on_delete=models.CASCADE,
        related_name="certification_applications",
    )
    agent_id_number = models.CharField(max_length=50)
    network = models.CharField(
        max_length=20,
        default="mtn",
        help_text="Telco network the agent is registered with",
    )
    agent_id_photo = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        related_name="+",
        help_text="Photo of agent ID card or certificate",
    )
    business_location_photo = models.ForeignKey(
        "files.FileAsset",
        on_delete=models.SET_NULL,
        null=True,
        related_name="+",
        help_text="Photo of business location / branded stall",
    )
    business_registration_number = models.CharField(max_length=50, blank=True, default="")
    status = models.CharField(
        max_length=10,
        choices=CertificationStatus.choices,
        default=CertificationStatus.PENDING,
    )
    rejection_reason = models.TextField(blank=True, default="")
    reviewed_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    reviewed_at = models.DateTimeField(null=True, blank=True)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["status", "created_at"]),
        ]

    def __str__(self):
        return f"Certification({self.agent_profile.user.email}, {self.status})"
