from django.urls import path

from . import views

urlpatterns = [
    path("", views.home, name="home"),
    path("api/status/", views.api_status, name="api_status"),
    path("api/celery-status/", views.celery_status, name="celery_status"),
    path("api/task-status/<str:task_id>/", views.task_status, name="task_status"),
]
