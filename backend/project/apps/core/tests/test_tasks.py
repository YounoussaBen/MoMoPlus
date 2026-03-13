from unittest.mock import patch

from project.apps.core.tasks import (
    cleanup_old_data,
    example_long_task,
    health_check_task,
    send_welcome_email,
)


class TestCeleryTasks:
    @patch("project.apps.core.tasks.send_mail")
    def test_send_welcome_email(self, mock_send_mail):
        """Test welcome email task"""
        result = send_welcome_email("test@example.com", "Test User")

        mock_send_mail.assert_called_once()
        assert result == "Welcome email sent to test@example.com"

    def test_example_long_task(self):
        """Test example long task"""
        result = example_long_task(0)  # 0 seconds for testing
        assert result == "Task completed after 0 seconds"

    def test_health_check_task(self):
        result = health_check_task()
        assert result["status"] == "healthy"
        assert "timestamp" in result
        assert "worker" in result

    def test_cleanup_old_data(self):
        result = cleanup_old_data()
        assert result == "Cleanup completed"
