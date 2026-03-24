from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("wallets", "0003_make_wallet_phone_globally_unique"),
    ]

    operations = [
        migrations.RemoveField(
            model_name="wallet",
            name="paystack_subaccount_code",
        ),
    ]
