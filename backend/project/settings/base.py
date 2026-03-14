from datetime import timedelta
from pathlib import Path
from urllib.parse import parse_qsl, urlencode, urlsplit, urlunsplit

import dj_database_url
from decouple import Csv, config

# Build paths inside the project like this: BASE_DIR / 'subdir'.
BASE_DIR = Path(__file__).resolve().parent.parent

# ==============================================================================
# CORE SETTINGS
# ==============================================================================

SECRET_KEY = config("SECRET_KEY", default="django-insecure$project.settings.local")

DEBUG = config("DEBUG", default=True, cast=bool)

ALLOWED_HOSTS = config("ALLOWED_HOSTS", default="127.0.0.1,localhost", cast=Csv())

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Third party
    "rest_framework",
    "corsheaders",
    "drf_spectacular",
    "django_celery_beat",
    "django_celery_results",
    # Project apps
    "project.apps.accounts",
    "project.apps.core",
    "project.apps.api",
    "project.apps.files",
]

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# Add after DEFAULT_AUTO_FIELD
AUTH_USER_MODEL = "accounts.User"

# ==============================================================================

ROOT_URLCONF = "project.urls"

INTERNAL_IPS = ["127.0.0.1"]

WSGI_APPLICATION = "project.wsgi.application"

# ==============================================================================
# MIDDLEWARE SETTINGS
# ==============================================================================

MIDDLEWARE = [
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

# ==============================================================================
# TEMPLATES SETTINGS
# ==============================================================================

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.debug",
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# ==============================================================================
# DATABASES SETTINGS
# ==============================================================================


def _normalize_database_url(value: str) -> str:
    if not value:
        return value

    parsed = urlsplit(value)
    if not parsed.query:
        return value

    filtered_query = [
        (key, query_value)
        for key, query_value in parse_qsl(parsed.query, keep_blank_values=True)
        if key.lower() not in {"pgbouncer"}
    ]

    if len(filtered_query) == len(parse_qsl(parsed.query, keep_blank_values=True)):
        return value

    return urlunsplit(
        (
            parsed.scheme,
            parsed.netloc,
            parsed.path,
            urlencode(filtered_query, doseq=True),
            parsed.fragment,
        )
    )


SUPABASE_DB_URL = config("SUPABASE_DB_URL", default="")
DATABASE_URL = _normalize_database_url(SUPABASE_DB_URL or config("DATABASE_URL", default="sqlite:///db.sqlite3"))

DATABASES = {
    "default": dj_database_url.config(
        default=DATABASE_URL,
        conn_max_age=600,
        ssl_require=config("SUPABASE_DB_SSL_REQUIRE", default=bool(SUPABASE_DB_URL), cast=bool),
    )
}

# ==============================================================================
# AUTHENTICATION AND AUTHORIZATION SETTINGS
# ==============================================================================

AUTH_PASSWORD_VALIDATORS = [
    {
        "NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.CommonPasswordValidator",
    },
    {
        "NAME": "django.contrib.auth.password_validation.NumericPasswordValidator",
    },
]

# ==============================================================================
# I18N AND L10N SETTINGS
# ==============================================================================

LANGUAGE_CODE = config("LANGUAGE_CODE", default="en-us")

TIME_ZONE = config("TIME_ZONE", default="UTC")

USE_I18N = True

USE_L10N = True

USE_TZ = True

LOCALE_PATHS = [BASE_DIR / "locale"]

# ==============================================================================
# STATIC FILES SETTINGS
# ==============================================================================

STATIC_URL = "/static/"

STATIC_ROOT = BASE_DIR.parent / "staticfiles"

STATICFILES_DIRS = [BASE_DIR / "static"]

STATICFILES_FINDERS = (
    "django.contrib.staticfiles.finders.FileSystemFinder",
    "django.contrib.staticfiles.finders.AppDirectoriesFinder",
)

# ==============================================================================
# MEDIA FILES SETTINGS
# ==============================================================================

MEDIA_URL = "/media/"

MEDIA_ROOT = BASE_DIR.parent / "media"

# ==============================================================================
# THIRD-PARTY SETTINGS
# ==============================================================================

# ==============================================================================
# FIRST-PARTY SETTINGS
# ==============================================================================

PROJECT_ENVIRONMENT = config("PROJECT_ENVIRONMENT", default="local")


# ==============================================================================
# DJANGO REST FRAMEWORK
# ==============================================================================

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "project.apps.accounts.authentication.HybridAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

# ==============================================================================
# API DOCUMENTATION
# ==============================================================================

SPECTACULAR_SETTINGS = {
    "TITLE": "MoMoPlus API",
    "DESCRIPTION": "Modern Django REST API",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SWAGGER_UI_SETTINGS": {
        "displayRequestDuration": True,
        "persistAuthorization": True,
    },
}

# ==============================================================================
# DJANGO STAFF JWT SETTINGS
# ==============================================================================

SIMPLE_JWT = {
    "ALGORITHM": "HS256",
    "SIGNING_KEY": config("DJANGO_JWT_SIGNING_KEY", default=SECRET_KEY),
    "VERIFYING_KEY": "",
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=8),
    "AUTH_HEADER_TYPES": ("Bearer",),
}

# ==============================================================================
# SUPABASE SETTINGS
# ==============================================================================

SUPABASE_URL = config("SUPABASE_URL", default="")
SUPABASE_ANON_KEY = config("SUPABASE_ANON_KEY", default="")
SUPABASE_SERVICE_ROLE_KEY = config("SUPABASE_SERVICE_ROLE_KEY", default="")
SUPABASE_JWT_AUDIENCE = config("SUPABASE_JWT_AUDIENCE", default="authenticated")
SUPABASE_JWT_ISSUER = config(
    "SUPABASE_JWT_ISSUER",
    default=f"{SUPABASE_URL.rstrip('/')}/auth/v1" if SUPABASE_URL else "",
)
SUPABASE_JWKS_URL = config(
    "SUPABASE_JWKS_URL",
    default=f"{SUPABASE_URL.rstrip('/')}/auth/v1/.well-known/jwks.json" if SUPABASE_URL else "",
)
SUPABASE_HTTP_TIMEOUT = config("SUPABASE_HTTP_TIMEOUT", default=10, cast=int)
SUPABASE_STORAGE_BUCKET = config("SUPABASE_STORAGE_BUCKET", default="")
SUPABASE_STORAGE_BASE_PATH = config("SUPABASE_STORAGE_BASE_PATH", default="")
SUPABASE_STORAGE_PUBLIC = config("SUPABASE_STORAGE_PUBLIC", default=False, cast=bool)
SUPABASE_STORAGE_SIGNED_URL_EXPIRY = config("SUPABASE_STORAGE_SIGNED_URL_EXPIRY", default=3600, cast=int)

if SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY and SUPABASE_STORAGE_BUCKET:
    STORAGES = {
        "default": {
            "BACKEND": "project.storage_backends.SupabaseStorage",
        },
        "staticfiles": {
            "BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage",
        },
    }

# ==============================================================================
# CORS SETTINGS
# ==============================================================================

# Environment-specific CORS origins
CORS_ALLOWED_ORIGINS = config(
    "CORS_ALLOWED_ORIGINS", default="http://localhost:3000,http://127.0.0.1:3000", cast=Csv()
)

# Security headers
CORS_ALLOW_CREDENTIALS = True
CORS_PREFLIGHT_MAX_AGE = 86400  # 24 hours

# Restrict methods and headers
CORS_ALLOWED_ORIGIN_REGEXES = [
    r"^https://.*\.yourdomain\.com$",  # Allow subdomains in production
]

CORS_ALLOW_HEADERS = [
    "accept",
    "accept-encoding",
    "authorization",
    "content-type",
    "dnt",
    "origin",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
]

CORS_ALLOW_METHODS = [
    "DELETE",
    "GET",
    "OPTIONS",
    "PATCH",
    "POST",
    "PUT",
]

# Don't allow all origins in production
CORS_ALLOW_ALL_ORIGINS = config("CORS_ALLOW_ALL_ORIGINS", default=True, cast=bool)


# ==============================================================================
# CELERY SETTINGS
# ==============================================================================

CELERY_BROKER_URL = config("CELERY_BROKER_URL", default="redis://localhost:6379/0")
CELERY_RESULT_BACKEND = config("CELERY_RESULT_BACKEND", default="redis://localhost:6379/0")
CELERY_ACCEPT_CONTENT = ["json"]
CELERY_TASK_SERIALIZER = "json"
CELERY_RESULT_SERIALIZER = "json"
CELERY_TIMEZONE = TIME_ZONE
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"

# ==============================================================================
# CSRF SETTINGS
# ==============================================================================

# CSRF trusted origins
CSRF_TRUSTED_ORIGINS = config(
    "CSRF_TRUSTED_ORIGINS", default="http://localhost:3000,http://127.0.0.1:3000", cast=Csv()
)

# CSRF cookie security
CSRF_COOKIE_SECURE = config("CSRF_COOKIE_SECURE", default=False, cast=bool)
CSRF_COOKIE_HTTPONLY = config("CSRF_COOKIE_HTTPONLY", default=True, cast=bool)
CSRF_COOKIE_SAMESITE = config("CSRF_COOKIE_SAMESITE", default="Lax")
CSRF_COOKIE_AGE = config("CSRF_COOKIE_AGE", default=3600, cast=int)  # 1 hour

# CSRF failure view
CSRF_FAILURE_VIEW = "project.apps.core.views.csrf_failure"
