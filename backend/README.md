# Travel Super App API

Go/Gin API starter organized by domain. The first vertical slices are health, authentication, and trips; each future domain follows controller → service → repository with database transactions in services.

Run locally with `go run ./cmd/api`. Copy `.env.example` to `.env` and supply production secrets through your deployment secret manager.

OpenAPI is maintained at `docs/openapi.yaml`. The running API exposes `GET /health`, `POST /api/v1/auth/register`, `POST /api/v1/auth/login`, `GET /api/v1/trips`, and `POST /api/v1/trips` for the initial integration.
