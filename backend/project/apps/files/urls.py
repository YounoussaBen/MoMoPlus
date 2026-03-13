from django.urls import path

from .views import FileAssetAccessUrlView, FileAssetDetailView, FileAssetListCreateView

urlpatterns = [
    path("", FileAssetListCreateView.as_view(), name="files-list"),
    path("<uuid:file_id>/", FileAssetDetailView.as_view(), name="files-detail"),
    path("<uuid:file_id>/access-url/", FileAssetAccessUrlView.as_view(), name="files-access-url"),
]
