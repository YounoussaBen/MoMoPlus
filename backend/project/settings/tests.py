# flake8: noqa
import dj_database_url
from dj_database_url import DBConfig
from decouple import config

from .base import *

PASSWORD_HASHERS = ["django.contrib.auth.hashers.MD5PasswordHasher"]


class DisableMigrations:
    def __contains__(self, item):
        return True

    def __getitem__(self, item):
        return None


MIGRATION_MODULES = DisableMigrations()


def _default_test_database_url() -> str:
    test_db_path = (BASE_DIR.parent / "db.sqlite3").resolve()
    return f"sqlite:///{test_db_path}"


def _build_test_database_config(database_url: str) -> DBConfig:
    return dj_database_url.parse(database_url, conn_max_age=0, ssl_require=False)


# Keep the default test database local so pytest does not create/drop databases
# against the shared Supabase pooler defined in the development environment.
DATABASES = {"default": _build_test_database_config(config("TEST_DATABASE_URL", default=_default_test_database_url()))}

PAYSTACK_SECRET_KEY = "sk_test_mocked"
