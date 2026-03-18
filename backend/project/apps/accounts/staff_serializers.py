from rest_framework import serializers

from .models import User


class StaffUserListSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "agent_status",
            "is_active",
            "is_staff",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields

    def get_full_name(self, obj: User) -> str:
        return f"{obj.first_name} {obj.last_name}".strip()


class StaffUserDetailSerializer(StaffUserListSerializer):
    class Meta(StaffUserListSerializer.Meta):
        fields = StaffUserListSerializer.Meta.fields + ["supabase_user_id", "username", "is_superuser"]
        read_only_fields = fields


class AgentRejectSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, allow_blank=True, default="")
