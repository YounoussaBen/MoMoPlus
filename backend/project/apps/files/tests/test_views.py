from __future__ import annotations

from uuid import uuid4

import pytest
from django.core.files.uploadedfile import SimpleUploadedFile
from rest_framework import status

from project.apps.files.models import FileAsset
from project.apps.files.services import create_file_asset


def build_claims(email: str, *, sub: str | None = None, is_staff: bool = False) -> dict[str, object]:
    return {
        "sub": sub or str(uuid4()),
        "email": email,
        "user_metadata": {
            "first_name": email.split("@", maxsplit=1)[0].title(),
            "last_name": "User",
        },
        "app_metadata": {
            "is_staff": is_staff,
        },
    }


@pytest.fixture
def media_root(settings, tmp_path):
    settings.MEDIA_ROOT = tmp_path
    return tmp_path


class TestFileAssetViews:
    @pytest.mark.django_db
    def test_upload_creates_private_document_by_default(self, authenticated_client, media_root):
        uploaded_file = SimpleUploadedFile("notes.txt", b"hello world", content_type="text/plain")

        response = authenticated_client.post(
            "/api/files/",
            {
                "file": uploaded_file,
                "kind": FileAsset.FileKind.DOCUMENT,
            },
            format="multipart",
        )

        assert response.status_code == status.HTTP_201_CREATED
        asset = FileAsset.objects.get(pk=response.data["id"])
        assert asset.visibility == FileAsset.Visibility.PRIVATE
        assert asset.owner.email == "supabase@example.com"
        assert asset.status == FileAsset.Status.READY

    @pytest.mark.django_db
    def test_upload_rejects_invalid_visibility_for_passport(self, authenticated_client, media_root):
        uploaded_file = SimpleUploadedFile("passport.pdf", b"passport", content_type="application/pdf")

        response = authenticated_client.post(
            "/api/files/",
            {
                "file": uploaded_file,
                "kind": FileAsset.FileKind.PASSPORT,
                "visibility": FileAsset.Visibility.AUTHENTICATED,
            },
            format="multipart",
        )

        assert response.status_code == status.HTTP_400_BAD_REQUEST
        assert "passport files only support" in str(response.data).lower()

    @pytest.mark.django_db
    def test_list_returns_only_owned_files(self, auth_client_factory, user_factory, media_root):
        owner = user_factory(email="owner@example.com", username="owner")
        other_user = user_factory(email="other@example.com", username="other")
        create_file_asset(
            owner=owner,
            uploaded_by=owner,
            uploaded_file=SimpleUploadedFile("mine.txt", b"mine", content_type="text/plain"),
            kind=FileAsset.FileKind.DOCUMENT,
        )
        create_file_asset(
            owner=other_user,
            uploaded_by=other_user,
            uploaded_file=SimpleUploadedFile("other.txt", b"other", content_type="text/plain"),
            kind=FileAsset.FileKind.DOCUMENT,
        )
        owner_client = auth_client_factory(build_claims(owner.email, sub=str(owner.supabase_user_id)))

        response = owner_client.get("/api/files/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 1
        assert response.data["results"][0]["owner"] == owner.id

    @pytest.mark.django_db
    def test_staff_list_returns_all_files(self, auth_client_factory, user_factory, media_root):
        staff_user = user_factory(
            email="staff@example.com",
            username="staff",
            is_staff=True,
            is_superuser=True,
        )
        owner = user_factory(email="owner@example.com", username="owner")
        other_user = user_factory(email="other@example.com", username="other")
        create_file_asset(
            owner=owner,
            uploaded_by=owner,
            uploaded_file=SimpleUploadedFile("mine.txt", b"mine", content_type="text/plain"),
            kind=FileAsset.FileKind.DOCUMENT,
        )
        create_file_asset(
            owner=other_user,
            uploaded_by=other_user,
            uploaded_file=SimpleUploadedFile("other.txt", b"other", content_type="text/plain"),
            kind=FileAsset.FileKind.DOCUMENT,
        )
        staff_client = auth_client_factory(
            build_claims(staff_user.email, sub=str(staff_user.supabase_user_id), is_staff=True)
        )

        response = staff_client.get("/api/files/")

        assert response.status_code == status.HTTP_200_OK
        assert response.data["count"] == 2

    @pytest.mark.django_db
    def test_staff_filters_and_search_across_all_files(self, auth_client_factory, user_factory, media_root):
        staff_user = user_factory(
            email="staff@example.com",
            username="staff",
            is_staff=True,
            is_superuser=True,
        )
        owner = user_factory(email="owner@example.com", username="owner")
        other_user = user_factory(email="other@example.com", username="other")
        asset_one = create_file_asset(
            owner=owner,
            uploaded_by=staff_user,
            uploaded_file=SimpleUploadedFile("salary-slip.pdf", b"salary", content_type="application/pdf"),
            kind=FileAsset.FileKind.DOCUMENT,
            visibility=FileAsset.Visibility.PRIVATE,
        )
        create_file_asset(
            owner=other_user,
            uploaded_by=other_user,
            uploaded_file=SimpleUploadedFile("avatar.png", b"avatar", content_type="image/png"),
            kind=FileAsset.FileKind.PROFILE_PICTURE,
            visibility=FileAsset.Visibility.AUTHENTICATED,
        )
        staff_client = auth_client_factory(
            build_claims(staff_user.email, sub=str(staff_user.supabase_user_id), is_staff=True)
        )

        by_kind = staff_client.get("/api/files/", {"kind": FileAsset.FileKind.DOCUMENT})
        by_visibility = staff_client.get("/api/files/", {"visibility": FileAsset.Visibility.AUTHENTICATED})
        by_status = staff_client.get("/api/files/", {"status": FileAsset.Status.READY})
        by_owner = staff_client.get("/api/files/", {"owner": owner.id})
        by_uploader = staff_client.get("/api/files/", {"uploaded_by": staff_user.id})
        by_query = staff_client.get("/api/files/", {"q": "salary-slip"})

        assert by_kind.status_code == status.HTTP_200_OK
        assert by_kind.data["count"] == 1
        assert by_visibility.data["count"] == 1
        assert by_status.data["count"] == 2
        assert by_owner.data["count"] == 1
        assert by_uploader.data["count"] == 1
        assert by_query.data["count"] == 1
        assert by_query.data["results"][0]["id"] == str(asset_one.id)

    @pytest.mark.django_db
    def test_authenticated_visibility_can_be_viewed_by_other_authenticated_users(
        self,
        auth_client_factory,
        user_factory,
        media_root,
    ):
        owner = user_factory(email="owner@example.com", username="owner")
        asset = create_file_asset(
            owner=owner,
            uploaded_by=owner,
            uploaded_file=SimpleUploadedFile("avatar.png", b"avatar", content_type="image/png"),
            kind=FileAsset.FileKind.PROFILE_PICTURE,
            visibility=FileAsset.Visibility.AUTHENTICATED,
        )
        viewer_client = auth_client_factory(build_claims("viewer@example.com"))

        detail_response = viewer_client.get(f"/api/files/{asset.id}/")
        access_response = viewer_client.post(f"/api/files/{asset.id}/access-url/")

        assert detail_response.status_code == status.HTTP_200_OK
        assert access_response.status_code == status.HTTP_200_OK
        assert access_response.data["url"].startswith("http://testserver/media/")

    @pytest.mark.django_db
    def test_private_files_are_restricted_to_owner_and_staff(
        self,
        auth_client_factory,
        user_factory,
        media_root,
    ):
        owner = user_factory(email="owner@example.com", username="owner")
        staff_user = user_factory(
            email="staff@example.com",
            username="staff",
            is_staff=True,
            is_superuser=True,
        )
        asset = create_file_asset(
            owner=owner,
            uploaded_by=owner,
            uploaded_file=SimpleUploadedFile("passport.pdf", b"passport", content_type="application/pdf"),
            kind=FileAsset.FileKind.PASSPORT,
            visibility=FileAsset.Visibility.PRIVATE,
        )
        viewer_client = auth_client_factory(build_claims("viewer@example.com"))
        staff_client = auth_client_factory(
            build_claims(staff_user.email, sub=str(staff_user.supabase_user_id), is_staff=True)
        )

        denied_response = viewer_client.post(f"/api/files/{asset.id}/access-url/")
        allowed_response = staff_client.post(f"/api/files/{asset.id}/access-url/")

        assert denied_response.status_code == status.HTTP_403_FORBIDDEN
        assert allowed_response.status_code == status.HTTP_200_OK

    @pytest.mark.django_db
    def test_owner_can_update_visibility_and_delete_asset(self, auth_client_factory, user_factory, media_root):
        owner = user_factory(email="owner@example.com", username="owner")
        asset = create_file_asset(
            owner=owner,
            uploaded_by=owner,
            uploaded_file=SimpleUploadedFile("avatar.png", b"avatar", content_type="image/png"),
            kind=FileAsset.FileKind.PROFILE_PICTURE,
            visibility=FileAsset.Visibility.AUTHENTICATED,
        )
        owner_client = auth_client_factory(build_claims(owner.email, sub=str(owner.supabase_user_id)))

        patch_response = owner_client.patch(
            f"/api/files/{asset.id}/",
            {"visibility": FileAsset.Visibility.PRIVATE, "metadata": {"caption": "Updated"}},
            format="json",
        )
        delete_response = owner_client.delete(f"/api/files/{asset.id}/")

        asset.refresh_from_db()

        assert patch_response.status_code == status.HTTP_200_OK
        assert patch_response.data["visibility"] == FileAsset.Visibility.PRIVATE
        assert delete_response.status_code == status.HTTP_204_NO_CONTENT
        assert asset.status == FileAsset.Status.DELETED
        assert asset.deleted_at is not None
