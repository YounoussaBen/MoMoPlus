from django.urls import path

from . import views

urlpatterns = [
    path("staff/login/", views.staff_login, name="staff-login"),
    path("sync/", views.sync_profile, name="sync"),
    path("profile/", views.profile, name="profile"),
    path("logout/", views.logout, name="logout"),
]
