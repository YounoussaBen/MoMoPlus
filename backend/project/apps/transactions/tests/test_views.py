import uuid
from decimal import Decimal

import pytest
from django.urls import reverse

from project.apps.accounts.models import AgentStatus, UserRole
from project.apps.agents.models import AgentProfile, AgentType
from project.apps.wallets.models import Wallet


@pytest.fixture
def agent_claims():
    return {
        "sub": str(uuid.uuid4()),
        "email": "agent-view@example.com",
        "user_metadata": {"first_name": "Agent", "last_name": "Smith"},
    }


@pytest.fixture
def user_claims():
    return {
        "sub": str(uuid.uuid4()),
        "email": "user-view@example.com",
        "user_metadata": {"first_name": "User", "last_name": "Doe"},
    }


@pytest.fixture
def agent_api_client(auth_client_factory, agent_claims):
    return auth_client_factory(agent_claims)


@pytest.fixture
def user_api_client(auth_client_factory, user_claims):
    return auth_client_factory(user_claims)


def _setup_agent(agent_claims):
    """Create agent user + profile after sync."""
    from django.contrib.auth import get_user_model

    User = get_user_model()
    user = User.objects.get(email=agent_claims["email"])
    user.role = UserRole.AGENT
    user.agent_status = AgentStatus.APPROVED
    user.save(update_fields=["role", "agent_status"])
    return AgentProfile.objects.create(
        user=user,
        latitude=Decimal("5.6037"),
        longitude=Decimal("-0.1870"),
        is_available=True,
        min_amount=Decimal("10.00"),
        max_amount=Decimal("500.00"),
        agent_type=AgentType.CERTIFIED,
    )


def _setup_wallet(user_claims):
    """Create verified wallet for user after sync."""
    from django.contrib.auth import get_user_model

    User = get_user_model()
    user = User.objects.get(email=user_claims["email"])
    return Wallet.objects.create(
        user=user,
        phone_number="0241234567",
        network="mtn",
        is_verified=True,
        is_default=True,
    )


@pytest.mark.django_db
class TestCreateTransactionView:
    def test_create_success(self, user_api_client, agent_api_client, agent_claims, user_claims):
        # Trigger sync for both
        user_api_client.get(reverse("transaction-list"))
        agent_api_client.get(reverse("transaction-list"))

        agent_profile = _setup_agent(agent_claims)
        wallet = _setup_wallet(user_claims)

        response = user_api_client.post(
            reverse("transaction-create"),
            {
                "agent_id": str(agent_profile.pk),
                "transaction_type": "cash_out",
                "amount": "100.00",
                "network": "mtn",
                "wallet_id": str(wallet.pk),
            },
            format="json",
        )
        assert response.status_code == 201
        data = response.json()
        assert data["status"] == "pending"
        assert data["amount"] == "100.00"
        assert data["transaction_type"] == "cash_out"
        assert data["verification_code"] == ""

    def test_create_agent_unavailable(self, user_api_client, agent_api_client, agent_claims, user_claims):
        user_api_client.get(reverse("transaction-list"))
        agent_api_client.get(reverse("transaction-list"))

        agent_profile = _setup_agent(agent_claims)
        agent_profile.is_available = False
        agent_profile.save(update_fields=["is_available"])
        wallet = _setup_wallet(user_claims)

        response = user_api_client.post(
            reverse("transaction-create"),
            {
                "agent_id": str(agent_profile.pk),
                "transaction_type": "cash_out",
                "amount": "100.00",
                "network": "mtn",
                "wallet_id": str(wallet.pk),
            },
            format="json",
        )
        assert response.status_code == 400
        assert "no longer available" in response.json()["detail"]


@pytest.mark.django_db
class TestTransactionLifecycleView:
    def _create_txn(self, user_client, agent_client, agent_claims, user_claims):
        """Helper to create a transaction through the API."""
        user_client.get(reverse("transaction-list"))
        agent_client.get(reverse("transaction-list"))
        agent_profile = _setup_agent(agent_claims)
        wallet = _setup_wallet(user_claims)

        response = user_client.post(
            reverse("transaction-create"),
            {
                "agent_id": str(agent_profile.pk),
                "transaction_type": "cash_out",
                "amount": "100.00",
                "network": "mtn",
                "wallet_id": str(wallet.pk),
            },
            format="json",
        )
        return response.json()

    def test_full_lifecycle(self, user_api_client, agent_api_client, agent_claims, user_claims):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]

        # Agent accepts
        response = agent_api_client.post(
            reverse("transaction-accept", args=[txn_id]),
            {
                "meeting_latitude": "5.6100",
                "meeting_longitude": "-0.1900",
                "meeting_description": "By the roundabout",
            },
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["status"] == "accepted"
        assert response.json()["meeting_description"] == "By the roundabout"

        # The code is only visible to the user, never in the agent payload.
        user_detail = user_api_client.get(reverse("transaction-detail", args=[txn_id])).json()
        code = user_detail["verification_code"]
        assert len(code) == 6
        agent_detail = agent_api_client.get(reverse("transaction-detail", args=[txn_id])).json()
        assert agent_detail["verification_code"] == ""

        # Agent enters the user's code before starting cash service.
        response = agent_api_client.post(
            reverse("transaction-confirm", args=[txn_id]),
            {"verification_code": code},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["agent_confirmed"] is True
        assert response.json()["status"] == "accepted"

        # User confirms the cash handoff → completed.
        response = user_api_client.post(
            reverse("transaction-confirm", args=[txn_id]),
            {},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["status"] == "completed"
        assert response.json()["user_confirmed"] is True
        assert response.json()["completed_at"] is not None

    def test_wrong_code_is_rejected(
        self,
        user_api_client,
        agent_api_client,
        agent_claims,
        user_claims,
    ):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]
        agent_api_client.post(
            reverse("transaction-accept", args=[txn_id]),
            {
                "meeting_latitude": "5.6100",
                "meeting_longitude": "-0.1900",
            },
            format="json",
        )
        code = user_api_client.get(reverse("transaction-detail", args=[txn_id])).json()["verification_code"]
        wrong_code = "000001" if code == "000000" else "000000"

        response = agent_api_client.post(
            reverse("transaction-confirm", args=[txn_id]),
            {"verification_code": wrong_code},
            format="json",
        )
        assert response.status_code == 400
        assert response.json()["detail"] == ("The code is incorrect. 4 attempts remaining.")

    def test_accept_allows_high_precision_coordinates(
        self,
        user_api_client,
        agent_api_client,
        agent_claims,
        user_claims,
    ):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]

        response = agent_api_client.post(
            reverse("transaction-accept", args=[txn_id]),
            {
                "meeting_latitude": "5.610012345678",
                "meeting_longitude": "-0.190098765432",
                "meeting_description": "By the roundabout",
            },
            format="json",
        )

        assert response.status_code == 200
        assert response.json()["status"] == "accepted"
        assert response.json()["meeting_latitude"] == "5.610012"
        assert response.json()["meeting_longitude"] == "-0.190099"

    def test_reject(self, user_api_client, agent_api_client, agent_claims, user_claims):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]

        response = agent_api_client.post(
            reverse("transaction-reject", args=[txn_id]),
            {"reason": "Too far"},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["status"] == "rejected"

    def test_cancel(self, user_api_client, agent_api_client, agent_claims, user_claims):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]

        response = user_api_client.post(
            reverse("transaction-cancel", args=[txn_id]),
            {"reason": "Changed my mind"},
            format="json",
        )
        assert response.status_code == 200
        assert response.json()["status"] == "cancelled"

    def test_list_transactions(self, user_api_client, agent_api_client, agent_claims, user_claims):
        self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)

        # User sees their transactions
        response = user_api_client.get(reverse("transaction-list"))
        assert response.status_code == 200
        assert len(response.json()) == 1

    def test_detail(self, user_api_client, agent_api_client, agent_claims, user_claims):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)

        response = user_api_client.get(reverse("transaction-detail", args=[data["id"]]))
        assert response.status_code == 200
        assert response.json()["id"] == data["id"]

    def test_user_can_rate_completed_cash_service(
        self,
        user_api_client,
        agent_api_client,
        agent_claims,
        user_claims,
    ):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)
        txn_id = data["id"]

        agent_api_client.post(
            reverse("transaction-accept", args=[txn_id]),
            {"meeting_latitude": "5.6100", "meeting_longitude": "-0.1900"},
            format="json",
        )
        code = user_api_client.get(reverse("transaction-detail", args=[txn_id])).json()["verification_code"]
        agent_api_client.post(
            reverse("transaction-confirm", args=[txn_id]),
            {"verification_code": code},
            format="json",
        )
        user_api_client.post(reverse("transaction-confirm", args=[txn_id]), {}, format="json")

        response = user_api_client.post(
            reverse("transaction-rate", args=[txn_id]),
            {"rating": 5},
            format="json",
        )

        assert response.status_code == 200
        assert response.json()["my_rating"] == 5

    def test_agent_cannot_rate_a_cash_service(
        self,
        user_api_client,
        agent_api_client,
        agent_claims,
        user_claims,
    ):
        data = self._create_txn(user_api_client, agent_api_client, agent_claims, user_claims)

        response = agent_api_client.post(
            reverse("transaction-rate", args=[data["id"]]),
            {"rating": 5},
            format="json",
        )

        assert response.status_code == 400
        assert "completed" in response.json()["detail"] or "user" in response.json()["detail"]
