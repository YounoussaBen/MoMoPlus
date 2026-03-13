import pytest


class TestApiDocumentation:
    @pytest.mark.django_db
    def test_schema_is_public(self, django_client):
        response = django_client.get("/api/schema/", HTTP_ACCEPT="application/json")

        assert response.status_code == 200
        schema = response.json()
        register_operation = schema["paths"]["/api/auth/register/"]["post"]

        assert schema["openapi"].startswith("3.")
        assert "/api/auth/register/" in schema["paths"]
        assert "/api/token/" in schema["paths"]
        assert "requestBody" in register_operation
        assert "application/json" in register_operation["requestBody"]["content"]

    @pytest.mark.django_db
    def test_swagger_ui_is_available(self, django_client):
        response = django_client.get("/api/docs/")

        assert response.status_code == 200
        assert b'id="swagger-ui"' in response.content
        assert b"/api/schema/" in response.content
