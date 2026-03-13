#!/usr/bin/env python
"""Generate local-only secrets for Django."""

from django.core.management.utils import get_random_secret_key


def generate_secret_key():
    """Generate Django SECRET_KEY"""
    return get_random_secret_key()


def generate_all_keys():
    """Generate the local Django secret values that are not sourced from Supabase."""
    print("=== Security Keys ===")
    print(f"SECRET_KEY={generate_secret_key()}")
    print(f"DJANGO_JWT_SIGNING_KEY={generate_secret_key()}")
    print("\n=== Add this to your .env file, then copy the Supabase keys from your project dashboard ===")


if __name__ == "__main__":
    generate_all_keys()
