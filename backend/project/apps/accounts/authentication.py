from __future__ import annotations

import jwt
from drf_spectacular.extensions import OpenApiAuthenticationExtension
from rest_framework import exceptions
from rest_framework.authentication import BaseAuthentication, get_authorization_header
from rest_framework_simplejwt.authentication import JWTAuthentication

from project.integrations.supabase import (
    SupabaseAuthClient,
    SupabaseAuthenticationError,
    SupabaseConfigurationError,
)

from .services import sync_user_from_supabase_claims


class StaffJWTAuthentication(JWTAuthentication):
    """Authenticates local Django staff tokens."""

    def authenticate_staff_token(self, raw_token: str):
        try:
            validated_token = self.get_validated_token(raw_token.encode("utf-8"))
            user = self.get_user(validated_token)
        except exceptions.AuthenticationFailed:
            raise
        except Exception as exc:
            raise exceptions.AuthenticationFailed("Invalid staff authentication token.") from exc

        if not validated_token.get("staff_session"):
            raise exceptions.AuthenticationFailed("Invalid staff authentication token.")

        if not user.is_active:
            raise exceptions.AuthenticationFailed("User account is disabled.")

        if not (user.is_staff or user.is_superuser):
            raise exceptions.AuthenticationFailed("Staff access is required.")

        return (user, validated_token)


class HybridAuthentication(BaseAuthentication):
    """Authenticates API requests using either local staff JWTs or Supabase tokens."""

    www_authenticate_realm = "api"

    def authenticate(self, request):
        header = get_authorization_header(request).split()
        if not header:
            return None

        if header[0].lower() != b"bearer":
            return None

        if len(header) != 2:
            raise exceptions.AuthenticationFailed("Invalid Authorization header.")

        token = header[1].decode("utf-8")

        if self._looks_like_staff_token(token):
            return StaffJWTAuthentication().authenticate_staff_token(token)

        try:
            claims = SupabaseAuthClient().verify_access_token(token)
            user = sync_user_from_supabase_claims(claims)
        except SupabaseConfigurationError as exc:
            raise exceptions.AuthenticationFailed(str(exc)) from exc
        except (SupabaseAuthenticationError, ValueError) as exc:
            raise exceptions.AuthenticationFailed(str(exc)) from exc

        if not user.is_active:
            raise exceptions.AuthenticationFailed("User account is disabled.")

        return (user, claims)

    def authenticate_header(self, request) -> str:
        return f'Bearer realm="{self.www_authenticate_realm}"'

    def _looks_like_staff_token(self, token: str) -> bool:
        try:
            claims = jwt.decode(
                token,
                options={
                    "verify_signature": False,
                    "verify_exp": False,
                    "verify_aud": False,
                },
            )
        except jwt.PyJWTError:
            return False

        return bool(claims.get("staff_session")) or claims.get("auth_source") == "django_staff"


class SupabaseAuthenticationScheme(OpenApiAuthenticationExtension):
    target_class = "project.apps.accounts.authentication.HybridAuthentication"
    name = "SupabaseBearerAuth"

    def get_security_definition(self, auto_schema):
        return {
            "type": "http",
            "scheme": "bearer",
            "bearerFormat": "JWT",
            "description": "Supabase access token for app users or Django-issued staff token for dashboard users.",
        }
