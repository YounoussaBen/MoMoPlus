import uuid

import pytest
from django.contrib.auth import get_user_model
from django.test import Client
from rest_framework.test import APIClient

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
