from __future__ import annotations

import json
from typing import Any

from django.urls import reverse
from rest_framework import serializers

from .models import FileAsset
from .services import resolve_visibility


class FileAssetSerializer(serializers.ModelSerializer):
    owner = serializers.PrimaryKeyRelatedField(read_only=True)
    uploaded_by = serializers.PrimaryKeyRelatedField(read_only=True)
    can_manage = serializers.SerializerMethodField()
    access_url_endpoint = serializers.SerializerMethodField()

    class Meta:
        model = FileAsset
        fields = [
            "id",
            "owner",
            "uploaded_by",
            "kind",
            "visibility",
            "status",
            "original_name",
            "content_type",
            "size",
            "sha256",
            "metadata",
            "created_at",
            "updated_at",
            "can_manage",
            "access_url_endpoint",
        ]
        read_only_fields = [
            "id",
            "owner",
            "uploaded_by",
            "status",
            "original_name",
            "content_type",
            "size",
            "sha256",
            "created_at",
            "updated_at",
            "can_manage",
            "access_url_endpoint",
        ]

    def get_can_manage(self, obj: FileAsset) -> bool:
        request = self.context.get("request")
        if request is None:
            return False
        return obj.can_manage(request.user)

    def get_access_url_endpoint(self, obj: FileAsset) -> str | None:
        request = self.context.get("request")
        if request is None:
            return None
        return request.build_absolute_uri(reverse("files-access-url", kwargs={"file_id": obj.id}))


class FileAssetUploadSerializer(serializers.Serializer):
    original_name = serializers.CharField(max_length=255)
    content_type = serializers.CharField(max_length=255)
    size = serializers.IntegerField(min_value=1)
    kind = serializers.ChoiceField(choices=FileAsset.FileKind.choices)
    visibility = serializers.ChoiceField(choices=FileAsset.Visibility.choices, required=False)
    metadata = serializers.JSONField(required=False)
    sha256 = serializers.CharField(max_length=64, required=False, allow_blank=True)

    def validate_metadata(self, value: Any) -> dict[str, Any]:
        if value in (None, ""):
            return {}

        if isinstance(value, str):
            try:
                value = json.loads(value)
            except json.JSONDecodeError as exc:
                raise serializers.ValidationError("Metadata must be valid JSON.") from exc

        if not isinstance(value, dict):
            raise serializers.ValidationError("Metadata must be a JSON object.")

        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        try:
            attrs["visibility"] = resolve_visibility(attrs["kind"], attrs.get("visibility"))
        except ValueError as exc:
            raise serializers.ValidationError({"visibility": str(exc)}) from exc
        attrs["metadata"] = attrs.get("metadata", {})
        attrs["sha256"] = attrs.get("sha256", "")
        return attrs


class FileAssetUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = FileAsset
        fields = ["visibility", "metadata"]

    def validate_metadata(self, value: Any) -> dict[str, Any]:
        if not isinstance(value, dict):
            raise serializers.ValidationError("Metadata must be a JSON object.")
        return value

    def validate(self, attrs: dict[str, Any]) -> dict[str, Any]:
        visibility = attrs.get("visibility", self.instance.visibility)
        try:
            attrs["visibility"] = resolve_visibility(self.instance.kind, visibility)
        except ValueError as exc:
            raise serializers.ValidationError({"visibility": str(exc)}) from exc
        return attrs


class FileAssetAccessUrlSerializer(serializers.Serializer):
    url = serializers.URLField(read_only=True)
    expires_in = serializers.IntegerField(read_only=True, allow_null=True)


class FileAssetUploadTargetSerializer(serializers.Serializer):
    provider = serializers.CharField(read_only=True)
    bucket = serializers.CharField(read_only=True)
    path = serializers.CharField(read_only=True)
    token = serializers.CharField(read_only=True)
    signed_url = serializers.URLField(read_only=True, allow_null=True)
    expires_in = serializers.IntegerField(read_only=True)


class FileAssetUploadInitResponseSerializer(serializers.Serializer):
    file = FileAssetSerializer(read_only=True)
    upload = FileAssetUploadTargetSerializer(read_only=True)
