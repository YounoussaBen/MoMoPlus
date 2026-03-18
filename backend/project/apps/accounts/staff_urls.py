from django.urls import path

from . import staff_views

urlpatterns = [
    path("users/", staff_views.user_list, name="staff-user-list"),
    path("users/<str:user_id>/", staff_views.user_detail, name="staff-user-detail"),
    path("users/<str:user_id>/approve-agent/", staff_views.approve_agent, name="staff-approve-agent"),
    path("users/<str:user_id>/reject-agent/", staff_views.reject_agent, name="staff-reject-agent"),
]
