````markdown
# MoMoPlus API

Django REST API Backend for MoMoPlus

## Requirements

- Python 3.11+
- Redis (for background tasks)
- PostgreSQL (production)

## Quick Start

### 1. Setup
```bash
make dev
````

### 2. Environment

```bash
# Copy example environment file
cp .env.example .env

# Fill in your Supabase values:
# - SUPABASE_URL
# - SUPABASE_ANON_KEY
# - SUPABASE_SERVICE_ROLE_KEY
# - SUPABASE_DB_URL
# - SUPABASE_STORAGE_BUCKET

# Paystack (use test keys for development)
PAYSTACK_SECRET_KEY=sk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
PAYSTACK_PUBLIC_KEY=pk_test_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
# Optional; defaults to payments@momoplus.com
PAYSTACK_PAYMENT_EMAIL=payments@momoplus.com
# Optional demo override; Paystack's Ghana MTN test number requires no PIN/OTP.
PAYSTACK_TEST_MOBILE_MONEY_PHONE=0551234987
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

Visit: [http://127.0.0.1:8000](http://127.0.0.1:8000)

Swagger UI: [http://127.0.0.1:8000/api/docs/](http://127.0.0.1:8000/api/docs/)
OpenAPI schema: [http://127.0.0.1:8000/api/schema/](http://127.0.0.1:8000/api/schema/)
ReDoc: [http://127.0.0.1:8000/api/redoc/](http://127.0.0.1:8000/api/redoc/)

---

## Paystack Integration

### API Keys

Get your keys from Paystack Dashboard → **Settings → API Keys & Webhooks**.

* Use **test keys** for development:

  * `sk_test_...`
  * `pk_test_...`

All Paystack charges use `payments@momoplus.com` by default. Set
`PAYSTACK_PAYMENT_EMAIL` to use a different payment email.

### Demo mobile-money override

For a test-mode demo, set:

```bash
PAYSTACK_TEST_MOBILE_MONEY_PHONE=0551234987
```

Users still create and verify wallets with their own phone numbers. The backend
stores those numbers and returns them on payment receipts, but sends the test
number and MTN provider to Paystack when creating recipients and initiating
charges. The override is applied only when `PAYSTACK_SECRET_KEY` starts with
`sk_test_`; it is ignored for live keys. Remove the setting (or leave it empty)
when moving to production.

---

### Webhook Setup

Set your Paystack webhook URL to:

```
https://<your-server-url>/api/paystack/webhook/
```

The backend endpoint is exposed at:

```
/api/paystack/webhook/
```

---

### Local Development (Webhook Testing)

Paystack cannot reach `localhost`. Use a tunnel:

#### Option 1: ngrok

```bash
ngrok http 8000
```

Example webhook URL:

```
https://abc123.ngrok.io/api/paystack/webhook/
```

Update this URL in your Paystack dashboard.

---

## Supabase Architecture

* Django ORM connects directly to Supabase Postgres through `SUPABASE_DB_URL`.
* Frontend signs users into Supabase Auth and sends the bearer access token to Django.
* Django verifies that token, maps `supabase_user_id` to the local user row, and applies authorization locally.
* Django file storage uses Supabase Storage when `SUPABASE_STORAGE_BUCKET` and `SUPABASE_SERVICE_ROLE_KEY` are configured.

Customer authentication uses Supabase phone OTP with a signed Send SMS hook and Arkesel V2 delivery. See [the phone OTP setup guide](docs/phone-otp-setup.md).

---

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

---

## Production Deployment

1. Set environment variables
2. Use PostgreSQL database
3. Configure static file serving
4. Set up SSL/HTTPS
5. Configure Paystack webhook with production URL
6. Monitor with Sentry

---

## License

MIT License
