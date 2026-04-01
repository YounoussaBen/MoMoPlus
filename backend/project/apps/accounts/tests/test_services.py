from uuid import uuid4

import pytest

from project.apps.accounts.models import LoanGuarantor, User
from project.apps.accounts.services import (
    add_guarantor,
    bulk_create_guarantors,
    delete_guarantor,
    sync_user_from_supabase_claims,
    update_guarantor,
)


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


# ---------------------------------------------------------------------------
# Loan Guarantor Services
# ---------------------------------------------------------------------------


class TestBulkCreateGuarantors:
    @pytest.mark.django_db
    def test_creates_multiple_guarantors(self, user_factory):
        user = user_factory(email="g1@example.com", username="g1")
        data = [
            {"name": "John Doe", "phone_number": "0241234567"},
            {"name": "Jane Smith", "phone_number": "0201234567"},
        ]

        result = bulk_create_guarantors(user=user, guarantors_data=data)

        assert len(result) == 2
        assert user.loan_guarantors.count() == 2

    @pytest.mark.django_db
    def test_raises_if_fewer_than_2(self, user_factory):
        user = user_factory(email="g2@example.com", username="g2")

        with pytest.raises(ValueError, match="At least 2"):
            bulk_create_guarantors(user=user, guarantors_data=[{"name": "Solo", "phone_number": "024"}])


class TestAddGuarantor:
    @pytest.mark.django_db
    def test_creates_one_guarantor(self, user_factory):
        user = user_factory(email="g3@example.com", username="g3")

        guarantor = add_guarantor(user=user, name="Kwame", phone_number="0551234567")

        assert guarantor.name == "Kwame"
        assert guarantor.phone_number == "0551234567"
        assert guarantor.user == user


class TestUpdateGuarantor:
    @pytest.mark.django_db
    def test_updates_name(self, user_factory):
        user = user_factory(email="g4@example.com", username="g4")
        guarantor = LoanGuarantor.objects.create(user=user, name="Old Name", phone_number="024")

        updated = update_guarantor(guarantor=guarantor, name="New Name")

        assert updated.name == "New Name"
        assert updated.phone_number == "024"

    @pytest.mark.django_db
    def test_updates_phone(self, user_factory):
        user = user_factory(email="g5@example.com", username="g5")
        guarantor = LoanGuarantor.objects.create(user=user, name="Name", phone_number="024")

        updated = update_guarantor(guarantor=guarantor, phone_number="055")

        assert updated.phone_number == "055"
        assert updated.name == "Name"


class TestDeleteGuarantor:
    @pytest.mark.django_db
    def test_deletes_when_more_than_2_remain(self, user_factory):
        user = user_factory(email="g6@example.com", username="g6")
        g1 = LoanGuarantor.objects.create(user=user, name="A", phone_number="1")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="2")
        LoanGuarantor.objects.create(user=user, name="C", phone_number="3")

        delete_guarantor(guarantor=g1, user=user)

        assert user.loan_guarantors.count() == 2

    @pytest.mark.django_db
    def test_raises_when_only_2_remain(self, user_factory):
        user = user_factory(email="g7@example.com", username="g7")
        g1 = LoanGuarantor.objects.create(user=user, name="A", phone_number="1")
        LoanGuarantor.objects.create(user=user, name="B", phone_number="2")

        with pytest.raises(ValueError, match="At least 2"):
            delete_guarantor(guarantor=g1, user=user)

        assert user.loan_guarantors.count() == 2
