from rest_framework import serializers

from project.apps.accounts.serializers import UserSerializer

from .models import KycSubmission


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

    def _get_url(self, asset):
        if asset is None:
            return None
        request = self.context.get("request")
        from project.apps.files.services import FileAssetAccessError, build_access_url

        try:
            return build_access_url(asset=asset, request=request)
        except FileAssetAccessError:
            return None

    def get_id_front_url(self, obj):
        return self._get_url(obj.id_front)

    def get_id_back_url(self, obj):
        return self._get_url(obj.id_back)

    def get_selfie_url(self, obj):
        return self._get_url(obj.selfie)

    def get_proof_of_address_url(self, obj):
        return self._get_url(obj.proof_of_address)
