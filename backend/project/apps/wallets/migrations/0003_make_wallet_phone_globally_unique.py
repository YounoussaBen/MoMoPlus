from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("wallets", "0002_add_paystack_fields"),
    ]

    operations = [
        migrations.RemoveConstraint(
            model_name="wallet",
            name="unique_user_phone",
        ),
        migrations.AddConstraint(
            model_name="wallet",
            constraint=models.UniqueConstraint(
                fields=("phone_number",),
                name="unique_wallet_phone_number",
            ),
        ),
    ]
