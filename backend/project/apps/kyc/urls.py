from django.urls import path

from . import views

urlpatterns = [
    path("submit/", views.submit, name="kyc-submit"),
    path("status/", views.kyc_status, name="kyc-status"),
    path("draft/", views.kyc_draft, name="kyc-draft-get"),
    path("draft/save/", views.kyc_draft_save, name="kyc-draft-save"),
]
