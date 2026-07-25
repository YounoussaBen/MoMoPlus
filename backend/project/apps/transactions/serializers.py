from decimal import Decimal

from rest_framework import serializers

from .models import PhysicalTransaction, TransactionType


class PhysicalTransactionSerializer(serializers.ModelSerializer):
    verification_code = serializers.SerializerMethodField()
    user_name = serializers.SerializerMethodField()
    agent_name = serializers.SerializerMethodField()
    agent_id = serializers.UUIDField(source="agent.pk", read_only=True)
    wallet_phone_number = serializers.CharField(source="wallet.phone_number", read_only=True)
    wallet_network = serializers.CharField(source="wallet.network", read_only=True)

    class Meta:
        model = PhysicalTransaction
        fields = [
            "id",
            "transaction_type",
            "amount",
            "network",
            "status",
            "verification_code",
            "meeting_latitude",
            "meeting_longitude",
            "meeting_description",
            "user_confirmed",
            "agent_confirmed",
            "user_name",
            "agent_name",
            "agent_id",
            "wallet_phone_number",
            "wallet_network",
            "cancellation_reason",
            "created_at",
            "updated_at",
            "completed_at",
            "expires_at",
        ]
        read_only_fields = fields

    def get_user_name(self, obj) -> str:
        return f"{obj.user.first_name} {obj.user.last_name}".strip()

    def get_agent_name(self, obj) -> str:
        agent_user = obj.agent.user
        return f"{agent_user.first_name} {agent_user.last_name}".strip()

    def get_verification_code(self, obj) -> str:
        """Only reveal an accepted transaction's code to its user."""
        request = self.context.get("request")
        if request is not None and request.user.pk == obj.user_id and obj.status == "accepted":
            return obj.verification_code
        return ""


class CreatePhysicalTransactionSerializer(serializers.Serializer):
    agent_id = serializers.UUIDField()
    transaction_type = serializers.ChoiceField(choices=TransactionType.choices)
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=Decimal("0.01"))
    network = serializers.CharField(max_length=15)
    wallet_id = serializers.UUIDField()


class AcceptTransactionSerializer(serializers.Serializer):
    meeting_latitude = serializers.FloatField()
    meeting_longitude = serializers.FloatField()
    meeting_description = serializers.CharField(required=False, default="", allow_blank=True)


class RejectTransactionSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, default="", allow_blank=True)


class CancelTransactionSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, default="", allow_blank=True)


class ConfirmTransactionSerializer(serializers.Serializer):
    verification_code = serializers.RegexField(
        r"^\d{6}$",
        required=False,
        default="",
        allow_blank=True,
        error_messages={"invalid": "Enter the 6-digit code."},
    )
