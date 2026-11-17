# sabai_app — Sabai Travel Super App (Flutter)

Flutter port of `apps/web-prototype`, using the **same REST contract** (`backend/docs/openapi.yaml`) and the same safety rules:
the client never computes money (amounts are server strings, display only), checkout uses stable `Idempotency-Key`s, refunds are
requests the server decides, and the wallet is refund-credit only.

## Layout (feature-first)
```
lib/
  main.dart                      entry: config -> repository -> app (invalid config shows ConfigErrorApp)
  src/
    app.dart                     MaterialApp + Provider
    core/    config/ errors/ theme/ util/
    data/    models/ repositories/ (AppRepository, MockRepository, HttpRepository)
    state/   AppState (ChangeNotifier)
    features/ auth catalog booking wallet shell config
test/        unit (config, format, models, http repository with MockClient) + widget flow
```

## Run
Platform folders are not committed. Generate them once:
```
cd apps/sabai_app && flutter create --platforms=android,ios,web --project-name sabai_app .
flutter pub get
flutter run                                   # DEV: mock repository
flutter run --dart-define=APP_ENV=beta --dart-define=API_MODE=beta --dart-define=API_BASE_URL=http://10.0.2.2:8080
```
(`10.0.2.2` is the Android emulator's alias for the host; see `backend/docs/run-local.md` to start the API with seed data.)

## Verify
```
flutter analyze && flutter test
```
CI (`.github/workflows/sabai-app.yml`) runs both on every change under `apps/sabai_app/`.

## Status
Ported: configuration (DEV/BETA/PRODUCTION rules), catalogue, sign-in/register, booking + payment (real backend or local mock),
my bookings with refund request, wallet (read-only).
**Not ported yet** (still only in the web prototype): AI planner, community, coupons, help,
maps, flights. See `apps/web-prototype/docs/05-known-limitations.md` for backend gaps that apply here too.

## Update: trips, profile, settings
- **Trips** use the real `/trips` API (list, detail with days and activities, create, delete, add/remove activity); the mock repository keeps them in memory.
- **Profile** shows the signed-in user and links to the wallet and settings.
- **Settings** are stored on this device only (theme, local reminders). Password change and account deletion are intentionally absent: the backend has no endpoints for them. Language/currency switching is not offered because the app has no localisation yet.

## Update: notifications and reviews
- **Notifications**: bell with unread count in the app bar, list, mark one/all as read (`/notifications`).
- **Reviews**: a confirmed or completed booking can be reviewed once (rating 1-5, optional text, optional tags via the central tagging API `/content/REVIEW/{id}/tags`); "my reviews" lists and deletes them. The reviews API does not verify that a subject exists, so the app only offers the user's own bookings.
