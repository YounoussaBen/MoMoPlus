from datetime import timedelta
from uuid import uuid4

import pytest
from django.db import IntegrityError
from django.utils import timezone

from project.apps.accounts.models import LoanGuarantor, LoanGuarantorOtp, User
from project.apps.accounts.services import (
    add_guarantor,
    bulk_create_guarantors,
    delete_guarantor,
    resend_guarantor_otp,
    sync_user_from_supabase_claims,
    update_guarantor,
    verify_guarantor,
)


class TestSupabaseUserSync:
    @pytest.mark.django_db
    def test_sync_creates_phone_only_user_with_nullable_email(self):
        claims = {"sub": str(uuid4()), "phone": "+233241234567", "user_metadata": {}}

        user = sync_user_from_supabase_claims(claims)

        assert user.phone == "+233241234567"
        assert user.email is None
        assert user.is_onboarded is False
        assert user.has_usable_password() is False

    @pytest.mark.django_db
    def test_sync_is_idempotent_for_phone_identity(self):
        supabase_id = uuid4()
        claims = {"sub": str(supabase_id), "phone": "+233241234567", "user_metadata": {}}

        first = sync_user_from_supabase_claims(claims)
        second = sync_user_from_supabase_claims(claims)

        assert first.pk == second.pk
        assert User.objects.filter(phone="+233241234567").count() == 1

    @pytest.mark.django_db
    def test_sync_links_unique_unclaimed_phone(self, user_factory):
        existing = user_factory(phone="+233241234567", supabase_user_id=None)
        claims = {"sub": str(uuid4()), "phone": "+233241234567", "user_metadata": {}}

        synced = sync_user_from_supabase_claims(claims)

        assert synced.pk == existing.pk
        assert synced.supabase_user_id is not None

    @pytest.mark.django_db
    def test_sync_rejects_phone_linked_to_different_supabase_identity(self, user_factory):
        existing = user_factory(phone="+233241234567")
        claims = {"sub": str(uuid4()), "phone": existing.phone, "user_metadata": {}}

        with pytest.raises(ValueError, match="does not match"):
            sync_user_from_supabase_claims(claims)

    @pytest.mark.django_db
    def test_sync_rejects_existing_supabase_identity_changing_to_another_phone(self, user_factory):
        user = user_factory(phone="+233241234567")
        claims = {
            "sub": str(user.supabase_user_id),
            "phone": "+233551234567",
            "user_metadata": {},
        }

        with pytest.raises(ValueError, match="phone does not match"):
            sync_user_from_supabase_claims(claims)

    @pytest.mark.django_db
    def test_sync_converts_unique_identity_race_to_closed_conflict(self, mocker):
        claims = {"sub": str(uuid4()), "phone": "+233241234567", "user_metadata": {}}
        mocker.patch(
            "project.apps.accounts.models.User.save",
            side_effect=IntegrityError("duplicate phone"),
        )

        with pytest.raises(ValueError, match="conflicts"):
            sync_user_from_supabase_claims(claims)

    @pytest.mark.django_db
    def test_sync_creates_new_user_from_supabase_claims(self):
        claims = {
            "sub": str(uuid4()),
            "phone": "+233241234567",
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
    def test_sync_rejects_claims_without_phone(self):
        claims = {"sub": str(uuid4()), "user_metadata": {}}

        with pytest.raises(ValueError, match="phone"):
            sync_user_from_supabase_claims(claims)

    @pytest.mark.django_db
    def test_sync_rejects_mismatched_supabase_identity(self, user_factory):
        user = user_factory(phone="+233241234567")
        claims = {
            "sub": str(uuid4()),
            "phone": user.phone,
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
    def test_creates_multiple_guarantors(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
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
    def test_creates_one_guarantor(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory(email="g3@example.com", username="g3")

        guarantor = add_guarantor(user=user, name="Kwame", phone_number="0551234567")

        assert guarantor.name == "Kwame"
        assert guarantor.phone_number == "+233551234567"
        assert guarantor.user == user

    @pytest.mark.django_db
    def test_rejects_users_current_phone_as_guarantor(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory(phone="+233241234567")

        with pytest.raises(ValueError, match="own current phone"):
            add_guarantor(user=user, name="Self", phone_number="0241234567")


class TestGuarantorConsent:
    @pytest.mark.django_db
    def test_creates_five_minute_otp_and_queues_sms(self, user_factory, mocker, django_capture_on_commit_callbacks):
        enqueue = mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory(first_name="Ama", last_name="Mensah")

        before = timezone.now()
        with django_capture_on_commit_callbacks(execute=True):
            guarantor = add_guarantor(user=user, name="Friend", phone_number="0551234567")
        otp = LoanGuarantorOtp.objects.get(guarantor=guarantor)

        assert otp.used is False
        assert otp.expires_at >= before + timedelta(minutes=5)
        enqueue.assert_called_once_with(
            phone="+233551234567",
            otp_code=otp.code,
            borrower_name="Ama Mensah",
        )

    @pytest.mark.django_db
    def test_verifies_with_latest_code(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory()
        guarantor = add_guarantor(user=user, name="Friend", phone_number="0551234567")
        otp = LoanGuarantorOtp.objects.get(guarantor=guarantor)

        verified = verify_guarantor(guarantor=guarantor, code=otp.code)

        assert verified.is_verified is True
        otp.refresh_from_db()
        assert otp.used is True

    @pytest.mark.django_db
    def test_rejects_expired_code(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory()
        guarantor = add_guarantor(user=user, name="Friend", phone_number="0551234567")
        otp = LoanGuarantorOtp.objects.get(guarantor=guarantor)
        otp.expires_at = timezone.now() - timedelta(minutes=1)
        otp.save(update_fields=["expires_at", "updated_at"])

        with pytest.raises(ValueError, match="Invalid or expired"):
            verify_guarantor(guarantor=guarantor, code=otp.code)

    @pytest.mark.django_db
    def test_resend_invalidates_old_code(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory()
        guarantor = add_guarantor(user=user, name="Friend", phone_number="0551234567")
        old_otp = LoanGuarantorOtp.objects.get(guarantor=guarantor)

        new_otp = resend_guarantor_otp(guarantor=guarantor)

        old_otp.refresh_from_db()
        assert old_otp.used is True
        assert new_otp.code != old_otp.code or new_otp.pk != old_otp.pk
        assert new_otp.used is False


class TestUpdateGuarantor:
    @pytest.mark.django_db
    def test_updates_name(self, user_factory):
        user = user_factory(email="g4@example.com", username="g4")
        guarantor = LoanGuarantor.objects.create(user=user, name="Old Name", phone_number="024")

        updated = update_guarantor(guarantor=guarantor, name="New Name")

        assert updated.name == "New Name"
        assert updated.phone_number == "024"

    @pytest.mark.django_db
    def test_updates_phone(self, user_factory, mocker):
        mocker.patch("project.apps.accounts.services.send_guarantor_otp_task.delay")
        user = user_factory(email="g5@example.com", username="g5")
        guarantor = LoanGuarantor.objects.create(user=user, name="Name", phone_number="024")

        updated = update_guarantor(guarantor=guarantor, phone_number="0551234567")

        assert updated.phone_number == "+233551234567"
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
