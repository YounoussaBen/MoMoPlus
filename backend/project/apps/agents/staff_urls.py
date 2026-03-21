from django.urls import path

from . import staff_views

urlpatterns = [
    path("certifications/", staff_views.certification_list, name="staff-certification-list"),
    path("certifications/<uuid:application_id>/", staff_views.certification_detail, name="staff-certification-detail"),
    path(
        "certifications/<uuid:application_id>/approve/",
        staff_views.certification_approve,
        name="staff-certification-approve",
    ),
    path(
        "certifications/<uuid:application_id>/reject/",
        staff_views.certification_reject,
        name="staff-certification-reject",
    ),
]
