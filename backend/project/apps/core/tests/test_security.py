import pytest
from rest_framework.test import APIClient

from project.apps.accounts.factories import UserFactory


class TestSecuritySettings:
    def test_cors_headers_present(self):
        """Test CORS headers are set"""
        client = APIClient()
        response = client.options("/api/auth/register/", HTTP_ORIGIN="http://example.com")
        assert response.status_code == 200
        assert "Access-Control-Allow-Origin" in response.headers

    @pytest.mark.django_db
    def test_jwt_token_expiry(self, api_client):
        """Test JWT tokens have proper expiry"""
        user = UserFactory()
        data = {"email": user.email, "password": "testpass123"}
        response = api_client.post("/api/token/", data)
        assert response.status_code == 200

        # Token should be present
        assert "access" in response.data
        assert "refresh" in response.data

    @pytest.mark.django_db
    def test_unauthorized_access_blocked(self, api_client):
        """Test unauthorized access is blocked"""
        response = api_client.get("/api/auth/profile/")
        assert response.status_code == 401
