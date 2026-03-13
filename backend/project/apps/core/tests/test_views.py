from unittest.mock import MagicMock, patch

import pytest
from django.test import RequestFactory
from django.urls import reverse
from rest_framework.test import APIClient

from project.apps.core.views import csrf_failure


@pytest.mark.django_db
class TestCoreViews:
    def setup_method(self):
        self.client = APIClient()

    def test_api_status_success(self):
        response = self.client.get(reverse("api_status"))  # assumes named URL
        assert response.status_code in [200, 503]
        assert "status" in response.json()

    def test_status_page_renders_backend_checks(self):
        sample_payload = {
            "status": "online",
            "timestamp": "2026-03-13T18:21:00.458838+00:00",
            "version": "1.0.0",
            "environment": "local",
            "services": {
                "database": {"status": "healthy", "type": "postgresql", "response_time": "< 1ms"},
                "redis": {"status": "healthy", "connected_clients": 6, "used_memory_human": "1.28M"},
                "celery": {"status": "unhealthy", "error": "No workers available"},
            },
            "docs": "http://127.0.0.1:8000/api/docs/",
            "system": {"error": "Memory metrics are not available on this platform"},
            "overall_status": "unhealthy",
        }

        with patch("project.apps.core.views.build_status_payload", return_value=(sample_payload, 503)):
            response = self.client.get(reverse("status_page"))

        assert response.status_code == 200
        content = response.content.decode()
        assert "Some Systems Need Attention" in content
        assert "Database" in content
        assert "Redis" in content
        assert "Celery" in content
        assert "No workers available" in content
        assert "/api/status/" in content

    def test_home_status_card_links_to_status_page(self):
        response = self.client.get(reverse("home"))

        assert response.status_code == 200
        assert b'href="/status/"' in response.content

    def test_celery_status_success(self):
        with patch("project.apps.core.views.current_app.control.inspect") as mock_inspect:
            mock_inspect.return_value.stats.return_value = {"worker1": {}}
            mock_inspect.return_value.active.return_value = {}
            mock_inspect.return_value.scheduled.return_value = {}
            mock_inspect.return_value.reserved.return_value = {}
            mock_inspect.return_value.registered.return_value = {}

            response = self.client.get(reverse("celery_status"))  # assumes named URL
            assert response.status_code == 200
            assert "workers" in response.json()

    def test_task_status_pending(self):
        with patch("project.apps.core.views.current_app.AsyncResult") as mock_result:
            mock = MagicMock()
            mock.state = "PENDING"
            mock_result.return_value = mock

            response = self.client.get(reverse("task_status", args=["some-id"]))  # assumes named URL
            assert response.status_code == 200
            assert response.json()["state"] == "PENDING"

    def test_task_status_progress(self):
        with patch("project.apps.core.views.current_app.AsyncResult") as mock_result:
            mock = MagicMock()
            mock.state = "PROGRESS"
            mock.result = {"foo": "bar"}
            mock.info = {"current": 5, "total": 10}
            mock_result.return_value = mock

            response = self.client.get(reverse("task_status", args=["progress-id"]))
            assert response.status_code == 200
            data = response.json()
            assert data["state"] == "PROGRESS"
            assert data["current"] == 5
            assert data["total"] == 10

    def test_task_status_failure(self):
        with patch("project.apps.core.views.current_app.AsyncResult") as mock_result:
            mock = MagicMock()
            mock.state = "FAILURE"
            mock.info = Exception("Test failure")
            mock_result.return_value = mock

            response = self.client.get(reverse("task_status", args=["fail-id"]))
            assert response.status_code == 200
            assert response.json()["state"] == "FAILURE"

    def test_csrf_failure(self):
        request = RequestFactory().get("/")
        response = csrf_failure(request, reason="Test reason")

        assert response.status_code == 403

        import json

        data = json.loads(response.content)
        assert "reason" in data
        assert data["reason"] == "Test reason"
        assert data["error"] == "CSRF verification failed"
