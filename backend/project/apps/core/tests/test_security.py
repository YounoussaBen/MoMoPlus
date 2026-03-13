import pytest
from rest_framework.test import APIClient


class TestSecuritySettings:
    def test_cors_headers_present(self):
        """Test CORS headers are set"""
        client = APIClient()
        response = client.options("/api/schema/", HTTP_ORIGIN="http://localhost:3000")
        assert response.status_code == 200
        assert "Access-Control-Allow-Origin" in response.headers

    @pytest.mark.django_db
    def test_supabase_bearer_auth_is_enforced(self, authenticated_client):
        """Test Supabase bearer auth is wired for protected endpoints."""
        response = authenticated_client.get("/api/auth/profile/")
        assert response.status_code == 200
        assert response.data["email"] == "supabase@example.com"

    @pytest.mark.django_db
    def test_unauthorized_access_blocked(self, api_client):
        """Test unauthorized access is blocked"""
        response = api_client.get("/api/auth/profile/")
        assert response.status_code == 401
