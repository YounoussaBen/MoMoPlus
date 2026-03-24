# flake8: noqa

from .base import *

ALLOWED_HOSTS = list(dict.fromkeys([*ALLOWED_HOSTS, "10.0.2.2"]))

INSTALLED_APPS += ["debug_toolbar"]

MIDDLEWARE.insert(0, "debug_toolbar.middleware.DebugToolbarMiddleware")

# ==============================================================================
# EMAIL SETTINGS
# ==============================================================================

EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"
