from django.urls import path

from . import views

urlpatterns = [
    path("physical/", views.list_transactions, name="transaction-list"),
    path("physical/create/", views.create_transaction, name="transaction-create"),
    path("physical/<uuid:pk>/", views.transaction_detail, name="transaction-detail"),
    path("physical/<uuid:pk>/accept/", views.accept_transaction_view, name="transaction-accept"),
    path("physical/<uuid:pk>/reject/", views.reject_transaction_view, name="transaction-reject"),
    path("physical/<uuid:pk>/confirm/", views.confirm_transaction_view, name="transaction-confirm"),
    path("physical/<uuid:pk>/cancel/", views.cancel_transaction_view, name="transaction-cancel"),
    path("physical/<uuid:pk>/rate/", views.rate_cash_service_view, name="transaction-rate"),
]
