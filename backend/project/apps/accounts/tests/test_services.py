from uuid import uuid4

import pytest

from project.apps.accounts.models import User
from project.apps.accounts.services import sync_user_from_supabase_claims


class TestSupabaseUserSync:
    @pytest.mark.django_db
    def test_sync_creates_new_user_from_supabase_claims(self):
        claims = {
            "sub": str(uuid4()),
            "email": "new-user@example.com",
            "user_metadata": {"full_name": "New User"},
        }

        user = sync_user_from_supabase_claims(claims)

        assert user.email == "new-user@example.com"
        assert user.supabase_user_id
        assert user.first_name == "New"
        assert user.last_name == "User"
        assert user.has_usable_password() is False

    @pytest.mark.django_db
    def test_sync_attaches_existing_email_match(self, user_factory):
        existing_user = user_factory(email="existing@example.com", supabase_user_id=None)
        claims = {
            "sub": str(uuid4()),
            "email": existing_user.email,
            "user_metadata": {"first_name": "Existing", "last_name": "User"},
        }

        synced_user = sync_user_from_supabase_claims(claims)

        assert synced_user.pk == existing_user.pk
        assert synced_user.supabase_user_id is not None

    @pytest.mark.django_db
    def test_sync_rejects_claims_without_email(self):
        claims = {"sub": str(uuid4()), "user_metadata": {}}

        with pytest.raises(ValueError, match="email"):
            sync_user_from_supabase_claims(claims)

    @pytest.mark.django_db
    def test_sync_rejects_mismatched_supabase_identity(self, user_factory):
        user = user_factory()
        claims = {
            "sub": str(uuid4()),
            "email": user.email,
            "user_metadata": {"first_name": "Mismatch"},
        }

        with pytest.raises(ValueError, match="does not match"):
            sync_user_from_supabase_claims(claims)

        assert User.objects.filter(pk=user.pk).exists()
