from django.db import migrations


class Migration(migrations.Migration):
    dependencies = [
        ("loans", "0001_initial"),
    ]

    operations = [
        migrations.RenameField(
            model_name="loanpayment",
            old_name="recipient_subaccount",
            new_name="recipient_code",
        ),
    ]
