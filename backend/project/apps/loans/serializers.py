from rest_framework import serializers

from .models import Loan, LoanPayment


class LoanPaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanPayment
        fields = [
            "id",
            "payment_type",
            "amount",
            "status",
            "reference",
            "payer_phone",
            "payer_network",
            "completed_at",
            "created_at",
        ]
        read_only_fields = fields


class LoanSerializer(serializers.ModelSerializer):
    borrower_name = serializers.SerializerMethodField()
    borrower_email = serializers.SerializerMethodField()
    agent_name = serializers.SerializerMethodField()
    agent_id = serializers.SerializerMethodField()
    borrower_wallet_phone = serializers.SerializerMethodField()
    borrower_wallet_network = serializers.SerializerMethodField()
    agent_wallet_phone = serializers.SerializerMethodField()
    payments = LoanPaymentSerializer(many=True, read_only=True)

    def get_borrower_name(self, obj: Loan) -> str:
        return f"{obj.borrower.first_name} {obj.borrower.last_name}".strip()

    def get_borrower_email(self, obj: Loan) -> str:
        return obj.borrower.email

    def get_agent_name(self, obj: Loan) -> str:
        u = obj.agent.user
        return f"{u.first_name} {u.last_name}".strip()

    def get_agent_id(self, obj: Loan) -> str:
        return str(obj.agent_id)

    def get_borrower_wallet_phone(self, obj: Loan) -> str:
        return obj.borrower_wallet.phone_number if obj.borrower_wallet else ""

    def get_borrower_wallet_network(self, obj: Loan) -> str:
        return obj.borrower_wallet.network if obj.borrower_wallet else ""

    def get_agent_wallet_phone(self, obj: Loan) -> str:
        return obj.agent_wallet.phone_number if obj.agent_wallet else ""

    class Meta:
        model = Loan
        fields = [
            "id",
            "borrower_name",
            "borrower_email",
            "agent_name",
            "agent_id",
            "amount",
            "interest_rate",
            "total_repayment",
            "penalty_amount",
            "outstanding_balance",
            "status",
            "network",
            "borrower_wallet_phone",
            "borrower_wallet_network",
            "agent_wallet_phone",
            "rejection_reason",
            "approved_at",
            "disbursed_at",
            "deadline_at",
            "completed_at",
            "defaulted_at",
            "created_at",
            "payments",
        ]
        read_only_fields = fields


class RequestLoanSerializer(serializers.Serializer):
    agent_id = serializers.UUIDField()
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=1)
    wallet_id = serializers.UUIDField()
    network = serializers.CharField(max_length=15)


class AcceptLoanSerializer(serializers.Serializer):
    agent_wallet_id = serializers.UUIDField()


class RejectLoanSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, default="", allow_blank=True)


class CancelLoanSerializer(serializers.Serializer):
    reason = serializers.CharField(required=False, default="", allow_blank=True)


class RepayLoanSerializer(serializers.Serializer):
    amount = serializers.DecimalField(max_digits=10, decimal_places=2, min_value=1, required=False)
