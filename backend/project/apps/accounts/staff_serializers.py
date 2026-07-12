from rest_framework import serializers

from project.apps.kyc.models import KycSubmission

from .models import User


class StaffUserKycSummarySerializer(serializers.ModelSerializer):
    class Meta:
        model = KycSubmission
        fields = [
            "id",
            "status",
            "id_type",
            "rejection_reason",
            "reviewed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class StaffUserListSerializer(serializers.ModelSerializer):
    full_name = serializers.SerializerMethodField()
    kyc_submission = StaffUserKycSummarySerializer(read_only=True, allow_null=True)

    class Meta:
        model = User
        fields = [
            "id",
            "email",
            "phone",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "agent_status",
            "kyc_status",
            "kyc_submission",
            "is_active",
            "deactivation_reason",
            "deactivated_at",
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


class AccountDeactivateSerializer(serializers.Serializer):
    reason = serializers.CharField(min_length=1, max_length=1000, trim_whitespace=True)
