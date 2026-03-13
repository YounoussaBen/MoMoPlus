from django.apps import AppConfig


class AccountsConfig(AppConfig):
    default_auto_field = "django.db.models.BigAutoField"
    name = "project.apps.accounts"

    def ready(self) -> None:
        # Import schema extensions so drf-spectacular can discover the bearer auth definition.
        from . import authentication  # noqa: F401
