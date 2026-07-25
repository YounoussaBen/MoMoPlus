from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("transactions", "0001_initial"),
    ]

    operations = [
        migrations.AddField(
            model_name="physicaltransaction",
            name="verification_attempts",
            field=models.PositiveSmallIntegerField(default=0),
        ),
    ]
