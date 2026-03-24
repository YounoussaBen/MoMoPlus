from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("wallets", "0004_remove_wallet_paystack_subaccount_code"),
    ]

    operations = [
        migrations.RemoveConstraint(
            model_name="wallet",
            name="unique_wallet_phone_number",
        ),
        migrations.AddConstraint(
            model_name="wallet",
            constraint=models.UniqueConstraint(
                fields=("user", "phone_number"),
                name="unique_user_phone",
            ),
        ),
    ]
