import pytest
from rest_framework import status

from project.apps.accounts.models import KycStatus
from project.apps.kyc.models import KycSubmission
from project.apps.kyc.services import reject_kyc

from .conftest import make_submission_asset_ids


def _submit_payload(user):
    """Build a JSON-serialisable submit payload using pre-uploaded file asset IDs."""
    return {"id_type": KycSubmission.IdType.NATIONAL_ID, **make_submission_asset_ids(user)}


class TestKycSubmit:
    @pytest.mark.django_db
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.post("/api/kyc/submit/", {}, format="json")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_submit_creates_pending_submission(self, kyc_client, kyc_user, media_root):
        response = kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.PENDING
        assert response.data["id_type"] == KycSubmission.IdType.NATIONAL_ID

    @pytest.mark.django_db
    def test_submit_sets_user_kyc_status_pending(self, kyc_client, kyc_user, media_root):
        kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        kyc_user.refresh_from_db()
        assert kyc_user.kyc_status == KycStatus.PENDING

    @pytest.mark.django_db
    def test_returns_400_if_already_pending(self, kyc_client, kyc_user, media_root):
        kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")
        response = kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_400_if_missing_field(self, kyc_client, kyc_user, media_root):
        payload = _submit_payload(kyc_user)
        del payload["selfie_id"]

        response = kyc_client.post("/api/kyc/submit/", payload, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_resubmission_allowed_after_rejection(self, kyc_client, kyc_user, kyc_submission_factory, media_root):
        submission = kyc_submission_factory(kyc_user)
        reject_kyc(submission=submission, reviewer=kyc_user, reason="Blurry")

        response = kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.PENDING


class TestKycStatus:
    @pytest.mark.django_db
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/kyc/status/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_returns_404_if_no_submission(self, kyc_client):
        response = kyc_client.get("/api/kyc/status/")
        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_returns_submission_status(self, kyc_client, kyc_user, media_root):
        kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        response = kyc_client.get("/api/kyc/status/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.PENDING
        assert "id_type" in response.data

    @pytest.mark.django_db
    def test_includes_rejection_reason_when_rejected(self, kyc_client, kyc_user, kyc_submission_factory, media_root):
        submission = kyc_submission_factory(kyc_user)
        reject_kyc(submission=submission, reviewer=kyc_user, reason="Document expired")

        response = kyc_client.get("/api/kyc/status/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.REJECTED
        assert response.data["rejection_reason"] == "Document expired"

    @pytest.mark.django_db
    def test_profile_endpoint_includes_kyc_status(self, kyc_client, kyc_user, media_root):
        kyc_client.post("/api/kyc/submit/", _submit_payload(kyc_user), format="json")

        response = kyc_client.get("/api/auth/profile/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["kyc_status"] == KycStatus.PENDING
