from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework import status

from project.apps.accounts.models import AgentStatus, KycStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType, CertificationApplication, CertificationStatus
from project.apps.kyc.models import KycSubmission
from project.apps.loans.models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType
from project.apps.transactions.models import PhysicalTransaction, TransactionStatus, TransactionType
from project.apps.wallets.models import Wallet


@pytest.fixture
def staff_client(api_client, user_factory):
    staff = user_factory(
        email="dashboard-admin@example.com",
        username="dashboard-admin",
        password="adminpass123",
        is_staff=True,
        is_superuser=True,
        supabase_user_id=None,
    )
    response = api_client.post(
        "/api/auth/staff/login/",
        {"email": staff.email, "password": "adminpass123"},
        format="json",
    )
    api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {response.data['access']}")
    return api_client, staff


def _set_created_at(instance, value):
    instance.__class__.objects.filter(pk=instance.pk).update(created_at=value, updated_at=value)
    instance.refresh_from_db()
    return instance


@pytest.mark.django_db
class TestStaffDashboardOverview:
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/staff/dashboard/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_non_staff_is_forbidden(self, authenticated_client):
        response = authenticated_client.get("/api/staff/dashboard/")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_returns_dashboard_metrics_and_chart_series(self, staff_client, user_factory):
        client, _ = staff_client
        now = timezone.now()
        current_day = now - timedelta(days=1)
        previous_day = now - timedelta(days=12)

        borrower = user_factory(
            email="dashboard-borrower@example.com",
            username="dashboard-borrower",
            first_name="Ama",
            last_name="Borrower",
            role=UserRole.USER,
            kyc_status=KycStatus.APPROVED,
        )
        _set_created_at(borrower, current_day)

        agent_user = user_factory(
            email="dashboard-agent@example.com",
            username="dashboard-agent",
            first_name="Kojo",
            last_name="Agent",
            role=UserRole.AGENT,
            agent_status=AgentStatus.APPROVED,
            kyc_status=KycStatus.APPROVED,
        )
        _set_created_at(agent_user, current_day)

        applicant_user = user_factory(
            email="dashboard-applicant@example.com",
            username="dashboard-applicant",
            first_name="Yaw",
            last_name="Applicant",
            role=UserRole.USER,
            agent_status=AgentStatus.PENDING,
        )
        _set_created_at(applicant_user, previous_day)

        agent_profile = AgentProfile.objects.create(
            user=agent_user,
            latitude=Decimal("5.603700"),
            longitude=Decimal("-0.187000"),
            is_available=True,
            min_amount=Decimal("10.00"),
            max_amount=Decimal("1000.00"),
            agent_type=AgentType.CERTIFIED,
        )
        _set_created_at(agent_profile, current_day)

        certification = CertificationApplication.objects.create(
            agent_profile=agent_profile,
            agent_id_number="AGENT-123",
            network="mtn",
            status=CertificationStatus.PENDING,
        )
        _set_created_at(certification, current_day)

        borrower_wallet = Wallet.objects.create(
            user=borrower,
            phone_number="0551234567",
            network=Wallet.Network.MTN,
            is_verified=True,
            is_default=True,
            paystack_recipient_code="RCP_dashboard_borrower",
        )
        _set_created_at(borrower_wallet, current_day)

        agent_wallet = Wallet.objects.create(
            user=agent_user,
            phone_number="0559876543",
            network=Wallet.Network.VODAFONE,
            is_verified=True,
            is_default=True,
            paystack_recipient_code="RCP_dashboard_agent",
        )
        _set_created_at(agent_wallet, current_day)

        kyc_submission = KycSubmission.objects.create(
            user=borrower,
            status=KycSubmission.Status.PENDING,
            id_type=KycSubmission.IdType.NATIONAL_ID,
        )
        _set_created_at(kyc_submission, current_day)

        loan = Loan.objects.create(
            borrower=borrower,
            agent=agent_profile,
            amount=Decimal("300.00"),
            interest_rate=Decimal("10.00"),
            origination_fee=Decimal("0.00"),
            agent_interest_amount=Decimal("15.00"),
            platform_interest_amount=Decimal("15.00"),
            total_repayment=Decimal("330.00"),
            outstanding_balance=Decimal("330.00"),
            agent_receivable_balance=Decimal("315.00"),
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            network=Wallet.Network.MTN,
            status=LoanStatus.ACTIVE,
            approved_at=now - timedelta(days=2),
            deadline_at=now - timedelta(hours=4),
        )
        _set_created_at(loan, current_day)

        disbursement = LoanPayment.objects.create(
            loan=loan,
            amount=Decimal("300.00"),
            charge_amount=Decimal("300.00"),
            transfer_amount=Decimal("285.00"),
            platform_amount=Decimal("15.00"),
            payment_type=PaymentType.DISBURSEMENT,
            status=PaymentStatus.SUCCESS,
            reference="DISBURSE_dashboard",
            paystack_reference="TRF_dashboard_disburse",
            payer_phone=agent_wallet.phone_number,
            payer_network=agent_wallet.network,
            recipient_code=borrower_wallet.paystack_recipient_code,
            completed_at=now - timedelta(days=1),
        )
        _set_created_at(disbursement, current_day)

        repayment = LoanPayment.objects.create(
            loan=loan,
            amount=Decimal("120.00"),
            charge_amount=Decimal("120.00"),
            transfer_amount=Decimal("114.00"),
            platform_amount=Decimal("6.00"),
            payment_type=PaymentType.REPAYMENT,
            status=PaymentStatus.SUCCESS,
            reference="REPAY_dashboard",
            paystack_reference="TRF_dashboard_repay",
            payer_phone=borrower_wallet.phone_number,
            payer_network=borrower_wallet.network,
            recipient_code=agent_wallet.paystack_recipient_code,
            completed_at=now - timedelta(days=1),
        )
        _set_created_at(repayment, current_day)

        cash_service = PhysicalTransaction.objects.create(
            user=borrower,
            agent=agent_profile,
            transaction_type=TransactionType.DEPOSIT,
            amount=Decimal("200.00"),
            network=Wallet.Network.VODAFONE,
            wallet=borrower_wallet,
            status=TransactionStatus.ACCEPTED,
            verification_code="654321",
            meeting_latitude=Decimal("5.610000"),
            meeting_longitude=Decimal("-0.190000"),
            meeting_description="By the station",
            expires_at=now + timedelta(hours=2),
        )
        _set_created_at(cash_service, current_day)

        completed_cash_service = PhysicalTransaction.objects.create(
            user=borrower,
            agent=agent_profile,
            transaction_type=TransactionType.CASH_OUT,
            amount=Decimal("150.00"),
            network=Wallet.Network.MTN,
            wallet=borrower_wallet,
            status=TransactionStatus.COMPLETED,
            verification_code="987654",
            completed_at=now - timedelta(days=1),
            expires_at=now + timedelta(hours=1),
        )
        _set_created_at(completed_cash_service, current_day)

        response = client.get("/api/staff/dashboard/", {"days": 14})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["range_days"] == 14
        assert response.data["summary"]["total_users"] == 3
        assert response.data["summary"]["approved_agents"] == 1
        assert response.data["summary"]["pending_kyc_reviews"] == 1
        assert response.data["summary"]["pending_agent_reviews"] == 1
        assert response.data["summary"]["open_get_funds_cases"] == 1
        assert response.data["summary"]["overdue_get_funds_cases"] == 1
        assert response.data["summary"]["open_cash_services"] == 1
        assert response.data["summary"]["scheduled_cash_meetings"] == 1

        assert response.data["period"]["new_users"] == 3
        assert response.data["period"]["new_agents"] == 1
        assert response.data["period"]["new_kyc_submissions"] == 1
        assert response.data["period"]["new_get_funds_cases"] == 1
        assert response.data["period"]["new_cash_services"] == 2
        assert response.data["period"]["loan_disbursement_volume"] == "300.00"
        assert response.data["period"]["loan_repayment_volume"] == "120.00"
        assert response.data["period"]["cash_in_volume"] == "0.00"
        assert response.data["period"]["cash_out_volume"] == "150.00"

        assert len(response.data["charts"]["activity"]) == 14
        assert len(response.data["charts"]["money_flow"]) == 14

        kyc_breakdown = {item["key"]: item["value"] for item in response.data["charts"]["kyc_status_breakdown"]}
        loan_breakdown = {item["key"]: item["value"] for item in response.data["charts"]["loan_status_breakdown"]}
        cash_breakdown = {
            item["key"]: item["value"] for item in response.data["charts"]["cash_service_status_breakdown"]
        }
        network_breakdown = {item["key"]: item["value"] for item in response.data["charts"]["network_breakdown"]}

        assert kyc_breakdown["pending"] == 1
        assert loan_breakdown["active"] == 1
        assert cash_breakdown["accepted"] == 1
        assert cash_breakdown["completed"] == 1
        assert network_breakdown["mtn"] == 2
        assert network_breakdown["vodafone"] == 1

    def test_invalid_days_falls_back_to_default_window(self, staff_client):
        client, _ = staff_client

        response = client.get("/api/staff/dashboard/", {"days": 999})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["range_days"] == 30
