import pytest

from project.apps.notifications.models import Notification, NotificationKind
from project.apps.notifications.services import create_notification


@pytest.mark.django_db
def test_create_notification_is_idempotent_for_a_lifecycle_event(user_factory):
    user = user_factory(email="notifications@example.com", username="notifications")

    first = create_notification(
        user=user,
        kind=NotificationKind.LOAN_REQUEST,
        title="New Get Funds request",
        message="A user requested funds.",
        resource_type="loan",
        resource_id="loan-1",
        dedupe_key="loan:loan-1:request",
    )
    second = create_notification(
        user=user,
        kind=NotificationKind.LOAN_REQUEST,
        title="New Get Funds request",
        message="A user requested funds.",
        resource_type="loan",
        resource_id="loan-1",
        dedupe_key="loan:loan-1:request",
    )

    assert second.pk == first.pk
    assert Notification.objects.filter(user=user).count() == 1
    assert first.is_read is False
