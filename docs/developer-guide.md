# Developer guide

## Local services

Docker Desktop runs MySQL, Redis, and MinIO with `docker compose up -d`. The initial MySQL schema loads automatically from `database/migrations/000001_travel_super_app_schema.up.sql` on a new volume.

Run the API from `backend` with `go run -mod=mod ./cmd/api`. Verify it through `GET http://localhost:8080/health`. The OpenAPI contract is in `backend/docs/openapi.yaml`.

## Flutter

Use `dart pub get` (or `flutter pub get` in a normal Flutter SDK installation). Set `--dart-define=API_BASE_URL=http://<host>:8080/api/v1` when running on a device that cannot resolve localhost. New backend integrations belong in `lib/core/network` and domain repositories under `lib/features`.

## Secrets

Copy `backend/.env.example` for local development. Do not commit `.env`, OAuth secrets, payment keys, JWT secrets, database passwords, or MinIO credentials. Production values belong in the deployment platform's secret manager.
