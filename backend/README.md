# Travel Super App API

Go/Gin API starter organized by domain. The vertical slices so far are health, authentication, trips (with itinerary), notifications and reviews; each future domain follows controller → service → repository with database transactions in services.

Run locally with `go run ./cmd/api`. Copy `.env.example` to `.env` and supply production secrets through your deployment secret manager. Docker exposes the API at `http://localhost:8082` to avoid conflicting with an existing local service.

For Flutter Web development, set `CORS_ALLOWED_ORIGINS` to a comma-separated list of exact frontend origins (for example, `http://localhost:8081,http://127.0.0.1:8081`). The API defaults to these local development origins when the variable is unset; configure the deployed web origin explicitly in production.

OpenAPI is maintained at `docs/openapi.yaml`. The running API exposes `GET /health`, `POST /api/v1/auth/{register,login}`, `/api/v1/trips` (CRUD plus `/{id}/activities`), `/api/v1/notifications` and `/api/v1/reviews`. All user data is scoped to the authenticated user; another user's resource is reported as 404. See `docs/openapi.yaml`.

## Tests
```bash
go vet ./... && go test ./...
```
Handler and service tests use `go-sqlmock`: they verify request/response behaviour, validation, ownership scoping and the SQL statements that are issued, but they do **not** execute SQL on MySQL. Before relying on a new query, run it against the Docker MySQL (`docker compose up mysql api`) and exercise it with the OpenAPI contract.

## Tests

- `go test -race ./...` runs unit tests (sqlmock; fast, no database).
- Integration tests run the real HTTP API against a real MySQL and are the only proof that the SQL, constraints, transactions and concurrency work:
  `database/migrate.sh up` then `MYSQL_TEST_DSN='user:pass@tcp(127.0.0.1:3306)/db?parseTime=true' go test -tags integration ./internal/integration`. CI does this on MySQL 8.4.
- Handlers must pass `c.Request.Context()` (never the `*gin.Context`) to database calls: gin recycles contexts after a request returns.

Not implemented yet: bookings, payments, wallet, coupons (the related tables are skeletons in migration 000001 and need a migration first).

## Authorization and portal operations

Every protected route validates the signed JWT, confirms that the account is active, and reads current roles from MySQL on every request. The fixed role set is `CUSTOMER`, `PARTNER`, `STAFF`, and `ADMIN`; registering an account assigns `CUSTOMER`. Staff/Admin portal routes operate booking status, payment verification, partner approval, ticket assignment/status, and disputes. Every operational status change is recorded in `audit_logs` with actor, before/after state, IP address, request ID, and timestamp.

## Financial design (Section 8) — design only
`docs/design/0002-financial-baseline-section8.md` (rules, gap analysis, RBAC, state machines), `docs/design/0003-financial-erd.md` (data model) and `docs/openapi-financial-draft.yaml` (draft API, **not served**). Nothing financial is implemented or enabled; see 0002 section 2 for existing endpoints that must be fixed first.

## Known integration gap (found by the real-MySQL tests)

`trips.destination_id` is a foreign key to `destinations(id)` (UUID). The web prototype sends slugs such as `chiangmai`, and `destinations` has no slug column and no seed data. The API now answers 400 `destination_id does not exist` instead of a 500, but the web app cannot create trips with a destination against this backend until destinations are seeded and the web uses their ids (or a `slug` column is added).

## Financial core (Section 8) — what exists

All of it runs on a **mock payment provider** and is **off by default** (`FINANCIAL_TRANSACTIONS_ENABLED=false`; endpoints answer 503).
A non-mock provider or live supplier is refused until `go_live_approvals` holds PSP, LEGAL, ACCOUNTING and SECURITY approvals.

| Area | Where | Guarantees (each proven by integration tests on real MySQL) |
|---|---|---|
| Schema | `database/migrations/000006`–`000012` | money `DECIMAL(14,2)`+currency; CHECKs for price sums, commission formula, refunded ≤ captured; append-only triggers; unique keys for idempotency, one live payout, one live refund disbursement |
| Booking | `internal/finance/booking` | server-side price from inventory, immutable price snapshot, coupons (platform/partner funded), idempotency key, no overselling, hold expiry |
| Payment | `internal/finance/payment` | charge = stored booking total; verified-signature webhook, replay window, duplicate and amount-mismatch handling; status changes only via webhook; late payment flagged, not resurrected |
| Refund | `internal/finance/refund` | refund from the booking's own terms; auto-approval only for small, low-risk, in-window cases; approval limits from data; no self-approval; two approvers above 50,000; wallet only with legally approved consent |
| Wallet | `internal/finance/wallet` | append-only ledger chain, refund-credit only, no double spend |
| Settlement | `internal/finance/settlement` | commission by policy version, partner-funded discounts reduce the base, 7-day window, maker/checker approval, one payout per batch |
| Audit | `internal/finance/faudit` | hash-chained, append-only; `Verify` detects forged or removed rows |
| RBAC | `database/migrations/000010`, `internal/auth` | permissions per role (data); System Admin/legacy ADMIN hold no financial permission; role grants need a second person |

All financial transactions use READ COMMITTED with row locks (`internal/finance/txopt`); the reason is documented there.

### Still open (blocked outside engineering, or not built yet)
- PSP selection/contract and a real provider implementation; supplier adapters other than internal inventory.
- Legal/accounting review: tax-invoice issuer, retention periods, fund flow, VAT treatment (`vat_included = UNVERIFIED`), approved consent wording, and the cancellation-policy defaults (`platform_default_proposal`).
- Not implemented: partial-refund commission reversal, REFUND_REVERSAL settlement items, tax-document generation/PDFs, reconciliation runner, scheduled jobs (hold expiry, weekly settlement), wallet as a payment method at checkout, category-scoped commission policies, `audit_logs` → `financial_audit_logs` migration for the older portal actions, OpenAPI for the new endpoints (draft in `docs/openapi-financial-draft.yaml` is design only).
