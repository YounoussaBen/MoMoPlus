from django.urls import path

from . import views

urlpatterns = [
    path("hooks/send-sms/", views.supabase_send_sms_hook, name="supabase-send-sms-hook"),
    path("staff/login/", views.staff_login, name="staff-login"),
    path("sync/", views.sync_profile, name="sync"),
    path("profile/", views.profile, name="profile"),
    path("logout/", views.logout, name="logout"),
    path("request-agent/", views.request_agent, name="request-agent"),
    # Guarantors
    path("guarantors/", views.guarantor_list, name="guarantor-list"),
    path("guarantors/bulk/", views.guarantor_bulk_create, name="guarantor-bulk-create"),
    path("guarantors/<uuid:guarantor_id>/verify/", views.guarantor_verify, name="guarantor-verify"),
    path("guarantors/<uuid:guarantor_id>/resend-otp/", views.guarantor_resend_otp, name="guarantor-resend-otp"),
    path("guarantors/<uuid:guarantor_id>/", views.guarantor_detail, name="guarantor-detail"),
]
