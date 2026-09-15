import uuid

from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0007_user_deactivation_fields"),
    ]

    operations = [
        migrations.AddField(
            model_name="loanguarantor",
            name="is_verified",
            field=models.BooleanField(default=False),
        ),
        migrations.AddIndex(
            model_name="loanguarantor",
            index=models.Index(fields=["user", "is_verified"], name="accounts_lo_user_id_51c70c_idx"),
        ),
        migrations.CreateModel(
            name="LoanGuarantorOtp",
            fields=[
                (
                    "id",
                    models.UUIDField(default=uuid.uuid4, editable=False, primary_key=True, serialize=False),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                ("code", models.CharField(max_length=6)),
                ("expires_at", models.DateTimeField()),
                ("used", models.BooleanField(default=False)),
                (
                    "guarantor",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="otps",
                        to="accounts.loanguarantor",
                    ),
                ),
            ],
            options={
                "ordering": ["-created_at"],
                "abstract": False,
                "indexes": [
                    models.Index(
                        fields=["guarantor", "used", "expires_at"],
                        name="accounts_lo_guarantor_otp_idx",
                    ),
                ],
            },
        ),
    ]
