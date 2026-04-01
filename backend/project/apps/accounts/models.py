from django.contrib.auth.models import AbstractUser
from django.db import models

from project.apps.core.models import BaseModel


class UserRole(models.TextChoices):
    USER = "user", "User"
    AGENT = "agent", "Agent"


class AgentStatus(models.TextChoices):
    NONE = "none", "None"
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class KycStatus(models.TextChoices):
    NONE = "none", "None"
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    REJECTED = "rejected", "Rejected"


class User(AbstractUser, BaseModel):
    supabase_user_id: models.UUIDField = models.UUIDField(unique=True, null=True, blank=True)
    email: models.EmailField = models.EmailField(unique=True)
    first_name: models.CharField = models.CharField(max_length=150)
    last_name: models.CharField = models.CharField(max_length=150)
    role: models.CharField = models.CharField(max_length=10, choices=UserRole.choices, default=UserRole.USER)
    agent_status: models.CharField = models.CharField(
        max_length=10, choices=AgentStatus.choices, default=AgentStatus.NONE
    )
    kyc_status: models.CharField = models.CharField(max_length=10, choices=KycStatus.choices, default=KycStatus.NONE)
    kyc_draft: models.JSONField = models.JSONField(default=dict, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "first_name", "last_name"]

    def __str__(self) -> str:
        return self.email


class LoanGuarantor(BaseModel):
    user: models.ForeignKey = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="loan_guarantors",
    )
    name: models.CharField = models.CharField(max_length=200)
    phone_number: models.CharField = models.CharField(max_length=20)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["user", "created_at"]),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.phone_number})"
