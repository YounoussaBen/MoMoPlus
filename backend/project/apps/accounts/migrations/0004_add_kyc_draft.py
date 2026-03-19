from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0003_add_kyc_status"),
    ]

    operations = [
        migrations.AddField(
            model_name="user",
            name="kyc_draft",
            field=models.JSONField(default=dict, blank=True),
        ),
    ]
