# Travel Super App API

Go/Gin API starter organized by domain. The first vertical slices are health, authentication, and trips; each future domain follows controller → service → repository with database transactions in services.

Run locally with `go run ./cmd/api`. Copy `.env.example` to `.env` and supply production secrets through your deployment secret manager. Docker exposes the API at `http://localhost:8082` to avoid conflicting with an existing local service.

For Flutter Web development, set `CORS_ALLOWED_ORIGINS` to a comma-separated list of exact frontend origins (for example, `http://localhost:8081,http://127.0.0.1:8081`). The API defaults to these local development origins when the variable is unset; configure the deployed web origin explicitly in production.

OpenAPI is maintained at `docs/openapi.yaml`. The running API exposes `GET /health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `GET /api/v1/trips`, and `POST /api/v1/trips` for the initial integration.

## Authorization and portal operations

Every protected route validates the signed JWT, confirms that the account is active, and reads current roles from MySQL on every request. The fixed role set is `CUSTOMER`, `PARTNER`, `STAFF`, and `ADMIN`; registering an account assigns `CUSTOMER`. Staff/Admin portal routes operate booking status, payment verification, partner approval, ticket assignment/status, and disputes. Every operational status change is recorded in `audit_logs` with actor, before/after state, IP address, request ID, and timestamp.
