from rest_framework import serializers

from .models import KycSubmission
from .utils import normalize_ghana_card_number


class GhanaCardNumberField(serializers.CharField):
    def to_internal_value(self, data):
        value = super().to_internal_value(data)
        try:
            return normalize_ghana_card_number(value)
        except ValueError as exc:
            raise serializers.ValidationError(str(exc)) from exc


class KycSubmitSerializer(serializers.Serializer):
    ghana_card_number = GhanaCardNumberField(max_length=32)
    id_front_id = serializers.UUIDField()
    id_back_id = serializers.UUIDField()
    selfie_id = serializers.UUIDField()
    proof_of_address_id = serializers.UUIDField()


class KycStatusSerializer(serializers.ModelSerializer):
    ghana_card_number = serializers.CharField(read_only=True)
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
            "ghana_card_number",
            "verification_method",
            "id_front_id",
            "id_back_id",
            "selfie_id",
            "proof_of_address_id",
            "rejection_reason",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields
