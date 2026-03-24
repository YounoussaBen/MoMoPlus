from rest_framework import serializers

from .models import Wallet


class WalletSerializer(serializers.ModelSerializer):
    has_paystack = serializers.SerializerMethodField()

    def get_has_paystack(self, obj: Wallet) -> bool:
        return bool(obj.paystack_recipient_code)

    class Meta:
        model = Wallet
        fields = [
            "id",
            "phone_number",
            "network",
            "is_verified",
            "is_default",
            "has_paystack",
            "created_at",
        ]
        read_only_fields = fields


class AddWalletSerializer(serializers.Serializer):
    phone_number = serializers.CharField(max_length=15)
    network = serializers.ChoiceField(choices=Wallet.Network.choices)


class VerifyOtpSerializer(serializers.Serializer):
    code = serializers.CharField(min_length=6, max_length=6)
