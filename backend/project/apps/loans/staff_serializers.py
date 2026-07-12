from django.utils import timezone
from rest_framework import serializers

from .models import Loan, LoanPayment, LoanStatus


class StaffLoanPaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = LoanPayment
        fields = [
            "id",
            "payment_type",
            "amount",
            "charge_amount",
            "transfer_amount",
            "platform_amount",
            "status",
            "reference",
            "paystack_reference",
            "payer_phone",
            "payer_network",
            "recipient_code",
            "completed_at",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class StaffLoanBaseSerializer(serializers.ModelSerializer):
    borrower_id = serializers.UUIDField(source="borrower.id", read_only=True)
    borrower_name = serializers.SerializerMethodField()
    borrower_email = serializers.EmailField(source="borrower.email", read_only=True)
    borrower_phone = serializers.CharField(source="borrower.phone", read_only=True, allow_null=True)
    agent_user_id = serializers.UUIDField(source="agent.user.id", read_only=True)
    agent_id = serializers.UUIDField(source="agent.id", read_only=True)
    agent_name = serializers.SerializerMethodField()
    agent_email = serializers.EmailField(source="agent.user.email", read_only=True)
    agent_phone = serializers.CharField(source="agent.user.phone", read_only=True, allow_null=True)
    borrower_wallet_phone = serializers.CharField(source="borrower_wallet.phone_number", read_only=True)
    borrower_wallet_network = serializers.CharField(source="borrower_wallet.network", read_only=True)
    agent_wallet_phone = serializers.SerializerMethodField()
    agent_wallet_network = serializers.SerializerMethodField()
    is_overdue = serializers.SerializerMethodField()

    def get_borrower_name(self, obj: Loan) -> str:
        return f"{obj.borrower.first_name} {obj.borrower.last_name}".strip()

    def get_agent_name(self, obj: Loan) -> str:
        return f"{obj.agent.user.first_name} {obj.agent.user.last_name}".strip()

    def get_agent_wallet_phone(self, obj: Loan) -> str:
        return obj.agent_wallet.phone_number if obj.agent_wallet else ""

    def get_agent_wallet_network(self, obj: Loan) -> str:
        return obj.agent_wallet.network if obj.agent_wallet else ""

    def get_is_overdue(self, obj: Loan) -> bool:
        return obj.status == LoanStatus.ACTIVE and obj.deadline_at is not None and obj.deadline_at < timezone.now()


class StaffLoanListSerializer(StaffLoanBaseSerializer):
    class Meta:
        model = Loan
        fields = [
            "id",
            "borrower_id",
            "borrower_name",
            "borrower_email",
            "borrower_phone",
            "agent_user_id",
            "agent_id",
            "agent_name",
            "agent_email",
            "agent_phone",
            "amount",
            "total_repayment",
            "outstanding_balance",
            "agent_receivable_balance",
            "penalty_amount",
            "status",
            "network",
            "borrower_wallet_phone",
            "borrower_wallet_network",
            "agent_wallet_phone",
            "agent_wallet_network",
            "approved_at",
            "disbursed_at",
            "deadline_at",
            "completed_at",
            "defaulted_at",
            "is_overdue",
            "created_at",
            "updated_at",
        ]
        read_only_fields = fields


class StaffLoanDetailSerializer(StaffLoanBaseSerializer):
    payments = StaffLoanPaymentSerializer(many=True, read_only=True)

    class Meta:
        model = Loan
        fields = [
            "id",
            "borrower_id",
            "borrower_name",
            "borrower_email",
            "borrower_phone",
            "agent_user_id",
            "agent_id",
            "agent_name",
            "agent_email",
            "agent_phone",
            "amount",
            "interest_rate",
            "origination_fee",
            "agent_interest_amount",
            "platform_interest_amount",
            "total_repayment",
            "penalty_amount",
            "outstanding_balance",
            "agent_receivable_balance",
            "status",
            "network",
            "borrower_wallet_phone",
            "borrower_wallet_network",
            "agent_wallet_phone",
            "agent_wallet_network",
            "rejection_reason",
            "approved_at",
            "disbursed_at",
            "deadline_at",
            "last_penalty_at",
            "completed_at",
            "defaulted_at",
            "is_overdue",
            "created_at",
            "updated_at",
            "payments",
        ]
        read_only_fields = fields
