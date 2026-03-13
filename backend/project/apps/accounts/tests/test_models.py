import pytest
from django.contrib.auth import get_user_model
from django.db import IntegrityError

from project.apps.accounts.factories import UserFactory

User = get_user_model()


class TestUserModel:
    @pytest.mark.django_db
    def test_create_user(self):
        """Test creating a user"""
        user = UserFactory()
        assert user.email
        assert user.username
        assert user.check_password("testpass123")
        assert str(user) == user.email

    @pytest.mark.django_db
    def test_email_unique(self):
        """Test email uniqueness constraint"""
        UserFactory(email="test@example.com")
        with pytest.raises(IntegrityError):
            UserFactory(email="test@example.com")

    @pytest.mark.django_db
    def test_user_has_uuid_id(self):
        """Test user has UUID primary key"""
        user = UserFactory()
        assert str(user.id).count("-") == 4  # UUID format
        assert len(str(user.id)) == 36  # UUID length

    @pytest.mark.django_db
    def test_timestamps_auto_populated(self):
        """Test created_at and updated_at are auto-populated"""
        user = UserFactory()
        assert user.created_at
        assert user.updated_at
        assert user.created_at <= user.updated_at
