import json
from email.message import Message
from urllib.error import HTTPError

import pytest
from django.test import override_settings

from project.integrations.sms_gateway import SmsDeliveryError, send_login_otp, send_sms


class _Response:
    def __init__(self, payload: dict):
        self.payload = payload

    def __enter__(self):
        return self

    def __exit__(self, *_):
        return False

    def read(self):
        return json.dumps(self.payload).encode()


@override_settings(
    ARKESEL_API_KEY="test-api-key",
    ARKESEL_SENDER_ID="MoMoPlus",
    ARKESEL_API_URL="https://sms.example.test/api/v2/sms/send",
    ARKESEL_HTTP_TIMEOUT=4,
)
def test_sends_arkesel_v2_json_with_header(mocker):
    urlopen = mocker.patch(
        "project.integrations.sms_gateway.urlopen",
        return_value=_Response({"status": "success", "data": []}),
    )

    send_sms(phone="+233241234567", message="A safe test message")

    request = urlopen.call_args.args[0]
    payload = json.loads(request.data.decode())
    assert request.full_url == "https://sms.example.test/api/v2/sms/send"
    assert request.get_header("Api-key") == "test-api-key"
    assert payload == {
        "sender": "MoMoPlus",
        "message": "A safe test message",
        "recipients": ["233241234567"],
    }
    assert urlopen.call_args.kwargs["timeout"] == 4


@override_settings(
    ARKESEL_API_KEY="test-api-key",
    ARKESEL_SENDER_ID="MoMoPlus",
    ARKESEL_API_URL="https://sms.example.test/api/v2/sms/send",
    ARKESEL_HTTP_TIMEOUT=4,
)
def test_login_template_uses_supabase_code(mocker):
    send = mocker.patch("project.integrations.sms_gateway.send_sms")
    send_login_otp(phone="+233241234567", otp_code="123456")
    message = send.call_args.kwargs["message"]
    assert "123456" in message
    assert "Do not share" in message


@override_settings(
    ARKESEL_API_KEY="test-api-key",
    ARKESEL_SENDER_ID="MoMoPlus",
    ARKESEL_API_URL="https://sms.example.test/api/v2/sms/send",
    ARKESEL_HTTP_TIMEOUT=4,
)
@pytest.mark.parametrize("provider_payload", [{}, {"status": "error"}, {"status": "failed"}])
def test_rejects_non_success_provider_payload(mocker, provider_payload):
    mocker.patch(
        "project.integrations.sms_gateway.urlopen",
        return_value=_Response(provider_payload),
    )
    with pytest.raises(SmsDeliveryError):
        send_sms(phone="+233241234567", message="Test")


@override_settings(
    ARKESEL_API_KEY="test-api-key",
    ARKESEL_SENDER_ID="MoMoPlus",
    ARKESEL_API_URL="https://sms.example.test/api/v2/sms/send",
    ARKESEL_HTTP_TIMEOUT=4,
)
def test_converts_http_failure_to_stable_exception(mocker):
    mocker.patch(
        "project.integrations.sms_gateway.urlopen",
        side_effect=HTTPError(
            "https://sms.example.test",
            422,
            "invalid",
            Message(),
            None,
        ),
    )
    with pytest.raises(SmsDeliveryError, match="provider rejected"):
        send_sms(phone="+233241234567", message="Test")
