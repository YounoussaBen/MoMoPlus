# Project API

Django REST API

## Requirements

- Python 3.11+
- Redis (for background tasks)
- PostgreSQL (production)

## Quick Start

### 1. Setup
```bash
make dev
```

### 2. Environment
```bash
# Copy example environment file
cp .env.example .env

# Generate new security keys
make generate-secrets
# Copy the output to your .env file
```

### 3. Database
```bash
make migrate
make superuser
```

### 4. Run
```bash
# Terminal 1: Start server
make server

# Terminal 2: Start background tasks
make celery
```

Visit: http://127.0.0.1:8000


## Development

### Common Commands
```bash
make help              # Show all commands
make test              # Run tests
make test-cov          # Run tests with coverage
make format            # Format code
make lint              # Check code quality
make shell             # Django shell
```

### Testing
```bash
make test              # Run all tests
make test-fast         # Run tests in parallel
make test-html         # Generate coverage report
```

## Production Deployment

1. Set environment variables
2. Use PostgreSQL database
3. Configure static file serving
4. Set up SSL/HTTPS
5. Monitor with Sentry

## License

MIT License
