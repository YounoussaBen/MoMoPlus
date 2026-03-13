#!/usr/bin/env python
"""Generate secure keys for Django"""

import secrets
import string

from django.core.management.utils import get_random_secret_key


def generate_secret_key():
    """Generate Django SECRET_KEY"""
    return get_random_secret_key()


def generate_jwt_key():
    """Generate JWT signing key"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    return "".join(secrets.choice(alphabet) for _ in range(64))


def generate_all_keys():
    """Generate all required keys"""
    print("=== Security Keys ===")
    print(f"SECRET_KEY={generate_secret_key()}")
    print(f"JWT_SIGNING_KEY={generate_jwt_key()}")
    print("\n=== Add these to your .env files ===")


if __name__ == "__main__":
    generate_all_keys()
