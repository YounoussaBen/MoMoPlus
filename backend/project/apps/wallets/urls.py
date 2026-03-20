from django.urls import path

from . import views

urlpatterns = [
    path("", views.wallet_list, name="wallet-list"),
    path("add/", views.wallet_create, name="wallet-create"),
    path("<uuid:pk>/verify/", views.wallet_verify, name="wallet-verify"),
    path("<uuid:pk>/resend-otp/", views.wallet_resend_otp, name="wallet-resend-otp"),
    path("<uuid:pk>/set-default/", views.wallet_set_default, name="wallet-set-default"),
    path("<uuid:pk>/", views.wallet_delete, name="wallet-delete"),
]
