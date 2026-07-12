import logging

from project.integrations.sms_dispatcher import dispatch_login_otp
from project.integrations.sms_gateway import SmsDeliveryError


def test_dispatches_login_sms_outside_request_path(mocker):
    submit = mocker.patch("project.integrations.sms_dispatcher._executor.submit")

    dispatch_login_otp(phone="+233241234567", otp_code="123456")

    submit.assert_called_once()
    assert submit.call_args.kwargs == {
        "phone": "+233241234567",
        "otp_code": "123456",
    }


def test_background_delivery_failure_is_logged_without_customer_data(mocker, caplog):
    caplog.set_level(logging.WARNING, logger="project.integrations.sms_dispatcher")
    mocker.patch(
        "project.integrations.sms_dispatcher.send_login_otp",
        side_effect=SmsDeliveryError("provider detail"),
    )
    mocker.patch(
        "project.integrations.sms_dispatcher._executor.submit",
        side_effect=lambda function, **kwargs: function(**kwargs),
    )

    dispatch_login_otp(phone="+233241234567", otp_code="123456")

    assert "Background login SMS delivery failed" in caplog.text
    assert "provider detail" not in caplog.text
    assert "233241234567" not in caplog.text
    assert "123456" not in caplog.text
