from django.urls import path

from . import views

urlpatterns = [
    path("nearby/", views.nearby_agents, name="agent-nearby"),
    path("profile/", views.my_profile, name="agent-profile"),
    path("profile/update/", views.update_profile, name="agent-profile-update"),
    path("profile/toggle-availability/", views.toggle_availability_view, name="agent-toggle-availability"),
    path("certification/", views.certification_status, name="agent-certification-status"),
    path("certification/apply/", views.certification_apply, name="agent-certification-apply"),
    path("<uuid:pk>/", views.agent_detail, name="agent-detail"),
]
