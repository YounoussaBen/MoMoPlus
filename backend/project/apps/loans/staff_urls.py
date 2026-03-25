from django.urls import path

from . import staff_views

urlpatterns = [
    path("", staff_views.loan_list, name="staff-loan-list"),
    path("<uuid:loan_id>/", staff_views.loan_detail, name="staff-loan-detail"),
]
