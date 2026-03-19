from rest_framework import serializers

from .models import KycSubmission


class KycSubmitSerializer(serializers.Serializer):
    id_type = serializers.ChoiceField(choices=KycSubmission.IdType.choices)
    id_front_id = serializers.UUIDField()
    id_back_id = serializers.UUIDField()
    selfie_id = serializers.UUIDField()
    proof_of_address_id = serializers.UUIDField()


class KycStatusSerializer(serializers.ModelSerializer):
    id_front_id = serializers.UUIDField(read_only=True)
    id_back_id = serializers.UUIDField(read_only=True)
    selfie_id = serializers.UUIDField(read_only=True)
    proof_of_address_id = serializers.UUIDField(read_only=True)

    class Meta:
        model = KycSubmission
        fields = [
            "id",
            "status",
            "id_type",
            "id_front_id",
            "id_back_id",
            "selfie_id",
            "proof_of_address_id",
            "rejection_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields
