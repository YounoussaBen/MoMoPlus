from django.urls import path

from . import views

urlpatterns = [
    path("", views.notification_list, name="notification-list"),
    path("read-all/", views.mark_all_notifications_read, name="notification-read-all"),
    path("<uuid:notification_id>/read/", views.mark_notification_read, name="notification-read"),
    path("<uuid:notification_id>/unread/", views.mark_notification_unread, name="notification-unread"),
]
