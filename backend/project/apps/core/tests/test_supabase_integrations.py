import json
from typing import Any

from django.core.files.base import ContentFile

from project.integrations.supabase import SupabaseAuthClient, SupabaseStorageClient
from project.storage_backends import SupabaseStorage


class TestSupabaseAuthClient:
    def test_verify_access_token_uses_auth_api_for_hs_tokens(self, settings, mocker):
        settings.SUPABASE_URL = "https://example.supabase.co"
        mocker.patch("project.integrations.supabase.jwt.get_unverified_header", return_value={"alg": "HS256"})
        expected = {"sub": "user-id"}
        verify = mocker.patch.object(SupabaseAuthClient, "_verify_via_auth_api", return_value=expected)

        claims = SupabaseAuthClient().verify_access_token("token")

        assert claims == expected
        verify.assert_called_once_with("token")

    def test_verify_access_token_uses_jwks_for_asymmetric_tokens(self, settings, mocker):
        settings.SUPABASE_URL = "https://example.supabase.co"
        mocker.patch("project.integrations.supabase.jwt.get_unverified_header", return_value={"alg": "RS256"})
        expected = {"sub": "user-id"}
        verify = mocker.patch.object(SupabaseAuthClient, "_verify_via_jwks", return_value=expected)

        claims = SupabaseAuthClient().verify_access_token("token")

        assert claims == expected
        verify.assert_called_once_with("token", "RS256")


class TestSupabaseStorageClient:
    def test_public_url_uses_bucket_and_base_path(self, settings):
        settings.SUPABASE_URL = "https://example.supabase.co"
        settings.SUPABASE_SERVICE_ROLE_KEY = "service-role"
        settings.SUPABASE_STORAGE_BUCKET = "media"
        settings.SUPABASE_STORAGE_BASE_PATH = "uploads"
        settings.SUPABASE_STORAGE_PUBLIC = True

        client = SupabaseStorageClient()

        assert client.url("avatars/me.png") == (
            "https://example.supabase.co/storage/v1/object/public/media/uploads/avatars/me.png"
        )

    def test_signed_url_uses_storage_api_response(self, settings, mocker):
        settings.SUPABASE_URL = "https://example.supabase.co"
        settings.SUPABASE_SERVICE_ROLE_KEY = "service-role"
        settings.SUPABASE_STORAGE_BUCKET = "media"
        settings.SUPABASE_STORAGE_BASE_PATH = ""
        settings.SUPABASE_STORAGE_PUBLIC = False
        settings.SUPABASE_STORAGE_SIGNED_URL_EXPIRY = 900
        request = mocker.patch(
            "project.integrations.supabase._request",
            return_value=(json.dumps({"signedURL": "/object/sign/media/report.pdf?token=abc"}).encode("utf-8"), {}),
        )

        client = SupabaseStorageClient()

        assert (
            client.url("report.pdf") == "https://example.supabase.co/storage/v1/object/sign/media/report.pdf?token=abc"
        )
        request.assert_called_once()

    def test_create_signed_upload_returns_upload_target(self, settings, mocker):
        settings.SUPABASE_URL = "https://example.supabase.co"
        settings.SUPABASE_SERVICE_ROLE_KEY = "service-role"
        settings.SUPABASE_STORAGE_BUCKET = "media"
        settings.SUPABASE_STORAGE_BASE_PATH = "uploads"
        request = mocker.patch(
            "project.integrations.supabase._request",
            return_value=(
                json.dumps(
                    {
                        "path": "uploads/documents/report.pdf",
                        "token": "upload-token",
                        "signedURL": "/object/upload/sign/media/uploads/documents/report.pdf?token=upload-token",
                    }
                ).encode("utf-8"),
                {},
            ),
        )

        client = SupabaseStorageClient()
        upload_target = client.create_signed_upload("documents/report.pdf")

        assert upload_target == {
            "path": "uploads/documents/report.pdf",
            "token": "upload-token",
            "signed_url": (
                "https://example.supabase.co/storage/v1/object/upload/sign/media/uploads/documents/report.pdf"
                "?token=upload-token"
            ),
            "expires_in": 7200,
        }
        request.assert_called_once()


class TestSupabaseStorageBackend:
    def test_save_uploads_content_via_client(self, mocker):
        upload = mocker.patch("project.storage_backends.SupabaseStorageClient.upload")
        storage: Any = SupabaseStorage.__new__(SupabaseStorage)
        storage.client = mocker.Mock()
        storage.client.upload = upload
        content = ContentFile(b"hello world")
        content.content_type = "text/plain"

        saved_name = storage._save("greetings/hello.txt", content)

        assert saved_name == "greetings/hello.txt"
        upload.assert_called_once_with("greetings/hello.txt", b"hello world", content_type="text/plain")
