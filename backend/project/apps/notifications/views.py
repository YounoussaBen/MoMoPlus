from uuid import UUID

from django.shortcuts import get_object_or_404
from django.utils import timezone
from drf_spectacular.utils import OpenApiResponse, extend_schema
from rest_framework import status
from rest_framework.decorators import api_view, permission_classes
from rest_framework.permissions import IsAuthenticated
from rest_framework.request import Request
from rest_framework.response import Response

from .models import Notification
from .serializers import NotificationSerializer


@extend_schema(
    tags=["Notifications"],
    responses={status.HTTP_200_OK: OpenApiResponse(description="User notifications and unread count")},
)
@api_view(["GET"])
@permission_classes([IsAuthenticated])
def notification_list(request: Request) -> Response:
    notifications = Notification.objects.filter(user=request.user)
    return Response(
        {
            "notifications": NotificationSerializer(notifications, many=True).data,
            "unread_count": notifications.filter(is_read=False).count(),
        }
    )


def _get_owned_notification(request: Request, notification_id: UUID) -> Notification:
    return get_object_or_404(Notification, pk=notification_id, user=request.user)


def _set_read_state(*, notification: Notification, is_read: bool) -> Notification:
    notification.is_read = is_read
    notification.read_at = timezone.now() if is_read else None
    notification.save(update_fields=["is_read", "read_at", "updated_at"])
    return notification


@extend_schema(
    tags=["Notifications"],
    responses={
        status.HTTP_200_OK: NotificationSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Notification not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_notification_read(request: Request, notification_id: UUID) -> Response:
    notification = _set_read_state(
        notification=_get_owned_notification(request, notification_id),
        is_read=True,
    )
    return Response(NotificationSerializer(notification).data)


@extend_schema(
    tags=["Notifications"],
    responses={
        status.HTTP_200_OK: NotificationSerializer,
        status.HTTP_404_NOT_FOUND: OpenApiResponse(description="Notification not found"),
    },
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_notification_unread(request: Request, notification_id: UUID) -> Response:
    notification = _set_read_state(
        notification=_get_owned_notification(request, notification_id),
        is_read=False,
    )
    return Response(NotificationSerializer(notification).data)


@extend_schema(
    tags=["Notifications"],
    responses={status.HTTP_200_OK: OpenApiResponse(description="Unread notifications marked as read")},
)
@api_view(["POST"])
@permission_classes([IsAuthenticated])
def mark_all_notifications_read(request: Request) -> Response:
    updated = Notification.objects.filter(user=request.user, is_read=False).update(
        is_read=True,
        read_at=timezone.now(),
        updated_at=timezone.now(),
    )
    return Response({"updated": updated, "unread_count": 0})
