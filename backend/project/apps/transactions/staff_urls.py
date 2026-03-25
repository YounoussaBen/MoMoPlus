from django.urls import path

from . import staff_views

urlpatterns = [
    path("physical/", staff_views.transaction_list, name="staff-physical-transaction-list"),
    path("physical/<uuid:transaction_id>/", staff_views.transaction_detail, name="staff-physical-transaction-detail"),
]
