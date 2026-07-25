from unittest.mock import patch

from django.test import override_settings

from project.integrations import paystack


@override_settings(PAYSTACK_PAYMENT_EMAIL="billing@momoplus.com")
def test_mobile_money_charge_uses_configured_payment_email():
    with patch("project.integrations.paystack._post") as mock_post:
        mock_post.return_value = {
            "status": True,
            "data": {
                "reference": "PAYSTACK_EMAIL_TEST",
                "status": "pay_offline",
            },
        }

        paystack.charge_mobile_money(
            amount_pesewas=1000,
            phone="0551234987",
            provider="mtn",
            reference="PAYSTACK_EMAIL_TEST",
        )

    _, payload = mock_post.call_args.args
    assert payload["email"] == "billing@momoplus.com"
