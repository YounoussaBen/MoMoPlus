#!/usr/bin/env python
"""Development helper script"""

import subprocess
import sys


def run_server():
    """Run Django development server"""
    subprocess.run(["uv", "run", "python", "manage.py", "runserver"])


def run_celery():
    """Run Celery worker"""
    subprocess.run(["uv", "run", "celery", "-A", "project", "worker", "--loglevel=info"])


def run_flower():
    """Run Flower monitoring"""
    subprocess.run(["uv", "run", "celery", "-A", "project", "flower"])


def format_code():
    """Format code with black and ruff"""
    subprocess.run(["uv", "run", "black", "."])
    subprocess.run(["uv", "run", "ruff", "check", "--fix", "."])


def run_tests():
    """Run all tests"""
    subprocess.run(["uv", "run", "pytest", "--disable-warnings", "--maxfail=1"])


def test_api():
    """Test API endpoints"""
    print("Testing API endpoints...")
    cmd = [
        "curl",
        "-X",
        "POST",
        "http://127.0.0.1:8000/api/auth/register/",
        "-H",
        "Content-Type: application/json",
        "-d",
        '{"username": "testuser", "email": "test@example.com", "password": "testpass123", "first_name": "Test"}',
    ]
    subprocess.run(cmd)


if __name__ == "__main__":
    if len(sys.argv) > 1:
        command = sys.argv[1]
        if command == "server":
            run_server()
        elif command == "celery":
            run_celery()
        elif command == "flower":
            run_flower()
        elif command == "format":
            format_code()
        elif command == "test":
            run_tests()
        elif command == "curl-test":
            test_api()
        else:
            print("Available commands: server, celery, flower, format, test, curl-test")
    else:
        print("Available commands: server, celery, flower, format, test, curl-test")
