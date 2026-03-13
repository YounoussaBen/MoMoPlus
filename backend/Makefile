.PHONY: help install dev test format lint clean server celery flower docs

# Default target
help:
	@echo "Available commands:"
	@echo "  make install     - Install dependencies"
	@echo "  make dev         - Install dev dependencies"
	@echo "  make test        - Run all tests"
	@echo "  make test-fast   - Run tests in parallel"
	@echo "  make test-cov    - Run tests with coverage report"
	@echo "  make test-html   - Generate HTML coverage report"
	@echo "  make format      - Format code (black + ruff)"
	@echo "  make lint        - Run linting checks"
	@echo "  make clean       - Clean cache files"
	@echo "  make server      - Run Django development server"
	@echo "  make celery      - Run Celery worker"
	@echo "  make flower      - Run Flower monitoring"
	@echo "  make shell       - Open Django shell"
	@echo "  make migrate     - Run database migrations"
	@echo "  make superuser   - Create superuser"
	@echo "  make collectstatic - Collect static files"

# Installation
install:
	uv sync

dev:
	uv sync --extra dev --extra test

# Testing
test:
	uv run pytest --disable-warnings --maxfail=1

test-fast:
	uv run pytest --disable-warnings -n auto

test-cov:
	uv run coverage run -m pytest
	uv run coverage report -m

test-html:
	uv run coverage run -m pytest
	uv run coverage html
	@echo "Coverage report generated in htmlcov/"

test-specific:
	@read -p "Enter test path: " test_path; \
	uv run pytest --disable-warnings "$$test_path" -v

# Code quality
format:
	uv run black .
	uv run ruff check --fix .

lint:
	uv run ruff check .
	uv run black --check .
	uv run mypy project/

# Cleanup
clean:
	find . -type f -name "*.pyc" -delete
	find . -type d -name "__pycache__" -delete
	find . -type d -name "*.egg-info" -exec rm -rf {} +
	rm -rf .coverage htmlcov/ .pytest_cache/

# Django commands
server:
	uv run python manage.py runserver

shell:
	uv run python manage.py shell

migrate:
	uv run python manage.py migrate

makemigrations:
	uv run python manage.py makemigrations

superuser:
	uv run python manage.py createsuperuser

collectstatic:
	uv run python manage.py collectstatic --noinput

# Background tasks
celery:
	uv run celery -A project worker --loglevel=info

flower:
	uv run celery -A project flower

# Development workflow
setup: dev migrate superuser
	@echo "Development environment setup complete!"
	@echo "Run 'make server' to start the development server"

# API testing
test-api:
	@echo "Testing API endpoints..."
	curl -X POST http://127.0.0.1:8000/api/auth/register/ \
		-H "Content-Type: application/json" \
		-d '{"username": "testuser", "email": "test@example.com", "password": "testpass123", "password_confirm": "testpass123", "first_name": "Test", "last_name": "User"}'

# Check everything
check: lint test
	@echo "All checks passed!"

# Add to existing Makefile
generate-secrets:
	uv run python scripts/generate_secrets.py

# Security
security-check:
	uv run python manage.py check --deploy
