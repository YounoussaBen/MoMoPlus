from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from rest_framework import status

from project.apps.accounts.models import AgentStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.transactions.models import PhysicalTransaction, TransactionStatus, TransactionType
from project.apps.wallets.models import Wallet


@pytest.fixture
def staff_client(api_client, user_factory):
    staff = user_factory(
        email="transactions-admin@example.com",
        username="transactions-admin",
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
        email="cash-user@example.com",
        username="cash-user",
        first_name="Ama",
        last_name="Customer",
        phone="+233241234567",
        role=UserRole.USER,
    )


@pytest.fixture
def agent_user(user_factory):
    return user_factory(
        email="cash-agent@example.com",
        username="cash-agent",
        first_name="Yaw",
        last_name="Operator",
        phone="+233551234567",
        role=UserRole.AGENT,
        agent_status=AgentStatus.APPROVED,
    )


@pytest.fixture
def agent_profile(agent_user):
    return AgentProfile.objects.create(
        user=agent_user,
        latitude=Decimal("5.603700"),
        longitude=Decimal("-0.187000"),
        is_available=True,
        min_amount=Decimal("10.00"),
        max_amount=Decimal("500.00"),
        agent_type=AgentType.CERTIFIED,
    )


@pytest.fixture
def wallet(borrower):
    return Wallet.objects.create(
        user=borrower,
        phone_number="0241234567",
        network="mtn",
        is_verified=True,
        is_default=True,
    )


def _make_transaction(
    *,
    borrower,
    agent_profile,
    wallet,
    status_value=TransactionStatus.PENDING,
    transaction_type=TransactionType.CASH_OUT,
    amount=Decimal("100.00"),
    with_meeting=False,
):
    kwargs = {}
    if with_meeting:
        kwargs = {
            "meeting_latitude": Decimal("5.610000"),
            "meeting_longitude": Decimal("-0.190000"),
            "meeting_description": "By the roundabout",
        }

    return PhysicalTransaction.objects.create(
        user=borrower,
        agent=agent_profile,
        transaction_type=transaction_type,
        amount=amount,
        network="mtn",
        wallet=wallet,
        status=status_value,
        verification_code="123456",
        expires_at=timezone.now() + timedelta(hours=1),
        **kwargs,
    )


@pytest.mark.django_db
class TestStaffPhysicalTransactionList:
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/staff/transactions/physical/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_non_staff_is_forbidden(self, authenticated_client):
        response = authenticated_client.get("/api/staff/transactions/physical/")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    def test_returns_paginated_list(self, staff_client, borrower, agent_profile, wallet):
        client, _ = staff_client
        _make_transaction(borrower=borrower, agent_profile=agent_profile, wallet=wallet)

        response = client.get("/api/staff/transactions/physical/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        first = response.data["results"][0]
        assert first["user_name"] == "Ama Customer"
        assert first["agent_name"] == "Yaw Operator"
        assert first["status"] == TransactionStatus.PENDING
        assert first["has_meeting"] is False

    def test_filters_by_status(self, staff_client, borrower, agent_profile, wallet):
        client, _ = staff_client
        _make_transaction(
            borrower=borrower,
            agent_profile=agent_profile,
            wallet=wallet,
            status_value=TransactionStatus.PENDING,
        )
        _make_transaction(
            borrower=borrower,
            agent_profile=agent_profile,
            wallet=wallet,
            status_value=TransactionStatus.ACCEPTED,
            with_meeting=True,
        )

        response = client.get("/api/staff/transactions/physical/", {"status": TransactionStatus.ACCEPTED})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["status"] == TransactionStatus.ACCEPTED

    def test_searches_user_and_agent_fields(self, staff_client, borrower, agent_profile, wallet):
        client, _ = staff_client
        _make_transaction(borrower=borrower, agent_profile=agent_profile, wallet=wallet)

        response = client.get("/api/staff/transactions/physical/", {"search": "241234567"})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["user_phone"] == borrower.phone

    def test_filters_transactions_with_meetings(self, staff_client, borrower, agent_profile, wallet):
        client, _ = staff_client
        _make_transaction(borrower=borrower, agent_profile=agent_profile, wallet=wallet, with_meeting=False)
        _make_transaction(
            borrower=borrower,
            agent_profile=agent_profile,
            wallet=wallet,
            amount=Decimal("120.00"),
            status_value=TransactionStatus.ACCEPTED,
            with_meeting=True,
        )

        response = client.get("/api/staff/transactions/physical/", {"has_meeting": "true"})

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["has_meeting"] is True


@pytest.mark.django_db
class TestStaffPhysicalTransactionDetail:
    def test_returns_transaction_detail(self, staff_client, borrower, agent_profile, wallet):
        client, _ = staff_client
        transaction = _make_transaction(
            borrower=borrower,
            agent_profile=agent_profile,
            wallet=wallet,
            status_value=TransactionStatus.ACCEPTED,
            with_meeting=True,
        )

        response = client.get(f"/api/staff/transactions/physical/{transaction.id}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["id"] == str(transaction.id)
        assert response.data["verification_code"] == "123456"
        assert response.data["wallet_phone_number"] == wallet.phone_number
        assert response.data["meeting_description"] == "By the roundabout"

    def test_returns_404_for_missing_transaction(self, staff_client):
        client, _ = staff_client
        response = client.get("/api/staff/transactions/physical/00000000-0000-0000-0000-000000000000/")
        assert response.status_code == status.HTTP_404_NOT_FOUND
