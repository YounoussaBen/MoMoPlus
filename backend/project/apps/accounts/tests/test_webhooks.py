import base64
import hashlib
import hmac
import json
import time

import pytest
from rest_framework import status

from project.integrations.sms_dispatcher import SmsDispatchError

SECRET_BYTES = b"test-hook-secret"
HOOK_SECRET = f"v1,whsec_{base64.b64encode(SECRET_BYTES).decode()}"


def _signed_headers(raw_body: bytes, *, timestamp: int | None = None, webhook_id: str = "msg_test"):
    resolved_timestamp = timestamp or int(time.time())
    signed = f"{webhook_id}.{resolved_timestamp}.{raw_body.decode()}".encode()
    signature = base64.b64encode(hmac.new(SECRET_BYTES, signed, hashlib.sha256).digest()).decode()
    return {
        "HTTP_WEBHOOK_ID": webhook_id,
        "HTTP_WEBHOOK_TIMESTAMP": str(resolved_timestamp),
        "HTTP_WEBHOOK_SIGNATURE": f"v1,{signature}",
    }


def _payload() -> bytes:
    return json.dumps(
        {"user": {"phone": "+233241234567"}, "sms": {"otp": "123456"}},
        separators=(",", ":"),
    ).encode()


class TestSupabaseSendSmsHook:
    @pytest.fixture(autouse=True)
    def _hook_settings(self, settings):
        settings.SEND_SMS_HOOK_SECRET = HOOK_SECRET
        settings.SEND_SMS_HOOK_TOLERANCE_SECONDS = 300

    def test_accepts_valid_signature_and_sends_supabase_code(self, api_client, mocker):
        raw_body = _payload()
        dispatch = mocker.patch("project.apps.accounts.views.dispatch_login_otp")

        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=raw_body,
            content_type="application/json",
            **_signed_headers(raw_body),
        )

        assert response.status_code == status.HTTP_200_OK
        assert response.data == {}
        dispatch.assert_called_once_with(phone="+233241234567", otp_code="123456")

    def test_rejects_altered_raw_body(self, api_client, mocker):
        original = _payload()
        altered = original.replace(b"123456", b"654321")
        dispatch = mocker.patch("project.apps.accounts.views.dispatch_login_otp")

        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=altered,
            content_type="application/json",
            **_signed_headers(original),
        )

        assert response.status_code == status.HTTP_401_UNAUTHORIZED
        dispatch.assert_not_called()

    @pytest.mark.parametrize(
        "headers",
        [
            {},
            {"HTTP_WEBHOOK_ID": "msg_test"},
            {
                "HTTP_WEBHOOK_ID": "msg_test",
                "HTTP_WEBHOOK_TIMESTAMP": "not-a-timestamp",
                "HTTP_WEBHOOK_SIGNATURE": "v1,invalid",
            },
        ],
    )
    def test_rejects_missing_or_malformed_signature_headers(self, api_client, headers):
        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=_payload(),
            content_type="application/json",
            **headers,
        )
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    @pytest.mark.parametrize("offset", [-301, 301])
    def test_rejects_timestamp_outside_replay_window(self, api_client, offset):
        raw_body = _payload()
        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=raw_body,
            content_type="application/json",
            **_signed_headers(raw_body, timestamp=int(time.time()) + offset),
        )
        assert response.status_code == status.HTTP_401_UNAUTHORIZED

    def test_rejects_malformed_json_after_valid_signature(self, api_client):
        raw_body = b'{"user":'
        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=raw_body,
            content_type="application/json",
            **_signed_headers(raw_body),
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    @pytest.mark.parametrize(
        "event",
        [
            {},
            {"user": {}, "sms": {"otp": "123456"}},
            {"user": {"phone": "+233241234567"}, "sms": {"otp": "12"}},
            {"user": {"phone": "+12025550123"}, "sms": {"otp": "123456"}},
        ],
    )
    def test_rejects_invalid_payload_after_signature_verification(self, api_client, event):
        raw_body = json.dumps(event, separators=(",", ":")).encode()
        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=raw_body,
            content_type="application/json",
            **_signed_headers(raw_body),
        )
        assert response.status_code == status.HTTP_400_BAD_REQUEST

    def test_surfaces_dispatch_failure_without_exposing_details(self, api_client, mocker):
        raw_body = _payload()
        mocker.patch(
            "project.apps.accounts.views.dispatch_login_otp",
            side_effect=SmsDispatchError("secret dispatch response"),
        )

        response = api_client.generic(
            "POST",
            "/api/auth/hooks/send-sms/",
            data=raw_body,
            content_type="application/json",
            **_signed_headers(raw_body),
        )

        assert response.status_code == status.HTTP_503_SERVICE_UNAVAILABLE
        assert "secret dispatch response" not in str(response.data)
