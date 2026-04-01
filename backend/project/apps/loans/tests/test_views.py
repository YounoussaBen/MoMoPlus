import uuid
from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone

from project.apps.accounts.models import AgentStatus, KycStatus, User, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.loans.models import Loan, LoanStatus
from project.apps.wallets.models import Wallet

BORROWER_SUB = str(uuid.uuid4())
AGENT_SUB = str(uuid.uuid4())


@pytest.fixture
def borrower_claims():
    return {
        "sub": BORROWER_SUB,
        "email": "borrower@example.com",
        "user_metadata": {"first_name": "Ada", "last_name": "Loan"},
    }


@pytest.fixture
def agent_claims():
    return {
        "sub": AGENT_SUB,
        "email": "agent@example.com",
        "user_metadata": {"first_name": "Agent", "last_name": "Smith"},
    }


@pytest.fixture
def borrower_client(auth_client_factory, borrower_claims):
    return auth_client_factory(borrower_claims)


@pytest.fixture
def agent_client(auth_client_factory, agent_claims):
    return auth_client_factory(agent_claims)


def _ensure_borrower() -> User:
    """Get or create the borrower user (created by auth on first request)."""
    user, _ = User.objects.get_or_create(
        email="borrower@example.com",
        defaults={
            "username": "borrower",
            "first_name": "Ada",
            "last_name": "Loan",
            "supabase_user_id": BORROWER_SUB,
            "role": UserRole.USER,
            "kyc_status": KycStatus.APPROVED,
        },
    )
    if user.role != UserRole.USER:
        user.role = UserRole.USER
        user.kyc_status = KycStatus.APPROVED
        user.save()
    return user


def _ensure_agent() -> tuple[User, AgentProfile]:
    """Get or create the agent user and profile."""
    user, _ = User.objects.get_or_create(
        email="agent@example.com",
        defaults={
            "username": "agent",
            "first_name": "Agent",
            "last_name": "Smith",
            "supabase_user_id": AGENT_SUB,
            "role": UserRole.AGENT,
            "agent_status": AgentStatus.APPROVED,
            "kyc_status": KycStatus.APPROVED,
        },
    )
    if user.role != UserRole.AGENT:
        user.role = UserRole.AGENT
        user.agent_status = AgentStatus.APPROVED
        user.kyc_status = KycStatus.APPROVED
        user.save()
    profile, _ = AgentProfile.objects.get_or_create(
        user=user,
        defaults={
            "is_available": True,
            "min_amount": Decimal("10.00"),
            "max_amount": Decimal("500.00"),
            "latitude": Decimal("5.600000"),
            "longitude": Decimal("-0.200000"),
            "agent_type": AgentType.CERTIFIED,
        },
    )
    return user, profile


def _create_completed_loan(
    *,
    borrower: User,
    agent_profile: AgentProfile,
    borrower_wallet: Wallet,
    agent_wallet: Wallet,
    completed_at,
) -> Loan:
    return Loan.objects.create(
        borrower=borrower,
        agent=agent_profile,
        amount=Decimal("100.00"),
        interest_rate=Decimal("10.00"),
        origination_fee=Decimal("0.00"),
        agent_interest_amount=Decimal("5.00"),
        platform_interest_amount=Decimal("5.00"),
        total_repayment=Decimal("110.00"),
        outstanding_balance=Decimal("0.00"),
        agent_receivable_balance=Decimal("0.00"),
        borrower_wallet=borrower_wallet,
        agent_wallet=agent_wallet,
        network="mtn",
        status=LoanStatus.COMPLETED,
        approved_at=completed_at - timedelta(days=7),
        disbursed_at=completed_at - timedelta(days=6),
        deadline_at=completed_at - timedelta(days=1),
        completed_at=completed_at,
    )


@pytest.fixture
def setup_users_and_wallets():
    """Set up borrower + agent with wallets. Call AFTER first authenticated request."""
    borrower = _ensure_borrower()
    agent_user, agent_profile = _ensure_agent()

    b_wallet, _ = Wallet.objects.get_or_create(
        user=borrower,
        phone_number="0551234567",
        defaults={
            "network": "mtn",
            "is_verified": True,
            "is_default": True,
            "paystack_recipient_code": "RCP_test_borrower",
        },
    )
    a_wallet, _ = Wallet.objects.get_or_create(
        user=agent_user,
        phone_number="0559876543",
        defaults={
            "network": "mtn",
            "is_verified": True,
            "is_default": True,
            "paystack_recipient_code": "RCP_test_agent",
        },
    )
    return borrower, agent_user, agent_profile, b_wallet, a_wallet


@pytest.mark.django_db
class TestLoanRequestEndpoint:
    def test_request_loan(self, borrower_client, agent_client):
        # Trigger auth to create both users
        borrower_client.get("/api/wallets/")
        agent_client.get("/api/wallets/")

        borrower, _, agent_profile, b_wallet, _ = (
            _ensure_borrower(),
            *_ensure_agent(),
            None,
            None,
        )
        # Actually set up wallets properly
        borrower = _ensure_borrower()
        _, agent_profile = _ensure_agent()
        b_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )

        resp = borrower_client.post(
            "/api/loans/request/",
            {
                "agent_id": str(agent_profile.pk),
                "amount": "100.00",
                "wallet_id": str(b_wallet.pk),
                "network": "mtn",
            },
            format="json",
        )
        assert resp.status_code == 201
        data = resp.json()
        assert data["status"] == "pending"
        assert data["amount"] == "100.00"
        assert data["origination_fee"] == "0.00"
        assert data["platform_interest_amount"] == "5.00"
        assert data["total_repayment"] == "110.00"

    def test_request_loan_invalid_amount(self, borrower_client, agent_client):
        borrower_client.get("/api/wallets/")
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        _, agent_profile = _ensure_agent()
        b_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )

        resp = borrower_client.post(
            "/api/loans/request/",
            {
                "agent_id": str(agent_profile.pk),
                "amount": "5000.00",
                "wallet_id": str(b_wallet.pk),
                "network": "mtn",
            },
            format="json",
        )
        assert resp.status_code == 400


@pytest.mark.django_db
class TestLoanListEndpoint:
    def test_borrower_list(self, borrower_client, agent_client):
        borrower_client.get("/api/wallets/")
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        _, agent_profile = _ensure_agent()
        b_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )
        Loan.objects.create(
            borrower=borrower,
            agent=agent_profile,
            amount=Decimal("50.00"),
            interest_rate=Decimal("10.00"),
            origination_fee=Decimal("0.00"),
            agent_interest_amount=Decimal("2.50"),
            platform_interest_amount=Decimal("2.50"),
            total_repayment=Decimal("55.00"),
            outstanding_balance=Decimal("55.00"),
            agent_receivable_balance=Decimal("52.50"),
            borrower_wallet=b_wallet,
            network="mtn",
            status=LoanStatus.PENDING,
        )
        resp = borrower_client.get("/api/loans/")
        assert resp.status_code == 200
        assert len(resp.json()) >= 1


@pytest.mark.django_db
class TestLoanAcceptEndpoint:
    def test_accept(self, borrower_client, agent_client):
        borrower_client.get("/api/wallets/")
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        agent_user, agent_profile = _ensure_agent()
        b_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )
        a_wallet, _ = Wallet.objects.get_or_create(
            user=agent_user,
            phone_number="0559876543",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_agent",
            },
        )
        loan = Loan.objects.create(
            borrower=borrower,
            agent=agent_profile,
            amount=Decimal("100.00"),
            interest_rate=Decimal("10.00"),
            origination_fee=Decimal("0.00"),
            agent_interest_amount=Decimal("5.00"),
            platform_interest_amount=Decimal("5.00"),
            total_repayment=Decimal("110.00"),
            outstanding_balance=Decimal("110.00"),
            agent_receivable_balance=Decimal("105.00"),
            borrower_wallet=b_wallet,
            network="mtn",
            status=LoanStatus.PENDING,
        )
        resp = agent_client.post(
            f"/api/loans/{loan.pk}/accept/",
            {"agent_wallet_id": str(a_wallet.pk)},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "approved"


@pytest.mark.django_db
class TestLoanRejectEndpoint:
    def test_reject(self, borrower_client, agent_client):
        borrower_client.get("/api/wallets/")
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        _, agent_profile = _ensure_agent()
        b_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )
        loan = Loan.objects.create(
            borrower=borrower,
            agent=agent_profile,
            amount=Decimal("100.00"),
            interest_rate=Decimal("10.00"),
            origination_fee=Decimal("0.00"),
            agent_interest_amount=Decimal("5.00"),
            platform_interest_amount=Decimal("5.00"),
            total_repayment=Decimal("110.00"),
            outstanding_balance=Decimal("110.00"),
            agent_receivable_balance=Decimal("105.00"),
            borrower_wallet=b_wallet,
            network="mtn",
            status=LoanStatus.PENDING,
        )
        resp = agent_client.post(
            f"/api/loans/{loan.pk}/reject/",
            {"reason": "No funds available"},
            format="json",
        )
        assert resp.status_code == 200
        assert resp.json()["status"] == "rejected"


@pytest.mark.django_db
class TestAgentEarningsEndpoint:
    def test_period_filter_limits_recent_earnings(self, agent_client):
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        agent_user, agent_profile = _ensure_agent()
        now = timezone.now()

        borrower_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )
        agent_wallet, _ = Wallet.objects.get_or_create(
            user=agent_user,
            phone_number="0559876543",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_agent",
            },
        )

        # "week" means current calendar week starting Monday, so place
        # week_loan on Monday of this week and old_loan well before it.
        today_loan = _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=now - timedelta(hours=2),
        )
        # Place on Monday of the current week (always within the week filter)
        monday = now - timedelta(days=now.weekday())
        week_loan = _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=monday.replace(hour=6, minute=0, second=0),
        )
        _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=now - timedelta(days=35),
        )

        response = agent_client.get("/api/loans/earnings/", {"period": "week"})

        assert response.status_code == 200
        assert response.data["total_loans_completed"] == 3
        returned_ids = {item["id"] for item in response.data["recent_earnings"]}
        assert returned_ids == {str(today_loan.pk), str(week_loan.pk)}

    def test_custom_range_limits_recent_earnings(self, agent_client):
        agent_client.get("/api/wallets/")

        borrower = _ensure_borrower()
        agent_user, agent_profile = _ensure_agent()
        now = timezone.now()

        borrower_wallet, _ = Wallet.objects.get_or_create(
            user=borrower,
            phone_number="0551234567",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_borrower",
            },
        )
        agent_wallet, _ = Wallet.objects.get_or_create(
            user=agent_user,
            phone_number="0559876543",
            defaults={
                "network": "mtn",
                "is_verified": True,
                "is_default": True,
                "paystack_recipient_code": "RCP_test_agent",
            },
        )

        inside_start = _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=now - timedelta(days=9),
        )
        inside_end = _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=now - timedelta(days=6),
        )
        _create_completed_loan(
            borrower=borrower,
            agent_profile=agent_profile,
            borrower_wallet=borrower_wallet,
            agent_wallet=agent_wallet,
            completed_at=now - timedelta(days=2),
        )

        response = agent_client.get(
            "/api/loans/earnings/",
            {
                "period": "custom",
                "start_date": (now - timedelta(days=10)).date().isoformat(),
                "end_date": (now - timedelta(days=5)).date().isoformat(),
            },
        )

        assert response.status_code == 200
        assert response.data["total_loans_completed"] == 3
        returned_ids = {item["id"] for item in response.data["recent_earnings"]}
        assert returned_ids == {str(inside_start.pk), str(inside_end.pk)}

    def test_custom_range_requires_start_and_end_date(self, agent_client):
        agent_client.get("/api/wallets/")
        _ensure_agent()

        response = agent_client.get("/api/loans/earnings/", {"period": "custom"})

        assert response.status_code == 400
        assert response.data["detail"] == "Custom period requires start_date and end_date."

    def test_invalid_period_is_rejected(self, agent_client):
        agent_client.get("/api/wallets/")
        _ensure_agent()

        response = agent_client.get("/api/loans/earnings/", {"period": "year"})

        assert response.status_code == 400
        assert response.data["detail"] == "Invalid period. Use today, week, month, or custom."
