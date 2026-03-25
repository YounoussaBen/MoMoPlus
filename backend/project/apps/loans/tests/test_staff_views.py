from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework import status

from project.apps.accounts.models import AgentStatus, KycStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.loans.models import Loan, LoanPayment, LoanStatus, PaymentStatus, PaymentType
from project.apps.wallets.models import Wallet


@pytest.fixture
def staff_client(api_client, user_factory):
    staff = user_factory(
        email="loans-admin@example.com",
        username="loans-admin",
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


@pytest.fixture
def borrower(user_factory):
    return user_factory(
        email="borrower-staff@example.com",
        username="borrower-staff",
        first_name="Ada",
        last_name="Borrower",
        role=UserRole.USER,
        kyc_status=KycStatus.APPROVED,
    )


@pytest.fixture
def agent_user(user_factory):
    return user_factory(
        email="agent-staff@example.com",
        username="agent-staff",
        first_name="Kojo",
        last_name="Agent",
        role=UserRole.AGENT,
        agent_status=AgentStatus.APPROVED,
        kyc_status=KycStatus.APPROVED,
    )


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
        paystack_recipient_code="RCP_staff_borrower",
    )


@pytest.fixture
def agent_wallet(agent_user):
    return Wallet.objects.create(
        user=agent_user,
        phone_number="0557654321",
        network="telecel",
        is_verified=True,
        is_default=True,
        paystack_recipient_code="RCP_staff_agent",
    )


def _make_loan(
    *,
    borrower,
    agent_profile,
    borrower_wallet,
    agent_wallet=None,
    status_value=LoanStatus.PENDING,
    amount=Decimal("100.00"),
    deadline_at=None,
):
    return Loan.objects.create(
        borrower=borrower,
        agent=agent_profile,
        amount=amount,
        interest_rate=Decimal("10.00"),
        origination_fee=Decimal("0.00"),
        agent_interest_amount=Decimal("5.00"),
        platform_interest_amount=Decimal("5.00"),
        total_repayment=Decimal("110.00"),
        outstanding_balance=Decimal("110.00"),
        agent_receivable_balance=Decimal("105.00"),
        borrower_wallet=borrower_wallet,
        agent_wallet=agent_wallet,
        network="mtn",
        status=status_value,
        approved_at=timezone.now() if status_value != LoanStatus.PENDING else None,
        deadline_at=deadline_at,
    )


@pytest.mark.django_db
class TestStaffLoanList:
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/staff/loans/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_non_staff_is_forbidden(self, authenticated_client):
        response = authenticated_client.get("/api/staff/loans/")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_returns_paginated_list(self, staff_client, borrower, agent_profile, borrower_wallet, agent_wallet):
        client, _ = staff_client
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
        )

        response = client.get("/api/staff/loans/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        first = response.data["results"][0]
        assert first["borrower_name"] == "Ada Borrower"
        assert first["agent_name"] == "Kojo Agent"
        assert first["status"] == LoanStatus.PENDING
        assert first["is_overdue"] is False

    def test_filters_by_status(self, staff_client, borrower, agent_profile, borrower_wallet, agent_wallet):
        client, _ = staff_client
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            status_value=LoanStatus.PENDING,
        )
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            status_value=LoanStatus.ACTIVE,
            deadline_at=timezone.now() + timedelta(hours=12),
        )

        response = client.get("/api/staff/loans/", {"status": LoanStatus.ACTIVE})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["status"] == LoanStatus.ACTIVE

    def test_searches_borrower_and_agent_fields(
        self, staff_client, borrower, agent_profile, borrower_wallet, agent_wallet
    ):
        client, _ = staff_client
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
        )

        response = client.get("/api/staff/loans/", {"search": "borrower-staff"})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["borrower_email"] == borrower.email

    def test_filters_overdue_loans(self, staff_client, borrower, agent_profile, borrower_wallet, agent_wallet):
        client, _ = staff_client
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            status_value=LoanStatus.ACTIVE,
            deadline_at=timezone.now() - timedelta(hours=3),
        )
        _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            status_value=LoanStatus.ACTIVE,
            amount=Decimal("150.00"),
            deadline_at=timezone.now() + timedelta(hours=3),
        )

        response = client.get("/api/staff/loans/", {"is_overdue": "true"})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["is_overdue"] is True


@pytest.mark.django_db
class TestStaffLoanDetail:
    def test_returns_detail_with_payments(self, staff_client, borrower, agent_profile, borrower_wallet, agent_wallet):
        client, _ = staff_client
        loan = _make_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            status_value=LoanStatus.ACTIVE,
            deadline_at=timezone.now() + timedelta(hours=24),
        )
        LoanPayment.objects.create(
            loan=loan,
            amount=Decimal("110.00"),
            charge_amount=Decimal("110.00"),
            transfer_amount=Decimal("105.00"),
            platform_amount=Decimal("5.00"),
            payment_type=PaymentType.REPAYMENT,
            status=PaymentStatus.SUCCESS,
            reference="REPAY_staff_test",
            paystack_reference="TRF_staff_test",
            payer_phone="0551234567",
            payer_network="mtn",
            recipient_code="RCP_staff_agent",
            completed_at=timezone.now(),
        )

        response = client.get(f"/api/staff/loans/{loan.id}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["id"] == str(loan.id)
        assert response.data["borrower_email"] == borrower.email
        assert response.data["agent_email"] == agent_profile.user.email
        assert len(response.data["payments"]) == 1
        assert response.data["payments"][0]["status"] == PaymentStatus.SUCCESS

    def test_returns_404_for_missing_loan(self, staff_client):
        client, _ = staff_client
        response = client.get("/api/staff/loans/00000000-0000-0000-0000-000000000000/")
        assert response.status_code == status.HTTP_404_NOT_FOUND
