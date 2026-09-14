import pytest
from rest_framework import status

from project.apps.files.models import FileAsset
from project.apps.kyc.models import KycSubmission
from project.apps.kyc.services import approve_kyc

from .conftest import make_ghana_card_record, make_submission_asset_ids


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
    def test_search_by_user_phone(self, user_factory, staff_client, kyc_submission_factory):
        client, _ = staff_client
        user = user_factory(email="findkyc@example.com", username="findkyc", phone="+233241234567")
        kyc_submission_factory(user)

        response = client.get("/api/staff/kyc/?search=241234567")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["user"]["phone"] == "+233241234567"

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


class TestStaffGhanaCardRegistry:
    @pytest.mark.django_db
    def test_staff_can_list_registered_cards(self, staff_client, media_root):
        client, staff = staff_client
        make_ghana_card_record(staff)

        response = client.get("/api/staff/kyc/ghana-cards/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["masked_card_number"] == "GHA-******34"
        assert response.data["results"][0]["first_names"] == "Kwame"

    @pytest.mark.django_db
    def test_staff_can_create_card_from_ready_images(self, staff_client, media_root):
        client, staff = staff_client
        asset_ids = make_submission_asset_ids(staff)

        response = client.post(
            "/api/staff/kyc/ghana-cards/",
            {
                "card_number": "GHA-728430143-5",
                "first_names": "Ama",
                "surname": "Owusu",
                "date_of_birth": "2001-01-02",
                "sex": "f",
                "card_front_id": asset_ids["id_front_id"],
                "card_back_id": asset_ids["id_back_id"],
            },
            format="json",
        )

        assert response.status_code == status.HTTP_201_CREATED
        assert response.data["card_number"] == "GHA-728430143-5"
        assert response.data["sex"] == "F"

    @pytest.mark.django_db
    def test_non_staff_cannot_manage_registry(self, authenticated_client):
        response = authenticated_client.get("/api/staff/kyc/ghana-cards/")

        assert response.status_code == status.HTTP_403_FORBIDDEN

    @pytest.mark.django_db
    def test_staff_can_deactivate_registered_card(self, staff_client, media_root):
        client, staff = staff_client
        record = make_ghana_card_record(staff)

        response = client.patch(
            f"/api/staff/kyc/ghana-cards/{record.id}/",
            {"is_active": False},
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["is_active"] is False
        record.refresh_from_db()
        assert record.is_active is False

    @pytest.mark.django_db
    def test_staff_can_view_registry_detail_with_images(self, staff_client, media_root):
        client, staff = staff_client
        record = make_ghana_card_record(staff)

        response = client.get(f"/api/staff/kyc/ghana-cards/{record.id}/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["card_number"] == record.card_number
        assert response.data["card_front_url"]["url"]
        assert response.data["card_back_url"]["url"]

    @pytest.mark.django_db
    def test_staff_can_edit_registry_details_and_replace_images(self, staff_client, media_root):
        client, staff = staff_client
        record = make_ghana_card_record(staff)
        old_front_id = record.card_front_id
        old_back_id = record.card_back_id
        replacement_assets = make_submission_asset_ids(staff)

        response = client.patch(
            f"/api/staff/kyc/ghana-cards/{record.id}/",
            {
                "card_number": "GHA-728430143-5",
                "first_names": "Ama",
                "surname": "Owusu",
                "date_of_birth": "2001-01-02",
                "sex": "f",
                "card_front_id": replacement_assets["id_front_id"],
                "card_back_id": replacement_assets["id_back_id"],
            },
            format="json",
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data["card_number"] == "GHA-728430143-5"
        assert response.data["first_names"] == "Ama"
        assert response.data["surname"] == "Owusu"
        assert response.data["sex"] == "F"
        record.refresh_from_db()
        assert str(record.card_front_id) == replacement_assets["id_front_id"]
        assert str(record.card_back_id) == replacement_assets["id_back_id"]
        assert FileAsset.objects.get(pk=old_front_id).status == FileAsset.Status.DELETED
        assert FileAsset.objects.get(pk=old_back_id).status == FileAsset.Status.DELETED

    @pytest.mark.django_db
    def test_staff_can_delete_registry_record_and_images(self, staff_client, media_root):
        client, staff = staff_client
        record = make_ghana_card_record(staff)
        front_id = record.card_front_id
        back_id = record.card_back_id

        response = client.delete(f"/api/staff/kyc/ghana-cards/{record.id}/")

        assert response.status_code == status.HTTP_204_NO_CONTENT
        assert not type(record).objects.filter(pk=record.id).exists()
        assert FileAsset.objects.get(pk=front_id).status == FileAsset.Status.DELETED
        assert FileAsset.objects.get(pk=back_id).status == FileAsset.Status.DELETED

    @pytest.mark.django_db
    def test_non_staff_cannot_edit_or_delete_registry_record(
        self,
        user_factory,
        authenticated_client,
        staff_client,
        media_root,
    ):
        _, staff = staff_client
        record = make_ghana_card_record(staff)

        patch_response = authenticated_client.patch(
            f"/api/staff/kyc/ghana-cards/{record.id}/",
            {"first_names": "Not Allowed"},
            format="json",
        )
        delete_response = authenticated_client.delete(
            f"/api/staff/kyc/ghana-cards/{record.id}/",
        )

        assert patch_response.status_code == status.HTTP_403_FORBIDDEN
        assert delete_response.status_code == status.HTTP_403_FORBIDDEN
