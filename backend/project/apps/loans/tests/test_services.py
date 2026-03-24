from decimal import Decimal
from unittest.mock import patch

import pytest

from project.apps.accounts.factories import UserFactory
from project.apps.accounts.models import AgentStatus, KycStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.loans.models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType
from project.apps.loans.services import (
    accept_loan,
    apply_penalties,
    cancel_loan,
    flag_defaulted_loans,
    handle_charge_failed,
    handle_charge_success,
    initiate_disbursement,
    initiate_repayment,
    reject_loan,
    request_loan,
)
from project.apps.wallets.models import Wallet


@pytest.fixture
def borrower():
    user = UserFactory(
        role=UserRole.USER,
        kyc_status=KycStatus.APPROVED,
    )
    return user


@pytest.fixture
def agent_user():
    user = UserFactory(
        role=UserRole.AGENT,
        agent_status=AgentStatus.APPROVED,
        kyc_status=KycStatus.APPROVED,
    )
    return user


@pytest.fixture
def agent_profile(agent_user):
    return AgentProfile.objects.create(
        user=agent_user,
        is_available=True,
        min_amount=Decimal("10.00"),
        max_amount=Decimal("500.00"),
        latitude=Decimal("5.600000"),
        longitude=Decimal("-0.200000"),
        agent_type=AgentType.CERTIFIED,
    )


@pytest.fixture
def borrower_wallet(borrower):
    return Wallet.objects.create(
        user=borrower,
        phone_number="0551234567",
        network="mtn",
        is_verified=True,
        is_default=True,
        paystack_subaccount_code="SUB_test_borrower",
        paystack_recipient_code="RCP_test_borrower",
    )


@pytest.fixture
def agent_wallet(agent_user):
    return Wallet.objects.create(
        user=agent_user,
        phone_number="0559876543",
        network="mtn",
        is_verified=True,
        is_default=True,
        paystack_subaccount_code="SUB_test_agent",
        paystack_recipient_code="RCP_test_agent",
    )


@pytest.fixture
def pending_loan(borrower, agent_profile, borrower_wallet):
    return Loan.objects.create(
        borrower=borrower,
        agent=agent_profile,
        amount=Decimal("100.00"),
        interest_rate=Decimal("10.00"),
        total_repayment=Decimal("110.00"),
        outstanding_balance=Decimal("110.00"),
        borrower_wallet=borrower_wallet,
        network="mtn",
        status=LoanStatus.PENDING,
    )


@pytest.mark.django_db
class TestRequestLoan:
    def test_success(self, borrower, agent_profile, borrower_wallet):
        loan = request_loan(
            borrower=borrower,
            agent_profile_id=str(agent_profile.pk),
            amount=Decimal("100.00"),
            wallet_id=str(borrower_wallet.pk),
            network="mtn",
        )
        assert loan.status == LoanStatus.PENDING
        assert loan.amount == Decimal("100.00")
        assert loan.total_repayment == Decimal("110.00")
        assert loan.outstanding_balance == Decimal("110.00")

    def test_amount_below_min(self, borrower, agent_profile, borrower_wallet):
        with pytest.raises(ValueError, match="Minimum loan amount"):
            request_loan(
                borrower=borrower,
                agent_profile_id=str(agent_profile.pk),
                amount=Decimal("1.00"),
                wallet_id=str(borrower_wallet.pk),
                network="mtn",
            )

    def test_amount_above_max(self, borrower, agent_profile, borrower_wallet):
        with pytest.raises(ValueError, match="Maximum loan amount"):
            request_loan(
                borrower=borrower,
                agent_profile_id=str(agent_profile.pk),
                amount=Decimal("1000.00"),
                wallet_id=str(borrower_wallet.pk),
                network="mtn",
            )

    def test_cannot_loan_from_self(self, agent_user, agent_profile, agent_wallet):
        agent_wallet.paystack_subaccount_code = "SUB_test"
        agent_wallet.save()
        with pytest.raises(ValueError, match="yourself"):
            request_loan(
                borrower=agent_user,
                agent_profile_id=str(agent_profile.pk),
                amount=Decimal("50.00"),
                wallet_id=str(agent_wallet.pk),
                network="mtn",
            )

    def test_duplicate_active_loan(self, borrower, agent_profile, borrower_wallet, pending_loan):
        with pytest.raises(ValueError, match="already have an active loan"):
            request_loan(
                borrower=borrower,
                agent_profile_id=str(agent_profile.pk),
                amount=Decimal("50.00"),
                wallet_id=str(borrower_wallet.pk),
                network="mtn",
            )


@pytest.mark.django_db
class TestAcceptLoan:
    def test_success(self, pending_loan, agent_user, agent_wallet):
        loan = accept_loan(
            loan=pending_loan,
            agent_user=agent_user,
            agent_wallet_id=str(agent_wallet.pk),
        )
        assert loan.status == LoanStatus.APPROVED
        assert loan.agent_wallet == agent_wallet
        assert loan.approved_at is not None

    def test_wrong_agent(self, pending_loan, borrower, agent_wallet):
        with pytest.raises(ValueError, match="Only the assigned agent"):
            accept_loan(
                loan=pending_loan,
                agent_user=borrower,
                agent_wallet_id=str(agent_wallet.pk),
            )


@pytest.mark.django_db
class TestRejectLoan:
    def test_success(self, pending_loan, agent_user):
        loan = reject_loan(loan=pending_loan, agent_user=agent_user, reason="No funds")
        assert loan.status == LoanStatus.REJECTED
        assert loan.rejection_reason == "No funds"


@pytest.mark.django_db
class TestCancelLoan:
    def test_borrower_can_cancel(self, pending_loan, borrower):
        loan = cancel_loan(loan=pending_loan, user=borrower, reason="Changed mind")
        assert loan.status == LoanStatus.CANCELLED

    def test_agent_can_cancel(self, pending_loan, agent_user):
        loan = cancel_loan(loan=pending_loan, user=agent_user)
        assert loan.status == LoanStatus.CANCELLED


@pytest.mark.django_db
class TestDisbursement:
    @patch("project.apps.loans.services.paystack.charge_mobile_money")
    def test_success(self, mock_charge, pending_loan, agent_user, agent_wallet):
        mock_charge.return_value = {
            "reference": "DISB_test123",
            "status": "pay_offline",
        }
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.APPROVED
        pending_loan.save()

        payment = initiate_disbursement(loan=pending_loan)
        assert payment.payment_type == PaymentType.DISBURSEMENT
        assert payment.status == PaymentStatus.PENDING
        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.DISBURSING

    @patch("project.apps.loans.services.paystack.charge_mobile_money")
    def test_paystack_failure(self, mock_charge, pending_loan, agent_user, agent_wallet):
        from project.integrations.paystack import PaystackError

        mock_charge.side_effect = PaystackError("Insufficient funds")
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.APPROVED
        pending_loan.save()

        with pytest.raises(ValueError, match="Disbursement failed"):
            initiate_disbursement(loan=pending_loan)

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.FAILED


@pytest.mark.django_db
class TestRepayment:
    @patch("project.apps.loans.services.paystack.charge_mobile_money")
    def test_success(self, mock_charge, pending_loan, agent_wallet):
        from django.utils import timezone

        mock_charge.return_value = {
            "reference": "REPAY_test123",
            "status": "pay_offline",
        }
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.ACTIVE
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        payment = initiate_repayment(loan=pending_loan)
        assert payment.payment_type == PaymentType.REPAYMENT
        assert payment.amount == Decimal("110.00")
        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.REPAYING


@pytest.mark.django_db
class TestWebhookHandlers:
    def test_charge_success_disbursement(self, pending_loan, agent_wallet):
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            reference="DISB_webhook_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_charge_success(reference="DISB_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.SUCCESS

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.ACTIVE
        assert pending_loan.disbursed_at is not None
        assert pending_loan.deadline_at is not None

    def test_charge_success_repayment_full(self, pending_loan, agent_wallet):
        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.REPAYING
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.REPAYMENT,
            amount=pending_loan.outstanding_balance,
            reference="REPAY_webhook_test",
            payer_phone="0551234567",
            payer_network="mtn",
        )

        handle_charge_success(reference="REPAY_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.SUCCESS

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.COMPLETED
        assert pending_loan.outstanding_balance == Decimal("0.00")

    def test_charge_failed(self, pending_loan, agent_wallet):
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            reference="DISB_fail_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_charge_failed(reference="DISB_fail_test", paystack_data={"status": "failed"})

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.FAILED


@pytest.mark.django_db
class TestPenalties:
    def test_apply_penalties(self, pending_loan, agent_wallet):
        from datetime import timedelta

        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.ACTIVE
        pending_loan.disbursed_at = timezone.now() - timedelta(hours=48)
        pending_loan.deadline_at = timezone.now() - timedelta(hours=24)
        pending_loan.save()

        count = apply_penalties()
        assert count == 1

        pending_loan.refresh_from_db()
        assert pending_loan.penalty_amount == Decimal("2.00")  # 2% of 100
        assert pending_loan.outstanding_balance == Decimal("112.00")

    def test_flag_defaulted(self, pending_loan, agent_wallet):
        from datetime import timedelta

        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.ACTIVE
        pending_loan.deadline_at = timezone.now() - timedelta(days=8)
        pending_loan.save()

        count = flag_defaulted_loans()
        assert count == 1

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.DEFAULTED
