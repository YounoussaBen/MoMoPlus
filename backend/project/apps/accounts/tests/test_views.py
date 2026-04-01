import uuid

import pytest
from rest_framework import status

from project.apps.accounts.models import LoanGuarantor, User


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


# ---------------------------------------------------------------------------
# Guarantor Views
# ---------------------------------------------------------------------------


def _make_guarantor_client(auth_client_factory, user_factory):
    """Create a user and authenticated client for guarantor tests."""
    supabase_id = uuid.uuid4()
    user = user_factory(
        email=f"guser-{supabase_id.hex[:8]}@example.com",
        username=f"guser-{supabase_id.hex[:8]}",
        supabase_user_id=supabase_id,
    )
    client = auth_client_factory(
        {
            "sub": str(supabase_id),
            "email": user.email,
            "user_metadata": {"first_name": user.first_name, "last_name": user.last_name},
        }
    )
    return client, user


class TestGuarantorList:
    @pytest.mark.django_db
    def test_unauthenticated_rejected(self, api_client):
        response = api_client.get("/api/auth/guarantors/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_returns_empty_list(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)
        response = client.get("/api/auth/guarantors/")
        assert response.status_code == status.HTTP_200_OK
        assert response.data == []

    @pytest.mark.django_db
    def test_returns_user_guarantors(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        LoanGuarantor.objects.create(user=user, name="A", phone_number="024")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="055")

        response = client.get("/api/auth/guarantors/")

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 2


class TestGuarantorCreate:
    @pytest.mark.django_db
    def test_creates_single_guarantor(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)

        response = client.post("/api/auth/guarantors/", {"name": "Kwame", "phone_number": "0241234567"}, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["name"] == "Kwame"
        assert user.loan_guarantors.count() == 1

    @pytest.mark.django_db
    def test_validation_error_missing_name(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)

        response = client.post("/api/auth/guarantors/", {"phone_number": "024"}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST


class TestGuarantorBulkCreate:
    @pytest.mark.django_db
    def test_bulk_creates_2_guarantors(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        payload = {
            "guarantors": [
                {"name": "A", "phone_number": "024"},
                {"name": "B", "phone_number": "055"},
            ]
        }

        response = client.post("/api/auth/guarantors/bulk/", payload, format="json")

        assert response.status_code == status.HTTP_201_CREATED
        assert len(response.data) == 2
        assert user.loan_guarantors.count() == 2

    @pytest.mark.django_db
    def test_rejects_fewer_than_2(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)
        payload = {"guarantors": [{"name": "Solo", "phone_number": "024"}]}

        response = client.post("/api/auth/guarantors/bulk/", payload, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_rejects_empty_list(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)

        response = client.post("/api/auth/guarantors/bulk/", {"guarantors": []}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST


class TestGuarantorUpdate:
    @pytest.mark.django_db
    def test_updates_name(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        g = LoanGuarantor.objects.create(user=user, name="Old", phone_number="024")

        response = client.put(f"/api/auth/guarantors/{g.id}/", {"name": "New"}, format="json")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["name"] == "New"

    @pytest.mark.django_db
    def test_updates_phone(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        g = LoanGuarantor.objects.create(user=user, name="Name", phone_number="024")

        response = client.put(f"/api/auth/guarantors/{g.id}/", {"phone_number": "055"}, format="json")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["phone_number"] == "055"

    @pytest.mark.django_db
    def test_returns_404_for_other_users_guarantor(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)
        other_user = user_factory(email="other@example.com", username="other")
        g = LoanGuarantor.objects.create(user=other_user, name="X", phone_number="024")

        response = client.put(f"/api/auth/guarantors/{g.id}/", {"name": "Hack"}, format="json")

        assert response.status_code == status.HTTP_404_NOT_FOUND


class TestGuarantorDelete:
    @pytest.mark.django_db
    def test_deletes_when_3_exist(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        g1 = LoanGuarantor.objects.create(user=user, name="A", phone_number="1")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="2")
        LoanGuarantor.objects.create(user=user, name="C", phone_number="3")

        response = client.delete(f"/api/auth/guarantors/{g1.id}/")

        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert user.loan_guarantors.count() == 2

    @pytest.mark.django_db
    def test_blocked_when_only_2_exist(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        g1 = LoanGuarantor.objects.create(user=user, name="A", phone_number="1")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="2")

        response = client.delete(f"/api/auth/guarantors/{g1.id}/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert user.loan_guarantors.count() == 2


class TestProfileHasGuarantors:
    @pytest.mark.django_db
    def test_false_with_no_guarantors(self, auth_client_factory, user_factory):
        client, _ = _make_guarantor_client(auth_client_factory, user_factory)

        response = client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["has_guarantors"] is False

    @pytest.mark.django_db
    def test_false_with_1_guarantor(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        LoanGuarantor.objects.create(user=user, name="A", phone_number="024")

        response = client.get("/api/auth/profile/")

        assert response.data["has_guarantors"] is False

    @pytest.mark.django_db
    def test_true_with_2_guarantors(self, auth_client_factory, user_factory):
        client, user = _make_guarantor_client(auth_client_factory, user_factory)
        LoanGuarantor.objects.create(user=user, name="A", phone_number="024")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="055")

        response = client.get("/api/auth/profile/")

        assert response.data["has_guarantors"] is True
