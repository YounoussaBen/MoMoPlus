from unittest.mock import patch
from uuid import uuid4

import pytest
from rest_framework import status

from project.apps.wallets.models import Wallet, WalletOtp


@pytest.mark.django_db
class TestWalletListView:
    def test_signup_sync_adds_phone_as_first_wallet(self, authenticated_client):
        sync_response = authenticated_client.post("/api/auth/sync/")
        assert sync_response.status_code == status.HTTP_200_OK

        response = authenticated_client.get("/api/wallets/")

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["phone_number"] == "0241234567"
        assert response.data[0]["network"] == "mtn"
        assert response.data[0]["is_verified"] is True
        assert response.data[0]["is_default"] is True
        assert response.data[0]["is_signup_wallet"] is True

    def test_returns_empty_list_for_new_user(self, authenticated_client):
        response = authenticated_client.get("/api/wallets/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data == []

    def test_returns_user_wallets(self, authenticated_client):
        authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        response = authenticated_client.get("/api/wallets/")

        assert response.status_code == status.HTTP_200_OK
        assert len(response.data) == 1
        assert response.data[0]["phone_number"] == "0241234567"

    def test_unauthenticated_returns_401(self, api_client):
        response = api_client.get("/api/wallets/")

        assert response.status_code == status.HTTP_401_UNAUTHORIZED


@pytest.mark.django_db
class TestWalletCreateView:
    def test_creates_wallet_and_returns_201(self, authenticated_client):
        response = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["phone_number"] == "0241234567"
        assert response.data["network"] == "mtn"
        assert response.data["is_verified"] is False

    def test_rejects_duplicate(self, authenticated_client):
        authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        response = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_allows_phone_number_added_on_another_account(self, authenticated_client, auth_client_factory):
        authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        other_client = auth_client_factory(
            {
                "sub": str(uuid4()),
                "email": "other@example.com",
                "user_metadata": {
                    "first_name": "Other",
                    "last_name": "User",
                },
            }
        )
        response = other_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["phone_number"] == "0241234567"

    def test_rejects_invalid_network(self, authenticated_client):
        response = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "invalid"},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestWalletVerifyView:
    def test_verifies_with_correct_otp(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]
        otp = WalletOtp.objects.get(wallet_id=wallet_id)

        response = authenticated_client.post(
            f"/api/wallets/{wallet_id}/verify/",
            {"code": otp.code},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["is_verified"] is True

    def test_rejects_wrong_otp(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]

        response = authenticated_client.post(
            f"/api/wallets/{wallet_id}/verify/",
            {"code": "000000"},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_returns_404_for_nonexistent_wallet(self, authenticated_client):
        response = authenticated_client.post(
            "/api/wallets/00000000-0000-0000-0000-000000000000/verify/",
            {"code": "123456"},
            format="json",
        )

        assert response.status_code == status.HTTP_404_NOT_FOUND

    def test_returns_400_when_paystack_setup_fails(self, authenticated_client):
        from project.integrations.paystack import PaystackError

        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]
        otp = WalletOtp.objects.get(wallet_id=wallet_id)

        with patch("project.apps.wallets.services.paystack.create_transfer_recipient") as mock_recipient:
            mock_recipient.side_effect = PaystackError("Account details are invalid")

            response = authenticated_client.post(
                f"/api/wallets/{wallet_id}/verify/",
                {"code": otp.code},
                format="json",
            )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "Wallet verification failed" in response.data["detail"]
        wallet = Wallet.objects.get(pk=wallet_id)
        assert wallet.is_verified is False


@pytest.mark.django_db
class TestWalletResendOtpView:
    def test_resends_otp(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]

        response = authenticated_client.post(f"/api/wallets/{wallet_id}/resend-otp/")

        assert response.status_code == status.HTTP_200_OK
        assert WalletOtp.objects.filter(wallet_id=wallet_id, used=False).count() == 1

    def test_rejects_verified_wallet(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]
        otp = WalletOtp.objects.get(wallet_id=wallet_id)
        authenticated_client.post(
            f"/api/wallets/{wallet_id}/verify/",
            {"code": otp.code},
            format="json",
        )

        response = authenticated_client.post(f"/api/wallets/{wallet_id}/resend-otp/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestWalletSetDefaultView:
    def test_sets_verified_wallet_as_default(self, authenticated_client):
        # Create and verify two wallets
        r1 = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )
        otp1 = WalletOtp.objects.get(wallet_id=r1.data["id"])
        authenticated_client.post(
            f"/api/wallets/{r1.data['id']}/verify/",
            {"code": otp1.code},
            format="json",
        )

        r2 = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0551234567", "network": "vodafone"},
            format="json",
        )
        otp2 = WalletOtp.objects.get(wallet_id=r2.data["id"])
        authenticated_client.post(
            f"/api/wallets/{r2.data['id']}/verify/",
            {"code": otp2.code},
            format="json",
        )

        response = authenticated_client.post(f"/api/wallets/{r2.data['id']}/set-default/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["is_default"] is True

    def test_rejects_unverified_wallet(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0241234567", "network": "mtn"},
            format="json",
        )

        response = authenticated_client.post(f"/api/wallets/{create_resp.data['id']}/set-default/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST


@pytest.mark.django_db
class TestWalletDeleteView:
    def test_cannot_delete_signup_wallet(self, authenticated_client):
        authenticated_client.post("/api/auth/sync/")
        wallet = Wallet.objects.get(phone_number="0241234567")

        response = authenticated_client.delete(f"/api/wallets/{wallet.id}/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "signup wallet" in response.data["detail"]
        assert Wallet.objects.filter(pk=wallet.pk).exists()

    def test_deletes_wallet(self, authenticated_client):
        create_resp = authenticated_client.post(
            "/api/wallets/add/",
            {"phone_number": "0551234567", "network": "mtn"},
            format="json",
        )
        wallet_id = create_resp.data["id"]

        response = authenticated_client.delete(f"/api/wallets/{wallet_id}/")

        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not Wallet.objects.filter(pk=wallet_id).exists()

    def test_returns_404_for_nonexistent(self, authenticated_client):
        response = authenticated_client.delete("/api/wallets/00000000-0000-0000-0000-000000000000/")

        assert response.status_code == status.HTTP_404_NOT_FOUND
