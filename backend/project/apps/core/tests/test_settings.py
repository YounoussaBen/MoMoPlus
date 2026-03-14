from project.settings.base import _normalize_database_url


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
