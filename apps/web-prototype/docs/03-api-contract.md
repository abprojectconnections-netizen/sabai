# API contract used by the HTTP repository (from `backend/docs/openapi.yaml`)

Base URL e.g. `http://localhost:8082/api/v1` (DEV only).
- `POST /auth/register` `{email, password, display_name}` → `{data:{user, access_token, token_type}, request_id}`
- `POST /auth/login` `{email, password}` → `{data:{access_token, token_type}, request_id}`
- Trips (persisted, scoped to the caller; other users' trips return 404): `GET/POST /trips`, `GET/PATCH/DELETE /trips/{id}`, `POST /trips/{id}/activities`, `DELETE /trips/{id}/activities/{activityId}`.
  `destination_id` accepts a catalog id or UUID (max 36 chars, not verified); empty dates mean "not set"; trips span at most 60 days.
- Read by `loadAccountSnapshot()` in BETA/PRODUCTION: `GET /bookings`, `GET /wallet`, `GET /wallet/transactions`, `GET /notifications`, `GET /reviews/mine`. The load fails as a whole if any of them fails (no half-empty account). Amounts arrive as decimal strings and are converted to numbers for display only.
- Cancel/refund: `POST /refunds` (with a stable `Idempotency-Key` per booking). The client sends the booking id and method only; the server computes and approves the amount. The booking is marked cancelled in the UI only after the server accepted the request.
- Served by the backend but **not yet used by the UI**: `GET /catalog/items`, `GET /bookings/{id}`, `POST /bookings`, `POST /payments/intents`, `POST /refunds/{id}/consent`. Checkout therefore still runs on local simulated state (see 05-known-limitations).
- Still missing on the server: coupons listing, support tickets, community, calendar events.
- Errors: `{error:{code,message}, request_id}` with codes such as `VALIDATION_ERROR`, `UNAUTHORIZED`, `INTERNAL_ERROR`.
Client-added codes: `NETWORK_ERROR`, `TIMEOUT`, `BAD_RESPONSE`.
Verified against a fake `fetch` only; the web app has not been run against the real server. The server's own tests use sqlmock, not a real MySQL.
