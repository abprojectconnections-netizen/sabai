# Run the whole stack locally (backend + seeded catalogue + web, beta mode)

This is for development only. Everything uses the **mock** payment provider; no real money or real supplier is involved.

## 1. Database

```bash
docker compose up -d mysql migrate          # MySQL 8.4 on :3308, applies database/migrations (see database/README.md)
```

Without Docker: create an empty database and run `MYSQL_HOST=… MYSQL_USER=… MYSQL_PASSWORD=… MYSQL_DATABASE=… database/migrate.sh up`.

## 2. Demo catalogue

```bash
cd backend
export MYSQL_DSN='travel:travel@tcp(127.0.0.1:3308)/travel_super_app?parseTime=true'
go run ./cmd/seed -yes          # idempotent; refuses when APP_ENV=prod|production; creates no login and no payment data
```

It adds one approved demo partner and four bookable items (tour, hotel, attraction ticket, airport transfer) plus one sold-out item
that must NOT appear in the catalogue, with availability for the next 90 days.

## 3. API

```bash
export JWT_SECRET='dev-only-secret-change-me-0123456789' APP_ENV=development APP_PORT=8088
export CORS_ALLOWED_ORIGINS=http://localhost:5173
export FINANCIAL_TRANSACTIONS_ENABLED=true PAYMENT_PROVIDER=mock SUPPLIER_MODE=mock MOCK_PSP_SECRET=dev-psp-secret
go run ./cmd/api
```

`FINANCIAL_TRANSACTIONS_ENABLED=true` is what allows bookings and payments; it is `false` by default. The payment simulator
(`POST /dev/payments/simulate`) exists only with the mock provider and `APP_ENV` other than `prod`.

## 4. Web (beta mode)

```bash
cd apps/web-prototype
VITE_APP_ENV=beta VITE_API_MODE=beta VITE_API_BASE_URL=http://localhost:8088/api/v1 npm run dev     # http://localhost:5173
```

Register in the app (or `POST /auth/register`), open Search, pick an item, pay. In this mode the booking, price, payment result and
refund all come from the API; the app only sends ids, a date, a quantity and a payment method.

## 5. Smoke test without a browser

```bash
cd backend && API=http://localhost:8088/api/v1 ./scripts/e2e-smoke.sh      # needs curl and jq
```

Registers a user, books a tour 5 days out, pays through the simulator and requests a refund (auto-approved: inside the free-cancellation window and under the auto limit).

## Things you will notice (they are the policy, not bugs)

- The web app books the **next available date**, which is tomorrow in the seed data: cancelling it is refused with "no refund is due under the cancellation policy" because the free-cancellation window is 48 hours.
- The wallet stays at 0.00 after a refund: refunds go back to the original payment method; the wallet only receives refund credit with the customer's recorded consent (needs approved legal wording, see design 0004).
- Ratings and review counts of catalogue items show 0 (no data source yet).

## Shortcut (scripts/local.sh)

`scripts/local.sh up | seed | api | smoke | test | backup | restore <file> | status | down` wraps the steps above using
`config/env/local.env` (or `local.env.example` when you have no private copy). `make local-up`, `local-seed`, `local-api`
work the same. It refuses to run with `APP_ENV=prod|production`. Environment templates for local/test/staging/production and
their rules are in `config/env/README.md`.
