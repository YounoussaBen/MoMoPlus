import pytest
from rest_framework import status

from project.apps.accounts.models import User


class TestAuthenticationViews:
    @pytest.mark.django_db
    def test_staff_login_returns_local_jwt(self, api_client, user_factory):
        staff_user = user_factory(
            email="staff@example.com",
            username="staff",
            password="strongpass123",
            is_staff=True,
            is_superuser=True,
            supabase_user_id=None,
        )

        response = api_client.post(
            "/api/auth/staff/login/",
            {"email": staff_user.email, "password": "strongpass123"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["access"]
        assert response.data["user"]["email"] == staff_user.email
        assert response.data["user"]["is_staff"] is True

    @pytest.mark.django_db
    def test_staff_login_rejects_non_staff_user(self, api_client, user_factory):
        user = user_factory(
            email="member@example.com",
            username="member",
            password="strongpass123",
        )

        response = api_client.post(
            "/api/auth/staff/login/",
            {"email": user.email, "password": "strongpass123"},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN

    @pytest.mark.django_db
    def test_staff_token_can_authenticate_dashboard_requests(self, api_client, user_factory):
        staff_user = user_factory(
            email="staff@example.com",
            username="staff",
            password="strongpass123",
            is_staff=True,
            is_superuser=True,
            supabase_user_id=None,
        )
        login_response = api_client.post(
            "/api/auth/staff/login/",
            {"email": staff_user.email, "password": "strongpass123"},
            format="json",
        )
        api_client.credentials(HTTP_AUTHORIZATION=f"Bearer {login_response.data['access']}")

        response = api_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["email"] == staff_user.email

    @pytest.mark.django_db
    def test_sync_profile_creates_local_user(self, authenticated_client, supabase_claims):
        """Test Supabase-authenticated requests create a mapped Django user."""
        response = authenticated_client.post("/api/auth/sync/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["user"]["email"] == supabase_claims["email"]
        assert response.data["user"]["first_name"] == supabase_claims["user_metadata"]["first_name"]
        assert User.objects.filter(email=supabase_claims["email"]).exists()

    @pytest.mark.django_db
    def test_get_user_profile(self, authenticated_client, supabase_claims):
        """Test getting a profile resolved from Supabase auth."""
        response = authenticated_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["email"] == supabase_claims["email"]
        assert response.data["first_name"] == supabase_claims["user_metadata"]["first_name"]

    @pytest.mark.django_db
    def test_get_profile_unauthorized(self, api_client):
        """Test getting profile without authentication"""
        response = api_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_update_profile_persists_local_fields(self, authenticated_client):
        """Test patching the Django profile for a Supabase-backed user."""
        response = authenticated_client.patch("/api/auth/profile/", {"first_name": "Updated"}, format="json")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["first_name"] == "Updated"
        assert User.objects.get(email="supabase@example.com").first_name == "Updated"

    @pytest.mark.django_db
    def test_logout_returns_supabase_message(self, authenticated_client):
        """Test logout response explains the Supabase session flow."""
        response = authenticated_client.post("/api/auth/logout/")

        assert response.status_code == status.HTTP_200_OK
        assert "bearer token" in response.data["message"]
