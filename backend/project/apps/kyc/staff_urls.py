from django.urls import path

from . import staff_views

urlpatterns = [
    path("ghana-cards/", staff_views.ghana_card_list_create, name="staff-ghana-card-list-create"),
    path("ghana-cards/<uuid:record_id>/", staff_views.ghana_card_detail, name="staff-ghana-card-detail"),
    path("", staff_views.submission_list, name="staff-kyc-list"),
    path("<uuid:submission_id>/", staff_views.submission_detail, name="staff-kyc-detail"),
    path("<uuid:submission_id>/approve/", staff_views.approve, name="staff-kyc-approve"),
    path("<uuid:submission_id>/reject/", staff_views.reject, name="staff-kyc-reject"),
]
