from decimal import Decimal
from unittest.mock import patch

import pytest
from django.test import override_settings

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
    handle_transfer_failed,
    handle_transfer_success,
    initiate_disbursement,
    initiate_repayment,
    reject_loan,
    request_loan,
)
from project.apps.notifications.models import Notification, NotificationKind
from project.apps.wallets.models import Wallet

EXPECTED_ORIGINATION_FEE = Decimal("0.00")
EXPECTED_AGENT_INTEREST = Decimal("5.00")
EXPECTED_PLATFORM_INTEREST = Decimal("5.00")
EXPECTED_AGENT_RECEIVABLE = Decimal("105.00")
EXPECTED_DISBURSEMENT_CHARGE = Decimal("100.00")
EXPECTED_DISBURSEMENT_TRANSFER = Decimal("97.05")
EXPECTED_FULL_REPAYMENT_LEDGER = Decimal("110.00")
EXPECTED_FULL_REPAYMENT_CHARGE = Decimal("110.00")


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
        paystack_recipient_code="RCP_test_agent",
    )


@pytest.fixture
def pending_loan(borrower, agent_profile, borrower_wallet):
    return Loan.objects.create(
        borrower=borrower,
        agent=agent_profile,
        amount=Decimal("100.00"),
        interest_rate=Decimal("10.00"),
        origination_fee=EXPECTED_ORIGINATION_FEE,
        agent_interest_amount=EXPECTED_AGENT_INTEREST,
        platform_interest_amount=EXPECTED_PLATFORM_INTEREST,
        total_repayment=EXPECTED_FULL_REPAYMENT_LEDGER,
        outstanding_balance=EXPECTED_FULL_REPAYMENT_LEDGER,
        agent_receivable_balance=EXPECTED_AGENT_RECEIVABLE,
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
        assert loan.total_repayment == EXPECTED_FULL_REPAYMENT_LEDGER
        assert loan.outstanding_balance == EXPECTED_FULL_REPAYMENT_LEDGER
        assert loan.origination_fee == EXPECTED_ORIGINATION_FEE
        assert loan.platform_interest_amount == EXPECTED_PLATFORM_INTEREST
        assert loan.agent_receivable_balance == EXPECTED_AGENT_RECEIVABLE
        assert Notification.objects.filter(
            user=agent_profile.user,
            kind=NotificationKind.LOAN_REQUEST,
            resource_id=str(loan.pk),
        ).exists()

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

    def test_zero_max_limit_rejects_get_funds(self, borrower, agent_profile, borrower_wallet):
        agent_profile.max_amount = Decimal("0.00")
        agent_profile.save(update_fields=["max_amount"])

        with pytest.raises(ValueError, match="not accepting get-funds"):
            request_loan(
                borrower=borrower,
                agent_profile_id=str(agent_profile.pk),
                amount=Decimal("100.00"),
                wallet_id=str(borrower_wallet.pk),
                network="mtn",
            )

    def test_cannot_loan_from_self(self, agent_user, agent_profile, agent_wallet):
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
        assert payment.amount == Decimal("100.00")
        assert payment.charge_amount == EXPECTED_DISBURSEMENT_CHARGE
        assert payment.transfer_amount == EXPECTED_DISBURSEMENT_TRANSFER
        assert payment.platform_amount == Decimal("0.00")
        assert payment.recipient_code == "RCP_test_borrower"
        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.DISBURSING
        _, kwargs = mock_charge.call_args
        assert kwargs["reference"] == payment.reference
        assert kwargs["amount_pesewas"] == 10000
        assert kwargs["phone"] == agent_wallet.phone_number
        assert kwargs["metadata"]["payer_phone"] == agent_wallet.phone_number
        assert kwargs["metadata"]["payer_network"] == agent_wallet.network
        assert "subaccount_code" not in kwargs

    @override_settings(
        PAYSTACK_SECRET_KEY="sk_test_mocked",
        PAYSTACK_TEST_MOBILE_MONEY_PHONE="0551234987",
    )
    @patch("project.apps.loans.services.paystack.charge_mobile_money")
    def test_uses_test_identity_but_records_agent_wallet(self, mock_charge, pending_loan, agent_wallet):
        mock_charge.return_value = {
            "reference": "DISB_test_override",
            "status": "pay_offline",
        }
        agent_wallet.phone_number = "0209876543"
        agent_wallet.network = "vodafone"
        agent_wallet.save(update_fields=["phone_number", "network", "updated_at"])
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.APPROVED
        pending_loan.save()

        payment = initiate_disbursement(loan=pending_loan)

        assert payment.payer_phone == "0209876543"
        assert payment.payer_network == "vodafone"
        _, kwargs = mock_charge.call_args
        assert kwargs["phone"] == "0551234987"
        assert kwargs["provider"] == "mtn"
        assert kwargs["metadata"]["payer_phone"] == "0209876543"
        assert kwargs["metadata"]["payer_network"] == "vodafone"

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
        assert payment.amount == EXPECTED_FULL_REPAYMENT_LEDGER
        assert payment.charge_amount == EXPECTED_FULL_REPAYMENT_CHARGE
        assert payment.transfer_amount == EXPECTED_AGENT_RECEIVABLE
        assert payment.platform_amount == EXPECTED_PLATFORM_INTEREST
        assert payment.recipient_code == "RCP_test_agent"
        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.REPAYING
        _, kwargs = mock_charge.call_args
        assert kwargs["reference"] == payment.reference
        assert kwargs["amount_pesewas"] == 11000
        assert kwargs["phone"] == pending_loan.borrower_wallet.phone_number
        assert kwargs["metadata"]["payer_phone"] == pending_loan.borrower_wallet.phone_number
        assert kwargs["metadata"]["payer_network"] == pending_loan.borrower_wallet.network
        assert "subaccount_code" not in kwargs

    @patch("project.apps.loans.services.paystack.charge_mobile_money")
    def test_partial_repayment_is_rejected(self, mock_charge, pending_loan, agent_wallet):
        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.ACTIVE
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        with pytest.raises(ValueError, match="Partial repayment is not supported"):
            initiate_repayment(loan=pending_loan, amount=Decimal("55.00"))

        mock_charge.assert_not_called()


@pytest.mark.django_db
class TestWebhookHandlers:
    @patch("project.apps.loans.services.paystack.initiate_transfer")
    def test_charge_success_disbursement_initiates_transfer(self, mock_transfer, pending_loan, agent_wallet):
        mock_transfer.return_value = {
            "reference": "TRF_webhook_test",
            "status": "success",
        }
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            charge_amount=EXPECTED_DISBURSEMENT_CHARGE,
            transfer_amount=EXPECTED_DISBURSEMENT_TRANSFER,
            platform_amount=Decimal("0.00"),
            reference="DISB_webhook_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_charge_success(reference="DISB_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.PENDING
        assert payment.paystack_reference == "TRF_webhook_test"

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.DISBURSING
        assert pending_loan.disbursed_at is None
        mock_transfer.assert_called_once()
        _, kwargs = mock_transfer.call_args
        assert kwargs["amount_pesewas"] == 9705

    @patch("project.apps.loans.services._get_available_balance")
    @patch("project.apps.loans.services.paystack.initiate_transfer")
    def test_charge_success_disbursement_blocks_low_balance(
        self, mock_transfer, mock_balance, pending_loan, agent_wallet
    ):
        mock_balance.return_value = Decimal("98.00")
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            charge_amount=EXPECTED_DISBURSEMENT_CHARGE,
            transfer_amount=EXPECTED_DISBURSEMENT_TRANSFER,
            platform_amount=Decimal("0.00"),
            reference="DISB_balance_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_charge_success(reference="DISB_balance_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.FAILED
        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.FAILED
        mock_transfer.assert_not_called()

    def test_transfer_success_disbursement(self, pending_loan, agent_wallet):
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            charge_amount=EXPECTED_DISBURSEMENT_CHARGE,
            transfer_amount=EXPECTED_DISBURSEMENT_TRANSFER,
            platform_amount=Decimal("0.00"),
            reference="DISB_webhook_test",
            paystack_reference="TRF_webhook_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_transfer_success(reference="TRF_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.SUCCESS

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.ACTIVE
        assert pending_loan.disbursed_at is not None
        assert pending_loan.deadline_at is not None

    @patch("project.apps.loans.services.paystack.initiate_transfer")
    def test_charge_success_repayment_full_initiates_transfer(self, mock_transfer, pending_loan, agent_wallet):
        from django.utils import timezone

        mock_transfer.return_value = {
            "reference": "TRF_repay_webhook_test",
            "status": "success",
        }
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.REPAYING
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.REPAYMENT,
            amount=EXPECTED_FULL_REPAYMENT_LEDGER,
            charge_amount=EXPECTED_FULL_REPAYMENT_CHARGE,
            transfer_amount=EXPECTED_AGENT_RECEIVABLE,
            platform_amount=EXPECTED_PLATFORM_INTEREST,
            reference="REPAY_webhook_test",
            payer_phone="0551234567",
            payer_network="mtn",
        )

        handle_charge_success(reference="REPAY_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.PENDING
        assert payment.paystack_reference == "TRF_repay_webhook_test"

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.REPAYING
        assert pending_loan.outstanding_balance == EXPECTED_FULL_REPAYMENT_LEDGER
        assert pending_loan.agent_receivable_balance == EXPECTED_AGENT_RECEIVABLE
        mock_transfer.assert_called_once()
        _, kwargs = mock_transfer.call_args
        assert kwargs["amount_pesewas"] == 10500

    def test_transfer_success_repayment_full(self, pending_loan, agent_wallet):
        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.REPAYING
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        payment = LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.REPAYMENT,
            amount=EXPECTED_FULL_REPAYMENT_LEDGER,
            charge_amount=EXPECTED_FULL_REPAYMENT_CHARGE,
            transfer_amount=EXPECTED_AGENT_RECEIVABLE,
            platform_amount=EXPECTED_PLATFORM_INTEREST,
            reference="REPAY_webhook_test",
            paystack_reference="TRF_repay_webhook_test",
            payer_phone="0551234567",
            payer_network="mtn",
        )

        handle_transfer_success(reference="TRF_repay_webhook_test", paystack_data={"status": "success"})

        payment.refresh_from_db()
        assert payment.status == PaymentStatus.SUCCESS

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.COMPLETED
        assert pending_loan.outstanding_balance == Decimal("0.00")
        assert pending_loan.agent_receivable_balance == Decimal("0.00")

    def test_charge_failed(self, pending_loan, agent_wallet):
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            charge_amount=EXPECTED_DISBURSEMENT_CHARGE,
            transfer_amount=EXPECTED_DISBURSEMENT_TRANSFER,
            platform_amount=Decimal("0.00"),
            reference="DISB_fail_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_charge_failed(reference="DISB_fail_test", paystack_data={"status": "failed"})

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.FAILED

    def test_transfer_failed(self, pending_loan, agent_wallet):
        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.DISBURSING
        pending_loan.save()

        LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.DISBURSEMENT,
            amount=pending_loan.amount,
            charge_amount=EXPECTED_DISBURSEMENT_CHARGE,
            transfer_amount=EXPECTED_DISBURSEMENT_TRANSFER,
            platform_amount=Decimal("0.00"),
            reference="DISB_fail_test",
            paystack_reference="TRF_fail_test",
            payer_phone="0559876543",
            payer_network="mtn",
        )

        handle_transfer_failed(reference="TRF_fail_test", paystack_data={"status": "failed"})

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.FAILED

    def test_transfer_failed_repayment_keeps_loan_repaying(self, pending_loan, agent_wallet):
        from django.utils import timezone

        pending_loan.agent_wallet = agent_wallet
        pending_loan.status = LoanStatus.REPAYING
        pending_loan.disbursed_at = timezone.now()
        pending_loan.save()

        LoanPayment.objects.create(
            loan=pending_loan,
            payment_type=PaymentType.REPAYMENT,
            amount=EXPECTED_FULL_REPAYMENT_LEDGER,
            charge_amount=EXPECTED_FULL_REPAYMENT_CHARGE,
            transfer_amount=EXPECTED_AGENT_RECEIVABLE,
            platform_amount=EXPECTED_PLATFORM_INTEREST,
            reference="REPAY_fail_test",
            paystack_reference="TRF_repay_fail_test",
            payer_phone="0551234567",
            payer_network="mtn",
        )

        handle_transfer_failed(reference="TRF_repay_fail_test", paystack_data={"status": "failed"})

        pending_loan.refresh_from_db()
        assert pending_loan.status == LoanStatus.REPAYING


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
        assert pending_loan.agent_receivable_balance == Decimal("107.00")

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
