from django.conf import settings
from django.db import models

from project.apps.core.models import BaseModel


class NotificationKind(models.TextChoices):
    LOAN_REQUEST = "loan_request", "Get Funds Request"
    LOAN_STATUS = "loan_status", "Get Funds Status"
    TRANSACTION_REQUEST = "transaction_request", "Cash Service Request"
    TRANSACTION_STATUS = "transaction_status", "Cash Service Status"


class Notification(BaseModel):
    """A durable, user-scoped in-app notification."""

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name="notifications",
    )
    kind = models.CharField(max_length=32, choices=NotificationKind.choices)
    title = models.CharField(max_length=160)
    message = models.TextField()
    is_read = models.BooleanField(default=False)
    read_at = models.DateTimeField(null=True, blank=True)
    resource_type = models.CharField(max_length=32, blank=True, default="")
    resource_id = models.CharField(max_length=64, blank=True, default="")
    metadata = models.JSONField(default=dict, blank=True)
    dedupe_key = models.CharField(max_length=255, unique=True, null=True, blank=True)

    class Meta(BaseModel.Meta):
        indexes = [
            models.Index(
                fields=["user", "is_read", "created_at"],
                name="notificatio_user_id_8a7c6b_idx",
            ),
            models.Index(
                fields=["user", "created_at"],
                name="notificatio_user_id_c62b26_idx",
            ),
        ]

    def __str__(self) -> str:
        return f"Notification({self.user_id}, {self.title})"
