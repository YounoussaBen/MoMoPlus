from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class TransactionType(models.TextChoices):
    CASH_OUT = "cash_out", "Cash Out"
    DEPOSIT = "deposit", "Deposit"


class TransactionStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    ACCEPTED = "accepted", "Accepted"
    REJECTED = "rejected", "Rejected"
    COMPLETED = "completed", "Completed"
    CANCELLED = "cancelled", "Cancelled"
    EXPIRED = "expired", "Expired"


class PhysicalTransaction(BaseModel):
    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="physical_transactions",
    )
    agent = models.ForeignKey(
        "agents.AgentProfile",
        on_delete=models.CASCADE,
        related_name="physical_transactions",
    )
    transaction_type = models.CharField(max_length=10, choices=TransactionType.choices)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    network = models.CharField(max_length=15)
    wallet = models.ForeignKey(
        "wallets.Wallet",
        on_delete=models.CASCADE,
        related_name="physical_transactions",
    )
    status = models.CharField(
        max_length=15,
        choices=TransactionStatus.choices,
        default=TransactionStatus.PENDING,
    )
    verification_code = models.CharField(max_length=6, blank=True, default="")
    meeting_latitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    meeting_longitude = models.DecimalField(max_digits=9, decimal_places=6, null=True, blank=True)
    meeting_description = models.TextField(blank=True, default="")
    user_confirmed = models.BooleanField(default=False)
    agent_confirmed = models.BooleanField(default=False)
    cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )
    cancellation_reason = models.TextField(blank=True, default="")
    completed_at = models.DateTimeField(null=True, blank=True)
    expires_at = models.DateTimeField()

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["user", "status"]),
            models.Index(fields=["agent", "status"]),
        ]

    def __str__(self):
        return f"PhysicalTransaction({self.transaction_type}, {self.status}, {self.amount})"
