from typing import cast
from uuid import uuid4

import pytest
from django.db import IntegrityError

from project.apps.accounts.factories import UserFactory
from project.apps.accounts.models import User


class TestUserModel:
    @pytest.mark.django_db
    def test_create_user(self):
        """Test creating a user"""
        user = cast(User, UserFactory())
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
        user = cast(User, UserFactory())
        assert str(user.id).count("-") == 4  # UUID format
        assert len(str(user.id)) == 36  # UUID length

    @pytest.mark.django_db
    def test_timestamps_auto_populated(self):
        """Test created_at and updated_at are auto-populated"""
        user = cast(User, UserFactory())
        assert user.created_at
        assert user.updated_at
        assert user.created_at <= user.updated_at

    @pytest.mark.django_db
    def test_supabase_user_id_unique(self):
        """Test Supabase user IDs remain unique when mapped into Django."""
        supabase_user_id = uuid4()
        UserFactory(supabase_user_id=supabase_user_id)
        with pytest.raises(IntegrityError):
            UserFactory(email="other@example.com", username="otheruser", supabase_user_id=supabase_user_id)
