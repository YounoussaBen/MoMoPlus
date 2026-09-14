from __future__ import annotations

from drf_spectacular.utils import extend_schema_field
from rest_framework import serializers

from project.apps.accounts.serializers import UserSerializer
from project.apps.files.models import FileAsset
from project.apps.files.serializers import FileAssetAccessUrlSerializer

from .models import GhanaCardRecord, KycSubmission
from .serializers import GhanaCardNumberField
from .utils import mask_ghana_card_number


class KycRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(min_length=1)


class StaffKycListSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)

    class Meta:
        model = KycSubmission
        fields = [
            "id",
            "user",
            "status",
            "id_type",
            "ghana_card_number",
            "verification_method",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class StaffKycDetailSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    id_front_url = serializers.SerializerMethodField()
    id_back_url = serializers.SerializerMethodField()
    selfie_url = serializers.SerializerMethodField()
    proof_of_address_url = serializers.SerializerMethodField()

    class Meta:
        model = KycSubmission
        fields = [
            "id",
            "user",
            "status",
            "id_type",
            "ghana_card_number",
            "verification_method",
            "id_front_url",
            "id_back_url",
            "selfie_url",
            "proof_of_address_url",
            "rejection_reason",
            "reviewed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def _get_url(self, asset: FileAsset | None) -> dict[str, str | int | None] | None:
        if asset is None:
            return None
        request = self.context.get("request")
        from project.apps.files.services import FileAssetAccessError, build_access_url

        try:
            return build_access_url(asset=asset, request=request)
        except FileAssetAccessError:
            return None

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_id_front_url(self, obj: KycSubmission) -> dict[str, str | int | None] | None:
        return self._get_url(obj.id_front)

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_id_back_url(self, obj: KycSubmission) -> dict[str, str | int | None] | None:
        return self._get_url(obj.id_back)

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_selfie_url(self, obj: KycSubmission) -> dict[str, str | int | None] | None:
        return self._get_url(obj.selfie)

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_proof_of_address_url(self, obj: KycSubmission) -> dict[str, str | int | None] | None:
        return self._get_url(obj.proof_of_address)


class GhanaCardRecordCreateSerializer(serializers.Serializer):
    card_number = GhanaCardNumberField(max_length=32)
    first_names = serializers.CharField(max_length=255)
    surname = serializers.CharField(max_length=255)
    date_of_birth = serializers.DateField(required=False, allow_null=True)
    sex = serializers.CharField(max_length=16, required=False, allow_blank=True)
    card_front_id = serializers.UUIDField()
    card_back_id = serializers.UUIDField()

    def validate_first_names(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("First names are required.")
        return value.strip()

    def validate_surname(self, value: str) -> str:
        if not value.strip():
            raise serializers.ValidationError("Surname is required.")
        return value.strip()


class GhanaCardRecordUpdateSerializer(serializers.Serializer):
    is_active = serializers.BooleanField()


class GhanaCardRecordListSerializer(serializers.ModelSerializer):
    masked_card_number = serializers.SerializerMethodField()

    class Meta:
        model = GhanaCardRecord
        fields = [
            "id",
            "masked_card_number",
            "first_names",
            "surname",
            "date_of_birth",
            "sex",
            "is_active",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_masked_card_number(self, obj: GhanaCardRecord) -> str:
        return mask_ghana_card_number(obj.card_number)


class GhanaCardRecordDetailSerializer(serializers.ModelSerializer):
    card_front_url = serializers.SerializerMethodField()
    card_back_url = serializers.SerializerMethodField()

    class Meta:
        model = GhanaCardRecord
        fields = [
            "id",
            "card_number",
            "first_names",
            "surname",
            "date_of_birth",
            "sex",
            "is_active",
            "card_front_url",
            "card_back_url",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def _get_url(self, asset: FileAsset) -> dict[str, str | int | None] | None:
        request = self.context.get("request")
        from project.apps.files.services import FileAssetAccessError, build_access_url

        try:
            return build_access_url(asset=asset, request=request)
        except FileAssetAccessError:
            return None

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_card_front_url(self, obj: GhanaCardRecord) -> dict[str, str | int | None] | None:
        return self._get_url(obj.card_front)

    @extend_schema_field(FileAssetAccessUrlSerializer)
    def get_card_back_url(self, obj: GhanaCardRecord) -> dict[str, str | int | None] | None:
        return self._get_url(obj.card_back)
