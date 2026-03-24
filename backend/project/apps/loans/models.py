from __future__ import annotations

from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class LoanStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    APPROVED = "approved", "Approved"
    DISBURSING = "disbursing", "Disbursing"
    ACTIVE = "active", "Active"
    REPAYING = "repaying", "Repaying"
    COMPLETED = "completed", "Completed"
    DEFAULTED = "defaulted", "Defaulted"
    REJECTED = "rejected", "Rejected"
    CANCELLED = "cancelled", "Cancelled"
    FAILED = "failed", "Failed"


class PaymentType(models.TextChoices):
    DISBURSEMENT = "disbursement", "Disbursement"
    REPAYMENT = "repayment", "Repayment"


class PaymentStatus(models.TextChoices):
    PENDING = "pending", "Pending"
    SUCCESS = "success", "Success"
    FAILED = "failed", "Failed"


class Loan(BaseModel):
    """Core loan record between a user (borrower) and an agent (lender)."""

    borrower = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="loans_as_borrower",
    )
    agent = models.ForeignKey(
        "agents.AgentProfile",
        on_delete=models.CASCADE,
        related_name="loans",
    )
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    interest_rate = models.DecimalField(
        max_digits=5,
        decimal_places=2,
        default=10.00,
        help_text="Interest rate as a percentage (e.g. 10.00 = 10%)",
    )
    total_repayment = models.DecimalField(
        max_digits=10,
        decimal_places=2,
        help_text="amount + interest, computed at approval time",
    )
    penalty_amount = models.DecimalField(max_digits=10, decimal_places=2, default=0)
    outstanding_balance = models.DecimalField(max_digits=10, decimal_places=2, default=0)

    status = models.CharField(
        max_length=15,
        choices=LoanStatus.choices,
        default=LoanStatus.PENDING,
    )

    # Wallets involved
    borrower_wallet = models.ForeignKey(
        "wallets.Wallet",
        on_delete=models.CASCADE,
        related_name="loans_received",
        help_text="The wallet that receives the disbursement",
    )
    agent_wallet = models.ForeignKey(
        "wallets.Wallet",
        on_delete=models.CASCADE,
        related_name="loans_funded",
        null=True,
        blank=True,
        help_text="The agent's wallet used for funding and receiving repayment",
    )

    network = models.CharField(max_length=15)

    # Rejection / cancellation
    rejection_reason = models.TextField(blank=True, default="")
    cancelled_by = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="+",
    )

    # Timeline
    approved_at = models.DateTimeField(null=True, blank=True)
    disbursed_at = models.DateTimeField(null=True, blank=True)
    deadline_at = models.DateTimeField(null=True, blank=True)
    last_penalty_at = models.DateTimeField(null=True, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    defaulted_at = models.DateTimeField(null=True, blank=True)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["borrower", "status"]),
            models.Index(fields=["agent", "status"]),
            models.Index(fields=["deadline_at"]),
        ]

    def __str__(self):
        return f"Loan({self.borrower_id} ← {self.agent_id}, {self.amount}, {self.status})"


class LoanPayment(BaseModel):
    """Tracks individual Paystack payment events (disbursements and repayments)."""

    loan = models.ForeignKey(
        Loan,
        on_delete=models.CASCADE,
        related_name="payments",
    )
    payment_type = models.CharField(max_length=15, choices=PaymentType.choices)
    amount = models.DecimalField(max_digits=10, decimal_places=2)
    status = models.CharField(
        max_length=10,
        choices=PaymentStatus.choices,
        default=PaymentStatus.PENDING,
    )

    # Paystack references
    reference = models.CharField(max_length=100, unique=True, help_text="Our internal reference sent to Paystack")
    paystack_reference = models.CharField(
        max_length=100, blank=True, default="", help_text="Paystack's own reference returned in response"
    )

    # Payer / recipient details for audit
    payer_phone = models.CharField(max_length=15)
    payer_network = models.CharField(max_length=15)
    recipient_subaccount = models.CharField(max_length=50, blank=True, default="")

    paystack_response = models.JSONField(default=dict, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["reference"]),
            models.Index(fields=["loan", "payment_type"]),
        ]

    def __str__(self):
        return f"LoanPayment({self.payment_type}, {self.amount}, {self.status})"
