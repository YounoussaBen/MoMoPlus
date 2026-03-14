from pathlib import Path

from project.settings.base import _normalize_database_url
from project.settings.tests import _build_test_database_config, _default_test_database_url


class TestDatabaseUrlNormalization:
    def test_removes_pgbouncer_flag(self):
        url = (
            "postgresql://postgres.example:secret@aws-1-us-east-1.pooler.supabase.com:6543/" "postgres?pgbouncer=true"
        )

        assert _normalize_database_url(url) == (
            "postgresql://postgres.example:secret@aws-1-us-east-1.pooler.supabase.com:6543/postgres"
        )

    def test_preserves_supported_query_parameters(self):
        url = (
            "postgresql://postgres.example:secret@aws-1-us-east-1.pooler.supabase.com:6543/"
            "postgres?sslmode=require&pgbouncer=true&target_session_attrs=read-write"
        )

        assert _normalize_database_url(url) == (
            "postgresql://postgres.example:secret@aws-1-us-east-1.pooler.supabase.com:6543/"
            "postgres?sslmode=require&target_session_attrs=read-write"
        )


class TestTestDatabaseSettings:
    def test_defaults_to_local_sqlite_database(self):
        database_config = _build_test_database_config(_default_test_database_url())

        assert database_config["ENGINE"] == "django.db.backends.sqlite3"
        assert Path(str(database_config["NAME"])).name == "db.sqlite3"

    def test_honors_explicit_test_database_url(self):
        database_config = _build_test_database_config("sqlite:////tmp/momoplus-test.sqlite3")

        assert database_config["ENGINE"] == "django.db.backends.sqlite3"
        assert database_config["NAME"] == "/tmp/momoplus-test.sqlite3"
