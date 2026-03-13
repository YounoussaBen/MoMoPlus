from __future__ import annotations

import json
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

import jwt
from django.conf import settings


class SupabaseError(Exception):
    """Base exception for Supabase integration failures."""


class SupabaseConfigurationError(SupabaseError):
    """Raised when required Supabase settings are missing."""


class SupabaseAuthenticationError(SupabaseError):
    """Raised when a Supabase access token cannot be verified."""


class SupabaseStorageError(SupabaseError):
    """Raised when a Supabase Storage request fails."""


def _build_url(path: str) -> str:
    return f"{settings.SUPABASE_URL.rstrip('/')}{path}"


def _require_setting(name: str) -> str:
    value = getattr(settings, name, "")
    if not value:
        raise SupabaseConfigurationError(f"{name} must be configured.")
    return value


def _decode_error_message(exc: HTTPError) -> str:
    payload = exc.read().decode("utf-8", errors="ignore")
    if not payload:
        return exc.reason or "Supabase request failed."

    try:
        data = json.loads(payload)
    except json.JSONDecodeError:
        return payload

    if isinstance(data, dict):
        return data.get("msg") or data.get("message") or data.get("error_description") or data.get("error") or payload

    return payload


def _request(
    method: str,
    url: str,
    *,
    headers: dict[str, str] | None = None,
    data: bytes | None = None,
    timeout: int | None = None,
) -> tuple[bytes, dict[str, str]]:
    request = Request(url, method=method, data=data, headers=headers or {})
    with urlopen(request, timeout=timeout or settings.SUPABASE_HTTP_TIMEOUT) as response:
        body = response.read()
        response_headers = dict(response.headers.items())
    return body, response_headers


class SupabaseAuthClient:
    """Verifies Supabase bearer tokens for Django requests."""

    def verify_access_token(self, token: str) -> dict[str, Any]:
        _require_setting("SUPABASE_URL")
        try:
            header = jwt.get_unverified_header(token)
        except jwt.PyJWTError as exc:
            raise SupabaseAuthenticationError("Invalid bearer token.") from exc

        algorithm = str(header.get("alg", "")).upper()
        if algorithm.startswith("HS"):
            return self._verify_via_auth_api(token)

        return self._verify_via_jwks(token, algorithm)

    def _verify_via_jwks(self, token: str, algorithm: str) -> dict[str, Any]:
        try:
            jwks_client = jwt.PyJWKClient(settings.SUPABASE_JWKS_URL)
            signing_key = jwks_client.get_signing_key_from_jwt(token)
            options = {"verify_aud": bool(settings.SUPABASE_JWT_AUDIENCE)}
            return jwt.decode(
                token,
                key=signing_key.key,
                algorithms=[algorithm],
                audience=settings.SUPABASE_JWT_AUDIENCE or None,
                issuer=settings.SUPABASE_JWT_ISSUER,
                options=options,
            )
        except (jwt.PyJWTError, URLError, ValueError) as exc:
            raise SupabaseAuthenticationError("Supabase token verification failed.") from exc

    def _verify_via_auth_api(self, token: str) -> dict[str, Any]:
        api_key = settings.SUPABASE_ANON_KEY or settings.SUPABASE_SERVICE_ROLE_KEY
        if not api_key:
            raise SupabaseConfigurationError("SUPABASE_ANON_KEY or SUPABASE_SERVICE_ROLE_KEY must be configured.")

        try:
            body, _ = _request(
                "GET",
                _build_url("/auth/v1/user"),
                headers={
                    "Authorization": f"Bearer {token}",
                    "apikey": api_key,
                    "Accept": "application/json",
                },
            )
        except HTTPError as exc:
            raise SupabaseAuthenticationError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseAuthenticationError("Unable to reach Supabase Auth.") from exc

        try:
            return json.loads(body.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise SupabaseAuthenticationError("Supabase Auth returned an invalid response.") from exc


class SupabaseStorageClient:
    """Minimal REST client for Supabase Storage operations."""

    def __init__(
        self,
        *,
        bucket: str | None = None,
        base_path: str | None = None,
        public_bucket: bool | None = None,
    ) -> None:
        self.bucket = bucket or _require_setting("SUPABASE_STORAGE_BUCKET")
        self.base_path = (base_path if base_path is not None else settings.SUPABASE_STORAGE_BASE_PATH).strip("/")
        self.public_bucket = settings.SUPABASE_STORAGE_PUBLIC if public_bucket is None else public_bucket
        self.service_role_key = _require_setting("SUPABASE_SERVICE_ROLE_KEY")
        _require_setting("SUPABASE_URL")

    def upload(
        self,
        path: str,
        content: bytes,
        *,
        content_type: str | None = None,
        upsert: bool = True,
    ) -> dict[str, Any]:
        try:
            body, _ = _request(
                "POST",
                self._object_url(path),
                headers={
                    **self._auth_headers(),
                    "Content-Type": content_type or "application/octet-stream",
                    "x-upsert": "true" if upsert else "false",
                },
                data=content,
            )
        except HTTPError as exc:
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc

        return json.loads(body.decode("utf-8")) if body else {}

    def download(self, path: str) -> bytes:
        try:
            body, _ = _request(
                "GET",
                self._object_url(path),
                headers=self._auth_headers(),
            )
        except HTTPError as exc:
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc
        return body

    def delete(self, path: str) -> None:
        payload = json.dumps({"prefixes": [self._normalized_path(path)]}).encode("utf-8")
        try:
            _request(
                "DELETE",
                self._bucket_url(),
                headers={**self._auth_headers(), "Content-Type": "application/json"},
                data=payload,
            )
        except HTTPError as exc:
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc

    def exists(self, path: str) -> bool:
        try:
            body, _ = _request(
                "GET",
                self._info_url(path),
                headers=self._auth_headers(),
            )
        except HTTPError as exc:
            if exc.code == 404:
                return False
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc

        try:
            json.loads(body.decode("utf-8")) if body else {}
        except json.JSONDecodeError as exc:
            raise SupabaseStorageError("Supabase Storage returned an invalid response.") from exc

        if not body:
            return False
        return True

    def size(self, path: str) -> int | None:
        metadata = self.info(path).get("metadata", {})
        size = metadata.get("size")
        return int(size) if size is not None else None

    def info(self, path: str) -> dict[str, Any]:
        try:
            body, _ = _request(
                "GET",
                self._info_url(path),
                headers=self._auth_headers(),
            )
        except HTTPError as exc:
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc
        try:
            return json.loads(body.decode("utf-8")) if body else {}
        except json.JSONDecodeError as exc:
            raise SupabaseStorageError("Supabase Storage returned an invalid response.") from exc

    def url(self, path: str) -> str:
        if self.public_bucket:
            return self.public_url(path)
        return self.signed_url(path, expires_in=settings.SUPABASE_STORAGE_SIGNED_URL_EXPIRY)

    def public_url(self, path: str) -> str:
        encoded_path = quote(self._normalized_path(path), safe="/")
        return _build_url(f"/storage/v1/object/public/{quote(self.bucket)}/{encoded_path}")

    def signed_url(self, path: str, *, expires_in: int) -> str:
        payload = json.dumps({"expiresIn": expires_in}).encode("utf-8")
        try:
            body, _ = _request(
                "POST",
                self._sign_url(path),
                headers={**self._auth_headers(), "Content-Type": "application/json"},
                data=payload,
            )
        except HTTPError as exc:
            raise SupabaseStorageError(_decode_error_message(exc)) from exc
        except URLError as exc:
            raise SupabaseStorageError("Unable to reach Supabase Storage.") from exc

        try:
            response = json.loads(body.decode("utf-8")) if body else {}
        except json.JSONDecodeError as exc:
            raise SupabaseStorageError("Supabase Storage returned an invalid response.") from exc
        signed_path = response.get("signedURL")
        if not signed_path:
            raise SupabaseStorageError("Supabase Storage did not return a signed URL.")
        return _build_url(f"/storage/v1{signed_path}")

    def _auth_headers(self) -> dict[str, str]:
        return {
            "Authorization": f"Bearer {self.service_role_key}",
            "apikey": self.service_role_key,
            "Accept": "application/json",
        }

    def _normalized_path(self, path: str) -> str:
        stripped = path.lstrip("/")
        if not self.base_path:
            return stripped
        if not stripped:
            return self.base_path
        return f"{self.base_path}/{stripped}"

    def _bucket_url(self) -> str:
        return _build_url(f"/storage/v1/object/{quote(self.bucket)}")

    def _object_url(self, path: str) -> str:
        encoded_path = quote(self._normalized_path(path), safe="/")
        return _build_url(f"/storage/v1/object/{quote(self.bucket)}/{encoded_path}")

    def _info_url(self, path: str) -> str:
        encoded_path = quote(self._normalized_path(path), safe="/")
        return _build_url(f"/storage/v1/object/info/{quote(self.bucket)}/{encoded_path}")

    def _sign_url(self, path: str) -> str:
        encoded_path = quote(self._normalized_path(path), safe="/")
        return _build_url(f"/storage/v1/object/sign/{quote(self.bucket)}/{encoded_path}")
