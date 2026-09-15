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
    phone: models.CharField = models.CharField(max_length=16, unique=True, null=True, blank=True)
    email: models.EmailField = models.EmailField(unique=True, null=True, blank=True)
    first_name: models.CharField = models.CharField(max_length=150)
    last_name: models.CharField = models.CharField(max_length=150)
    role: models.CharField = models.CharField(max_length=10, choices=UserRole.choices, default=UserRole.USER)
    agent_status: models.CharField = models.CharField(
        max_length=10, choices=AgentStatus.choices, default=AgentStatus.NONE
    )
    kyc_status: models.CharField = models.CharField(max_length=10, choices=KycStatus.choices, default=KycStatus.NONE)
    kyc_draft: models.JSONField = models.JSONField(default=dict, blank=True)
    deactivation_reason: models.TextField = models.TextField(blank=True)
    deactivated_at: models.DateTimeField = models.DateTimeField(null=True, blank=True)

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["username", "first_name", "last_name"]

    def __str__(self) -> str:
        return self.email or self.phone or self.username

    @property
    def is_onboarded(self) -> bool:
        return bool(self.first_name.strip() and self.last_name.strip())


class LoanGuarantor(BaseModel):
    user: models.ForeignKey = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="loan_guarantors",
    )
    name: models.CharField = models.CharField(max_length=200)
    phone_number: models.CharField = models.CharField(max_length=20)
    is_verified: models.BooleanField = models.BooleanField(default=False)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["user", "created_at"], name="accounts_lo_user_id_b5b3fe_idx"),
            models.Index(fields=["user", "is_verified"], name="accounts_lo_user_id_51c70c_idx"),
        ]

    def __str__(self) -> str:
        return f"{self.name} ({self.phone_number})"


class LoanGuarantorOtp(BaseModel):
    guarantor: models.ForeignKey = models.ForeignKey(
        LoanGuarantor,
        on_delete=models.CASCADE,
        related_name="otps",
    )
    code: models.CharField = models.CharField(max_length=6)
    expires_at: models.DateTimeField = models.DateTimeField()
    used: models.BooleanField = models.BooleanField(default=False)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["guarantor", "used", "expires_at"], name="accounts_lo_guarantor_otp_idx"),
        ]

    def __str__(self) -> str:
        return f"Guarantor OTP({self.guarantor.phone_number}, used={self.used})"
