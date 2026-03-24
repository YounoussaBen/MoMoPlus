import uuid

import pytest
from django.contrib.auth import get_user_model
from django.test import Client
from rest_framework.test import APIClient

from project.integrations import paystack

User = get_user_model()


@pytest.fixture
def api_client():
    """DRF API client"""
    return APIClient()


@pytest.fixture
def django_client():
    """Django test client"""
    return Client()


@pytest.fixture
def user_factory():
    """Factory for creating users"""

    def _create_user(**kwargs):
        defaults = {
            "username": "testuser",
            "email": "test@example.com",
            "first_name": "Test",
            "last_name": "User",
            "password": "testpass123",
            "supabase_user_id": uuid.uuid4(),
        }
        defaults.update(kwargs)
        return User.objects.create_user(**defaults)

    return _create_user


@pytest.fixture
def user(user_factory):
    """Create a test user"""
    return user_factory()


@pytest.fixture
def supabase_claims():
    return {
        "sub": str(uuid.uuid4()),
        "email": "supabase@example.com",
        "user_metadata": {
            "first_name": "Supa",
            "last_name": "Base",
        },
    }


@pytest.fixture
def auth_client_factory(mocker):
    claims_by_token = {}

    def verify_access_token(token: str):
        return claims_by_token[token]

    mocker.patch(
        "project.apps.accounts.authentication.SupabaseAuthClient.verify_access_token",
        side_effect=verify_access_token,
    )

    def _build(claims: dict[str, object]) -> APIClient:
        token = f"supabase-token-{len(claims_by_token) + 1}"
        claims_by_token[token] = claims
        client = APIClient()
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {token}")
        return client

    return _build


@pytest.fixture
def authenticated_client(auth_client_factory, supabase_claims):
    """API client with a mocked Supabase-authenticated user"""
    return auth_client_factory(supabase_claims)


@pytest.fixture(autouse=True)
def mock_paystack_network_calls(monkeypatch):
    """Prevent backend tests from creating real Paystack resources."""

    def _mock_post(path: str, data: dict | None = None) -> dict:
        payload = data or {}

        if path == "/subaccount":
            account_number = str(payload.get("account_number", "0000000000"))
            return {
                "status": True,
                "data": {
                    "subaccount_code": f"SUB_{account_number}",
                    "business_name": payload.get("business_name", "Test Business"),
                },
            }

        if path == "/transferrecipient":
            account_number = str(payload.get("account_number", "0000000000"))
            return {
                "status": True,
                "data": {
                    "recipient_code": f"RCP_{account_number}",
                    "name": payload.get("name", "Test Recipient"),
                },
            }

        if path == "/charge":
            reference = str(payload.get("reference", "CHARGE_test"))
            return {
                "status": True,
                "data": {
                    "reference": reference,
                    "status": "pay_offline",
                },
            }

        if path == "/transfer":
            reference = str(payload.get("reference", "TRF_test"))
            return {
                "status": True,
                "data": {
                    "reference": reference,
                    "status": "success",
                    "transfer_code": f"TRF_{reference}",
                },
            }

        return {"status": True, "data": {}}

    def _mock_get(path: str, params: dict | None = None) -> dict:
        if path == "/bank":
            return {
                "status": True,
                "data": [
                    {"name": "MTN", "code": "MTN"},
                    {"name": "Vodafone", "code": "VOD"},
                    {"name": "AirtelTigo", "code": "ATL"},
                ],
            }

        if path.startswith("/transaction/verify/"):
            reference = path.rsplit("/", maxsplit=1)[-1]
            return {
                "status": True,
                "data": {
                    "reference": reference,
                    "status": "success",
                },
            }

        return {"status": True, "data": {}}

    monkeypatch.setattr(paystack, "_post", _mock_post)
    monkeypatch.setattr(paystack, "_get", _mock_get)
