from typing import Any

from django.db import IntegrityError

from .models import Notification


def create_notification(
    *,
    user: Any,
    kind: str,
    title: str,
    message: str,
    resource_type: str = "",
    resource_id: str = "",
    metadata: dict[str, Any] | None = None,
    dedupe_key: str | None = None,
) -> Notification:
    """Create a durable notification, safely ignoring repeated lifecycle events."""
    scoped_key = f"{user.pk}:{dedupe_key}" if dedupe_key else None
    defaults = {
        "user": user,
        "kind": kind,
        "title": title,
        "message": message,
        "resource_type": resource_type,
        "resource_id": str(resource_id) if resource_id else "",
        "metadata": metadata or {},
    }

    if scoped_key is None:
        return Notification.objects.create(**defaults)

    try:
        notification, _ = Notification.objects.get_or_create(
            dedupe_key=scoped_key,
            defaults=defaults,
        )
    except IntegrityError:
        # A concurrent webhook/request may have inserted the same event.
        notification = Notification.objects.get(dedupe_key=scoped_key)
    return notification
