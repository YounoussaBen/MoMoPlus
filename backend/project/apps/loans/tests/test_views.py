import uuid
from decimal import Decimal

import pytest

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
