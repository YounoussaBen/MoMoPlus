from rest_framework import serializers

from .models import User


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = [
            "id",
            "supabase_user_id",
            "username",
            "email",
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
            "first_name",
            "last_name",
            "is_active",
            "is_staff",
            "is_superuser",
        ]
        read_only_fields = fields


class UserProfileSerializer(serializers.ModelSerializer):
    full_name: serializers.SerializerMethodField = serializers.SerializerMethodField()

    class Meta:
        model = User
        fields = [
            "id",
            "supabase_user_id",
            "username",
            "email",
            "first_name",
            "last_name",
            "full_name",
            "created_at",
            "updated_at",
        ]
        read_only_fields = ["id", "supabase_user_id", "username", "email", "created_at", "updated_at"]

    def get_full_name(self, obj: User) -> str:
        return f"{obj.first_name} {obj.last_name}".strip()


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
