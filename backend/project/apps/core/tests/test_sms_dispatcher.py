import logging

from project.apps.accounts.tasks import send_login_otp_task
from project.apps.wallets.tasks import send_wallet_otp_task
from project.integrations.sms_dispatcher import dispatch_login_otp
from project.integrations.sms_gateway import SmsDeliveryError


def test_dispatches_login_sms_outside_request_path(mocker):
    enqueue = mocker.patch("project.integrations.sms_dispatcher.send_login_otp_task.delay")

    dispatch_login_otp(phone="+233241234567", otp_code="123456")

    enqueue.assert_called_once_with(
        phone="+233241234567",
        otp_code="123456",
    )


def test_login_sms_task_delivers_through_gateway(mocker):
    deliver = mocker.patch("project.apps.accounts.tasks.send_login_otp")

    send_login_otp_task.run(phone="+233241234567", otp_code="123456")

    deliver.assert_called_once_with(phone="+233241234567", otp_code="123456")


def test_login_sms_task_logs_provider_failures_without_customer_data(mocker, caplog):
    caplog.set_level(logging.WARNING, logger="project.apps.accounts.tasks")
    mocker.patch(
        "project.apps.accounts.tasks.send_login_otp",
        side_effect=SmsDeliveryError("provider detail"),
    )

    send_login_otp_task.run(phone="+233241234567", otp_code="123456")

    assert "Background login SMS delivery failed" in caplog.text
    assert "provider detail" not in caplog.text
    assert "233241234567" not in caplog.text
    assert "123456" not in caplog.text


def test_wallet_sms_task_delivers_through_gateway(mocker):
    deliver = mocker.patch("project.apps.wallets.tasks.send_wallet_otp")

    send_wallet_otp_task.run(phone="+233241234567", otp_code="123456")

    deliver.assert_called_once_with(phone="+233241234567", otp_code="123456")
