# API contract used by the HTTP repository (from `backend/docs/openapi.yaml`)

Base URL e.g. `http://localhost:8082/api/v1` (DEV only).
- `POST /auth/register` `{email, password, display_name}` → `{data:{user, access_token, token_type}, request_id}`
- `POST /auth/login` `{email, password}` → `{data:{access_token, token_type}, request_id}`
- `GET /trips`, `POST /trips` `{name, destination_id, start_date, end_date}` — **stub on the server**; create does not persist.
- Errors: `{error:{code,message}, request_id}` with codes such as `VALIDATION_ERROR`, `UNAUTHORIZED`, `INTERNAL_ERROR`.
Client-added codes: `NETWORK_ERROR`, `TIMEOUT`, `BAD_RESPONSE`.
Verified against a fake `fetch` only; never run against the real server in this workspace.
