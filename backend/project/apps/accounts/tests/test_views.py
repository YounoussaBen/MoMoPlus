import pytest
from rest_framework import status


class TestAuthenticationViews:
    @pytest.mark.django_db
    def test_user_registration_success(self, api_client):
        """Test successful user registration"""
        data = {
            "username": "newuser",
            "email": "new@example.com",
            "password": "strongpass123",
            "password_confirm": "strongpass123",
            "first_name": "New",
            "last_name": "User",
        }

        response = api_client.post("/api/auth/register/", data)

        assert response.status_code == status.HTTP_201_CREATED
        assert "access" in response.data
        assert "refresh" in response.data
        assert response.data["user"]["email"] == "new@example.com"

    @pytest.mark.django_db
    def test_user_registration_password_mismatch(self, api_client):
        """Test registration with password mismatch"""
        data = {
            "username": "newuser",
            "email": "new@example.com",
            "password": "strongpass123",
            "password_confirm": "differentpass",
            "first_name": "New",
            "last_name": "User",
        }

        response = api_client.post("/api/auth/register/", data)

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "Passwords don't match" in str(response.data)

    @pytest.mark.django_db
    def test_get_user_profile(self, authenticated_client, user):
        """Test getting user profile"""
        response = authenticated_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["email"] == user.email
        assert response.data["username"] == user.username

    @pytest.mark.django_db
    def test_get_profile_unauthorized(self, api_client):
        """Test getting profile without authentication"""
        response = api_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
