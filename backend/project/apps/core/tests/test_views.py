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
