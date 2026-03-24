from django.urls import path

from . import views

urlpatterns = [
    path("", views.loan_list, name="loan-list"),
    path("request/", views.loan_request, name="loan-request"),
    path("<uuid:pk>/", views.loan_detail, name="loan-detail"),
    path("<uuid:pk>/accept/", views.loan_accept, name="loan-accept"),
    path("<uuid:pk>/reject/", views.loan_reject, name="loan-reject"),
    path("<uuid:pk>/disburse/", views.loan_disburse, name="loan-disburse"),
    path("<uuid:pk>/repay/", views.loan_repay, name="loan-repay"),
    path("<uuid:pk>/cancel/", views.loan_cancel, name="loan-cancel"),
]
