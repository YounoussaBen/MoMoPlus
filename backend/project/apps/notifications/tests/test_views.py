import pytest

from project.apps.notifications.models import Notification, NotificationKind


@pytest.mark.django_db
class TestNotificationViews:
    def test_lists_only_owned_notifications_with_unread_count(self, user_factory, auth_client_factory):
        user = user_factory(email="notifications@example.com", username="notifications")
        other_user = user_factory(email="other-notifications@example.com", username="other-notifications")
        client = auth_client_factory(
            {
                "sub": str(user.supabase_user_id),
                "email": user.email,
            }
        )
        unread_notification = Notification.objects.create(
            user=user,
            kind=NotificationKind.LOAN_REQUEST,
            title="New request",
            message="A request is waiting.",
        )
        read_notification = Notification.objects.create(
            user=user,
            kind=NotificationKind.LOAN_STATUS,
            title="Request accepted",
            message="Your request was accepted.",
            is_read=True,
        )
        Notification.objects.create(
            user=other_user,
            kind=NotificationKind.LOAN_REQUEST,
            title="Private request",
            message="This belongs to another user.",
        )

        response = client.get("/api/notifications/")

        assert response.status_code == 200
        assert response.data["unread_count"] == 1
        assert len(response.data["notifications"]) == 2
        assert {item["id"] for item in response.data["notifications"]} == {
            str(read_notification.id),
            str(unread_notification.id),
        }

    def test_can_mark_read_unread_and_mark_all_read(self, user_factory, auth_client_factory):
        user = user_factory(email="notification-controls@example.com", username="notification-controls")
        client = auth_client_factory(
            {
                "sub": str(user.supabase_user_id),
                "email": user.email,
            }
        )
        first = Notification.objects.create(
            user=user,
            kind=NotificationKind.TRANSACTION_REQUEST,
            title="New cash request",
            message="A cash request is waiting.",
        )
        second = Notification.objects.create(
            user=user,
            kind=NotificationKind.TRANSACTION_STATUS,
            title="Cash request accepted",
            message="Your cash request was accepted.",
        )

        read_response = client.post(f"/api/notifications/{first.pk}/read/")
        assert read_response.status_code == 200
        first.refresh_from_db()
        assert first.is_read is True
        assert first.read_at is not None

        unread_response = client.post(f"/api/notifications/{first.pk}/unread/")
        assert unread_response.status_code == 200
        first.refresh_from_db()
        assert first.is_read is False
        assert first.read_at is None

        all_read_response = client.post("/api/notifications/read-all/")
        assert all_read_response.status_code == 200
        assert all_read_response.data == {"updated": 2, "unread_count": 0}
        assert Notification.objects.filter(user=user, is_read=False).count() == 0
        second.refresh_from_db()
        assert second.read_at is not None

    def test_cannot_manage_another_users_notification(self, user_factory, auth_client_factory):
        user = user_factory(email="notification-owner@example.com", username="notification-owner")
        other_user = user_factory(email="notification-outsider@example.com", username="notification-outsider")
        client = auth_client_factory(
            {
                "sub": str(user.supabase_user_id),
                "email": user.email,
            }
        )
        notification = Notification.objects.create(
            user=other_user,
            kind=NotificationKind.LOAN_STATUS,
            title="Private status",
            message="This should remain private.",
        )

        response = client.post(f"/api/notifications/{notification.pk}/read/")

        assert response.status_code == 404
        notification.refresh_from_db()
        assert notification.is_read is False
