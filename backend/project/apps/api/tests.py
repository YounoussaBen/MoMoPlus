import pytest


class TestApiDocumentation:
    @pytest.mark.django_db
    def test_schema_is_public(self, django_client):
        response = django_client.get("/api/schema/", HTTP_ACCEPT="application/json")

        assert response.status_code == 200
        schema = response.json()
        staff_login_operation = schema["paths"]["/api/auth/staff/login/"]["post"]
        sync_operation = schema["paths"]["/api/auth/sync/"]["post"]
        upload_operation = schema["paths"]["/api/files/"]["post"]

        assert schema["openapi"].startswith("3.")
        assert "/api/auth/staff/login/" in schema["paths"]
        assert "/api/auth/sync/" in schema["paths"]
        assert "/api/auth/profile/" in schema["paths"]
        assert "/api/files/" in schema["paths"]
        assert "/api/files/{file_id}/complete/" in schema["paths"]
        assert "/api/files/{file_id}/access-url/" in schema["paths"]
        assert "security" not in staff_login_operation
        assert sync_operation["security"] == [{"SupabaseBearerAuth": []}]
        assert upload_operation["security"] == [{"SupabaseBearerAuth": []}]

    @pytest.mark.django_db
    def test_swagger_ui_is_available(self, django_client):
        response = django_client.get("/api/docs/")

        assert response.status_code == 200
        assert b'id="swagger-ui"' in response.content
        assert b"/api/schema/" in response.content
