from rest_framework import serializers

from .models import LoanGuarantor, User
from .phone_numbers import InvalidPhoneNumber, normalize_ghana_phone


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "supabase_user_id",
            "username",
            "email",
            "phone",
            "first_name",
            "last_name",
            "created_at",
            "updated_at",
            "is_active",
        ]
        read_only_fields = ["id", "created_at", "updated_at"]


class StaffUserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "username",
            "email",
            "phone",
            "first_name",
            "last_name",
            "is_active",
            "is_staff",
            "is_superuser",
        ]
        read_only_fields = fields


class UserProfileSerializer(serializers.ModelSerializer):
    full_name: serializers.SerializerMethodField = serializers.SerializerMethodField()
    has_guarantors: serializers.SerializerMethodField = serializers.SerializerMethodField()
    is_onboarded: serializers.BooleanField = serializers.BooleanField(read_only=True)

    class Meta:
        model = User
        fields = [
            "id",
            "supabase_user_id",
            "username",
            "email",
            "phone",
            "first_name",
            "last_name",
            "full_name",
            "role",
            "agent_status",
            "kyc_status",
            "has_guarantors",
            "is_onboarded",
            "created_at",
            "updated_at",
        ]
        read_only_fields = [
            "id",
            "supabase_user_id",
            "username",
            "email",
            "phone",
            "role",
            "agent_status",
            "kyc_status",
            "has_guarantors",
            "is_onboarded",
            "created_at",
            "updated_at",
        ]

    def get_full_name(self, obj: User) -> str:
        return f"{obj.first_name} {obj.last_name}".strip()

    def get_has_guarantors(self, obj: User) -> bool:
        return obj.loan_guarantors.filter(is_verified=True).count() >= 2


class AuthSyncResponseSerializer(serializers.Serializer):
    message = serializers.CharField(read_only=True)
    user = UserProfileSerializer(read_only=True)


class StaffLoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField(write_only=True, trim_whitespace=False)


class StaffLoginResponseSerializer(serializers.Serializer):
    access = serializers.CharField(read_only=True)
    token_type = serializers.CharField(read_only=True)
    expires_in = serializers.IntegerField(read_only=True)
    user = StaffUserSerializer(read_only=True)


class MessageSerializer(serializers.Serializer):
    message = serializers.CharField(read_only=True)


# ── Loan Guarantors ─────────────────────────────────────────────────────


class GuarantorSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanGuarantor
        fields = ["id", "name", "phone_number", "is_verified", "created_at", "updated_at"]
        read_only_fields = fields


class GuarantorCreateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200)
    phone_number = serializers.CharField(max_length=20)

    def validate_phone_number(self, value: str) -> str:
        try:
            return normalize_ghana_phone(value)
        except InvalidPhoneNumber as exc:
            raise serializers.ValidationError(str(exc)) from exc


class GuarantorBulkCreateSerializer(serializers.Serializer):
    guarantors = GuarantorCreateSerializer(many=True)

    def validate_guarantors(self, value: list[dict]) -> list[dict]:
        if len(value) < 2:
            raise serializers.ValidationError("At least 2 guarantors are required.")
        return value


class GuarantorUpdateSerializer(serializers.Serializer):
    name = serializers.CharField(max_length=200, required=False)
    phone_number = serializers.CharField(max_length=20, required=False)

    def validate_phone_number(self, value: str) -> str:
        try:
            return normalize_ghana_phone(value)
        except InvalidPhoneNumber as exc:
            raise serializers.ValidationError(str(exc)) from exc


class GuarantorVerifyOtpSerializer(serializers.Serializer):
    code = serializers.RegexField(r"^\d{6}$")
