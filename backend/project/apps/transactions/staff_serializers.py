from rest_framework import serializers

from .models import PhysicalTransaction


class StaffPhysicalTransactionSerializer(serializers.ModelSerializer):
    user_id = serializers.UUIDField(source="user.id", read_only=True)
    user_email = serializers.EmailField(source="user.email", read_only=True)
    user_name = serializers.SerializerMethodField()
    agent_user_id = serializers.UUIDField(source="agent.user.id", read_only=True)
    agent_id = serializers.UUIDField(source="agent.id", read_only=True)
    agent_email = serializers.EmailField(source="agent.user.email", read_only=True)
    agent_name = serializers.SerializerMethodField()
    wallet_phone_number = serializers.CharField(source="wallet.phone_number", read_only=True)
    wallet_network = serializers.CharField(source="wallet.network", read_only=True)
    has_meeting = serializers.SerializerMethodField()

    class Meta:
        model = PhysicalTransaction
        fields = [
            "id",
            "user_id",
            "user_email",
            "user_name",
            "agent_user_id",
            "agent_id",
            "agent_email",
            "agent_name",
            "transaction_type",
            "amount",
            "network",
            "status",
            "verification_code",
            "meeting_latitude",
            "meeting_longitude",
            "meeting_description",
            "has_meeting",
            "user_confirmed",
            "agent_confirmed",
            "wallet_phone_number",
            "wallet_network",
            "cancellation_reason",
            "created_at",
            "updated_at",
            "completed_at",
            "expires_at",
        ]
        read_only_fields = fields

    def get_user_name(self, obj: PhysicalTransaction) -> str:
        return f"{obj.user.first_name} {obj.user.last_name}".strip()

    def get_agent_name(self, obj: PhysicalTransaction) -> str:
        return f"{obj.agent.user.first_name} {obj.agent.user.last_name}".strip()

    def get_has_meeting(self, obj: PhysicalTransaction) -> bool:
        return obj.meeting_latitude is not None and obj.meeting_longitude is not None
