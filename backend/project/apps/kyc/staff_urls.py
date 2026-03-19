from django.urls import path

from . import staff_views

urlpatterns = [
    path("", staff_views.submission_list, name="staff-kyc-list"),
    path("<uuid:submission_id>/", staff_views.submission_detail, name="staff-kyc-detail"),
    path("<uuid:submission_id>/approve/", staff_views.approve, name="staff-kyc-approve"),
    path("<uuid:submission_id>/reject/", staff_views.reject, name="staff-kyc-reject"),
]
