import pytest
from rest_framework import status

from project.apps.kyc.models import KycSubmission
from project.apps.kyc.services import approve_kyc


class TestStaffKycList:
    @pytest.mark.django_db
    def test_unauthenticated_is_rejected(self, api_client):
        response = api_client.get("/api/staff/kyc/")
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, authenticated_client):
        response = authenticated_client.get("/api/staff/kyc/")
        assert response.status_code == status.HTTP_403_FORBIDDEN

    @pytest.mark.django_db
    def test_returns_paginated_list(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        u1 = user_factory(email="list1@example.com", username="list1")
        u2 = user_factory(email="list2@example.com", username="list2")
        kyc_submission_factory(u1)
        kyc_submission_factory(u2)

        response = client.get("/api/staff/kyc/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] >= 2

    @pytest.mark.django_db
    def test_filter_by_status_pending(self, user_factory, staff_client, kyc_submission_factory):
        client, staff = staff_client
        u1 = user_factory(email="filterpending@example.com", username="filterpending")
        u2 = user_factory(email="filterapproved@example.com", username="filterapproved")
        kyc_submission_factory(u1)
        sub2 = kyc_submission_factory(u2)
        approve_kyc(submission=sub2, reviewer=staff)

        response = client.get("/api/staff/kyc/?status=pending")

        assert response.status_code == status.HTTP_200_OK
        statuses = [s["status"] for s in response.data["results"]]
        assert all(s == KycSubmission.Status.PENDING for s in statuses)

    @pytest.mark.django_db
    def test_search_by_user_email(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="findkyc@example.com", username="findkyc")
        kyc_submission_factory(user)

        response = client.get("/api/staff/kyc/?search=findkyc")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["user"]["email"] == "findkyc@example.com"

    @pytest.mark.django_db
    def test_list_includes_user_and_status(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="listfields@example.com", username="listfields")
        kyc_submission_factory(user)

        response = client.get("/api/staff/kyc/")

        assert response.status_code == status.HTTP_200_OK
        first = response.data["results"][0]
        assert "user" in first
        assert "status" in first
        assert "id_type" in first


class TestStaffKycDetail:
    @pytest.mark.django_db
    def test_returns_submission_detail(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="detail@example.com", username="detail")
        submission = kyc_submission_factory(user)

        response = client.get(f"/api/staff/kyc/{submission.id}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["id"] == str(submission.id)
        assert "id_front_url" in response.data
        assert "id_back_url" in response.data
        assert "selfie_url" in response.data
        assert "proof_of_address_url" in response.data

    @pytest.mark.django_db
    def test_returns_404_for_missing_submission(self, staff_client):
        client, _ = staff_client
        response = client.get("/api/staff/kyc/00000000-0000-0000-0000-000000000000/")
        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, user_factory, authenticated_client, kyc_submission_factory):
        user = user_factory(email="detailforbidden@example.com", username="detailforbidden")
        submission = kyc_submission_factory(user)

        response = authenticated_client.get(f"/api/staff/kyc/{submission.id}/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


class TestStaffKycApprove:
    @pytest.mark.django_db
    def test_approves_pending_submission(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="approve@example.com", username="approve")
        submission = kyc_submission_factory(user)

        response = client.post(f"/api/staff/kyc/{submission.id}/approve/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.APPROVED

    @pytest.mark.django_db
    def test_approve_updates_user_kyc_status(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="approveuser@example.com", username="approveuser")
        submission = kyc_submission_factory(user)

        client.post(f"/api/staff/kyc/{submission.id}/approve/")

        user.refresh_from_db()
        from project.apps.accounts.models import KycStatus

        assert user.kyc_status == KycStatus.APPROVED

    @pytest.mark.django_db
    def test_returns_400_if_not_pending(self, user_factory, staff_client, kyc_submission_factory):
        client, staff = staff_client
        user = user_factory(email="alreadyapproved@example.com", username="alreadyapproved")
        submission = kyc_submission_factory(user)
        approve_kyc(submission=submission, reviewer=staff)

        response = client.post(f"/api/staff/kyc/{submission.id}/approve/")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_404_for_missing_submission(self, staff_client):
        client, _ = staff_client
        response = client.post("/api/staff/kyc/00000000-0000-0000-0000-000000000000/approve/")
        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, user_factory, authenticated_client, kyc_submission_factory):
        user = user_factory(email="approveforbidden@example.com", username="approveforbidden")
        submission = kyc_submission_factory(user)

        response = authenticated_client.post(f"/api/staff/kyc/{submission.id}/approve/")

        assert response.status_code == status.HTTP_403_FORBIDDEN


class TestStaffKycReject:
    @pytest.mark.django_db
    def test_rejects_pending_submission(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="reject@example.com", username="reject")
        submission = kyc_submission_factory(user)

        response = client.post(
            f"/api/staff/kyc/{submission.id}/reject/",
            {"reason": "ID is expired"},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["status"] == KycSubmission.Status.REJECTED
        assert response.data["rejection_reason"] == "ID is expired"

    @pytest.mark.django_db
    def test_reject_updates_user_kyc_status(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="rejectuser@example.com", username="rejectuser")
        submission = kyc_submission_factory(user)

        client.post(
            f"/api/staff/kyc/{submission.id}/reject/",
            {"reason": "Selfie mismatch"},
            format="json",
        )

        user.refresh_from_db()
        from project.apps.accounts.models import KycStatus

        assert user.kyc_status == KycStatus.REJECTED

    @pytest.mark.django_db
    def test_returns_400_without_reason(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="noreason@example.com", username="noreason")
        submission = kyc_submission_factory(user)

        response = client.post(f"/api/staff/kyc/{submission.id}/reject/", {}, format="json")

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_400_if_not_pending(self, user_factory, staff_client, kyc_submission_factory):
        client, staff = staff_client
        user = user_factory(email="alreadyrejected@example.com", username="alreadyrejected")
        submission = kyc_submission_factory(user)
        from project.apps.kyc.services import reject_kyc

        reject_kyc(submission=submission, reviewer=staff, reason="First rejection")

        response = client.post(
            f"/api/staff/kyc/{submission.id}/reject/",
            {"reason": "Second rejection"},
            format="json",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.django_db
    def test_returns_404_for_missing_submission(self, staff_client):
        client, _ = staff_client
        response = client.post(
            "/api/staff/kyc/00000000-0000-0000-0000-000000000000/reject/",
            {"reason": "Gone"},
            format="json",
        )
        assert response.status_code == status.HTTP_404_NOT_FOUND

    @pytest.mark.django_db
    def test_non_staff_is_forbidden(self, user_factory, authenticated_client, kyc_submission_factory):
        user = user_factory(email="rejectforbidden@example.com", username="rejectforbidden")
        submission = kyc_submission_factory(user)

        response = authenticated_client.post(
            f"/api/staff/kyc/{submission.id}/reject/",
            {"reason": "Forbidden"},
            format="json",
        )

        assert response.status_code == status.HTTP_403_FORBIDDEN
