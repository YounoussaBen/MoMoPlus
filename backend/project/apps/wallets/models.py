from __future__ import annotations

from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class Wallet(BaseModel):
    class Network(models.TextChoices):
        MTN = "mtn", "MTN"
        VODAFONE = "vodafone", "Vodafone"
        AIRTELTIGO = "airteltigo", "AirtelTigo"

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="wallets",
    )
    phone_number = models.CharField(max_length=15)
    network = models.CharField(max_length=15, choices=Network.choices)
    is_verified = models.BooleanField(default=False)
    is_default = models.BooleanField(default=False)
    paystack_recipient_code = models.CharField(max_length=50, blank=True, default="")

    class Meta(BaseModel.Meta):
        constraints = [
            models.UniqueConstraint(fields=["user", "phone_number"], name="unique_user_phone"),
        ]
        indexes = [
            models.Index(fields=["user", "is_default"]),
        ]

    def __str__(self) -> str:
        return f"Wallet({self.phone_number}, {self.network})"


class WalletOtp(BaseModel):
    wallet = models.ForeignKey(
        Wallet,
        on_delete=models.CASCADE,
        related_name="otps",
    )
    code = models.CharField(max_length=6)
    expires_at = models.DateTimeField()
    used = models.BooleanField(default=False)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(fields=["wallet", "used", "expires_at"]),
        ]

    def __str__(self) -> str:
        return f"OTP({self.wallet.phone_number}, used={self.used})"
