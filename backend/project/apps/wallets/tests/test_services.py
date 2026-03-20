from datetime import timedelta

import pytest
from django.utils import timezone

from project.apps.wallets.models import Wallet, WalletOtp
from project.apps.wallets.services import (
    add_wallet,
    delete_wallet,
    resend_otp,
    set_default_wallet,
    verify_otp,
)


@pytest.mark.django_db
class TestAddWallet:
    def test_creates_unverified_wallet(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")

        assert wallet.phone_number == "0241234567"
        assert wallet.network == "mtn"
        assert wallet.is_verified is False
        assert wallet.is_default is False
        assert wallet.user == user

    def test_sends_otp_on_creation(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")

        assert WalletOtp.objects.filter(wallet=wallet).count() == 1

    def test_rejects_duplicate_phone_number(self, user):
        add_wallet(user=user, phone_number="0241234567", network="mtn")

        with pytest.raises(ValueError, match="already added"):
            add_wallet(user=user, phone_number="0241234567", network="vodafone")

    def test_different_users_can_add_same_number(self, user, user_factory):
        other_user = user_factory(email="other@example.com", username="other")
        add_wallet(user=user, phone_number="0241234567", network="mtn")
        wallet2 = add_wallet(user=other_user, phone_number="0241234567", network="mtn")

        assert wallet2.user == other_user


@pytest.mark.django_db
class TestVerifyOtp:
    def test_verifies_wallet_with_correct_code(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)

        result = verify_otp(wallet=wallet, code=otp.code)

        assert result.is_verified is True

    def test_sets_first_verified_wallet_as_default(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)

        result = verify_otp(wallet=wallet, code=otp.code)

        assert result.is_default is True

    def test_second_verified_wallet_not_default(self, user):
        wallet1 = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp1 = WalletOtp.objects.get(wallet=wallet1)
        verify_otp(wallet=wallet1, code=otp1.code)

        wallet2 = add_wallet(user=user, phone_number="0551234567", network="vodafone")
        otp2 = WalletOtp.objects.get(wallet=wallet2)
        result = verify_otp(wallet=wallet2, code=otp2.code)

        assert result.is_default is False

    def test_rejects_wrong_code(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")

        with pytest.raises(ValueError, match="Invalid or expired"):
            verify_otp(wallet=wallet, code="000000")

    def test_rejects_expired_otp(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)
        otp.expires_at = timezone.now() - timedelta(minutes=1)
        otp.save()

        with pytest.raises(ValueError, match="Invalid or expired"):
            verify_otp(wallet=wallet, code=otp.code)

    def test_rejects_already_used_otp(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)
        otp.used = True
        otp.save()

        with pytest.raises(ValueError, match="Invalid or expired"):
            verify_otp(wallet=wallet, code=otp.code)

    def test_rejects_already_verified_wallet(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)
        verify_otp(wallet=wallet, code=otp.code)

        with pytest.raises(ValueError, match="already verified"):
            verify_otp(wallet=wallet, code=otp.code)


@pytest.mark.django_db
class TestResendOtp:
    def test_invalidates_old_otps_and_creates_new(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        old_otp = WalletOtp.objects.get(wallet=wallet)

        resend_otp(wallet=wallet)

        old_otp.refresh_from_db()
        assert old_otp.used is True
        assert WalletOtp.objects.filter(wallet=wallet, used=False).count() == 1

    def test_rejects_verified_wallet(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)
        verify_otp(wallet=wallet, code=otp.code)

        with pytest.raises(ValueError, match="already verified"):
            resend_otp(wallet=wallet)


@pytest.mark.django_db
class TestSetDefaultWallet:
    def test_sets_verified_wallet_as_default(self, user):
        wallet1 = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp1 = WalletOtp.objects.get(wallet=wallet1)
        verify_otp(wallet=wallet1, code=otp1.code)

        wallet2 = add_wallet(user=user, phone_number="0551234567", network="vodafone")
        otp2 = WalletOtp.objects.get(wallet=wallet2)
        verify_otp(wallet=wallet2, code=otp2.code)

        result = set_default_wallet(user=user, wallet=wallet2)

        assert result.is_default is True
        wallet1.refresh_from_db()
        assert wallet1.is_default is False

    def test_rejects_unverified_wallet(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")

        with pytest.raises(ValueError, match="Only verified"):
            set_default_wallet(user=user, wallet=wallet)

    def test_rejects_other_users_wallet(self, user, user_factory):
        other_user = user_factory(email="other@example.com", username="other")
        wallet = add_wallet(user=other_user, phone_number="0241234567", network="mtn")
        otp = WalletOtp.objects.get(wallet=wallet)
        verify_otp(wallet=wallet, code=otp.code)

        with pytest.raises(ValueError, match="does not belong"):
            set_default_wallet(user=user, wallet=wallet)


@pytest.mark.django_db
class TestDeleteWallet:
    def test_deletes_wallet(self, user):
        wallet = add_wallet(user=user, phone_number="0241234567", network="mtn")

        delete_wallet(user=user, wallet=wallet)

        assert not Wallet.objects.filter(pk=wallet.pk).exists()

    def test_promotes_next_default_when_default_deleted(self, user):
        wallet1 = add_wallet(user=user, phone_number="0241234567", network="mtn")
        otp1 = WalletOtp.objects.get(wallet=wallet1)
        verify_otp(wallet=wallet1, code=otp1.code)

        wallet2 = add_wallet(user=user, phone_number="0551234567", network="vodafone")
        otp2 = WalletOtp.objects.get(wallet=wallet2)
        verify_otp(wallet=wallet2, code=otp2.code)

        delete_wallet(user=user, wallet=wallet1)

        wallet2.refresh_from_db()
        assert wallet2.is_default is True

    def test_rejects_other_users_wallet(self, user, user_factory):
        other_user = user_factory(email="other@example.com", username="other")
        wallet = add_wallet(user=other_user, phone_number="0241234567", network="mtn")

        with pytest.raises(ValueError, match="does not belong"):
            delete_wallet(user=user, wallet=wallet)
