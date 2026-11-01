# API contract used by the HTTP repository (from `backend/docs/openapi.yaml`)

Base URL e.g. `http://localhost:8082/api/v1` (DEV only).
- `POST /auth/register` `{email, password, display_name}` → `{data:{user, access_token, token_type}, request_id}`
- `POST /auth/login` `{email, password}` → `{data:{access_token, token_type}, request_id}`
- Trips (persisted, scoped to the caller; other users' trips return 404): `GET/POST /trips`, `GET/PATCH/DELETE /trips/{id}`, `POST /trips/{id}/activities`, `DELETE /trips/{id}/activities/{activityId}`.
  `destination_id` accepts a catalog id or UUID (max 36 chars, not verified); empty dates mean "not set"; trips span at most 60 days.
- Notifications and reviews exist on the server (`/notifications`, `/reviews`) but are **not wired into the UI** yet.
- Still missing on the server: bookings, payments, wallet, coupons.
- Errors: `{error:{code,message}, request_id}` with codes such as `VALIDATION_ERROR`, `UNAUTHORIZED`, `INTERNAL_ERROR`.
Client-added codes: `NETWORK_ERROR`, `TIMEOUT`, `BAD_RESPONSE`.
Verified against a fake `fetch` only; the web app has not been run against the real server. The server's own tests use sqlmock, not a real MySQL.
