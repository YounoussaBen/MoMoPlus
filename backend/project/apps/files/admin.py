from django.contrib import admin

from .models import FileAsset


@admin.register(FileAsset)
class FileAssetAdmin(admin.ModelAdmin):
    list_display = (
        "id",
        "kind",
        "visibility",
        "status",
        "owner",
        "uploaded_by",
        "size",
        "created_at",
    )
    list_filter = ("kind", "visibility", "status", "created_at")
    search_fields = ("id", "original_name", "storage_path", "owner__email", "uploaded_by__email")
    readonly_fields = (
        "id",
        "storage_path",
        "storage_bucket",
        "original_name",
        "content_type",
        "size",
        "sha256",
        "created_at",
        "updated_at",
        "deleted_at",
    )
