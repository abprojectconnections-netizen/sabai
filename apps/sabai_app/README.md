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
**Not built yet:** real flight inventory and a real payment provider (both simulated, see the flights and sandbox update below). See `apps/web-prototype/docs/05-known-limitations.md` for backend gaps that apply here too.

## Update: trips, profile, settings
- **Trips** use the real `/trips` API (list, detail with days and activities, create, delete, add/remove activity); the mock repository keeps them in memory.
- **Profile** shows the signed-in user and links to the wallet and settings.
- **Settings** are stored on this device only (theme, local reminders). Password change and account deletion are intentionally absent: the backend has no endpoints for them. Language/currency switching is not offered because the app has no localisation yet.

## Update: notifications and reviews
- **Notifications**: bell with unread count in the app bar, list, mark one/all as read (`/notifications`).
- **Reviews**: a confirmed or completed booking can be reviewed once (rating 1-5, optional text, optional tags via the central tagging API `/content/REVIEW/{id}/tags`); "my reviews" lists and deletes them. The reviews API does not verify that a subject exists, so the app only offers the user's own bookings.

## Update: community, coupons, help
- **Community** (tab "ชุมชน", sign-in required): posts show immediately (no pre-moderation); you can tag your own post (central tag system, type `COMMUNITY_POST`), delete it, and report other posts. A reported post disappears for the reporter. There is no staff moderation tool yet, so reports are only stored.
- **Coupons** (Profile > คูปองของฉัน): save a code and see its state (ACTIVE / EXPIRED / NOT_STARTED / EXHAUSTED / UNAVAILABLE). Display only: the app never sends a coupon with a booking and says so on screen. (The backend booking API itself still accepts `coupon_code`.)
- **Help** (Profile > ช่วยเหลือ): read-only FAQ. It states no refund windows, fees or contact channel because none is defined yet.
- The mock repository ships demo codes `SABAI10` (active) and `OLD10` (expired).

## Update: maps and trip planner
- **Maps**: in a trip, each activity has "open in Google Maps" (a search for its title) and each day with 2+ activities has "view the whole day's route" (the last stop is the destination, up to 9 waypoints, starting from the user's current location). These are deep links opened with `url_launcher`: no API key and no map inside the app. Activities store only a title (no coordinates), so Maps searches by that text and may pick a different place.
- **Planner**: "สร้างแผนจากแม่แบบ" on the Trips tab builds a starter itinerary from fixed templates (a curated 3-day Chiang Mai plan, a generic plan otherwise, 1-7 days) and saves it as an ordinary trip through `/trips`. It is **not AI** and says so on screen; it checks no opening hours, distances or prices. If some activities fail to save, the trip stays and the app reports how many were lost.

## Update: flights and sandbox payments
- **Flights** ("ค้นหาเที่ยวบิน" on the Search tab) are ordinary catalogue products of category `FLIGHT`, listed from `/catalog` and booked through the normal checkout and server-side pricing. The seeded flights are **simulated** (fictional carriers, generated times and prices; see `backend/cmd/seed`). No ticket is issued by anyone. Route and departure time are read from the listing title for filtering (display only; there are no structured flight fields yet).
- **Sandbox payments**: in `dev`/`beta` the checkout shows a SANDBOX notice, and a "simulate failed payment" button asks the server's mock provider for a `CHARGE_FAILED` event (`POST /dev/payments/simulate {outcome: FAILED}`). The booking then stays unpaid and expires on its own; the app says so and offers a retry (which creates a new booking). In `production` the button does not exist, the client refuses the call, and the server route is absent.
- Real flights still need a provider decision first (inventory, pricing, ticketing, refunds).

## Update: staff moderation (phones and desktop)
- Users whose `GET /me` shows both `portal.read` and `support.manage` get "ตรวจสอบรายงานชุมชน (เจ้าหน้าที่)" in Profile. It lists posts with open reports (most reported first); staff can **dismiss** (keep the post) or **remove** it, with an optional note. Both are audited by the server. The menu is only a convenience: the server enforces the permission on every call, and a customer who somehow opens the screen gets 403.
- The layout adapts: one column on phones, and on wide windows (desktop/tablet) a centred column up to 900 px with the actions beside each post. Desktop runners (Windows, web) use the same screens.
- Offline mock: signing in with an address starting `staff@` simulates a moderator with two sample reports.

## Update: admin console (phones and desktop)

Profile → **คอนโซลผู้ดูแล** appears only when `GET /me` reports `user.manage` (System Admin) or `audit.read` (Auditor, CFO). The server still checks every call; the app only hides what you cannot use.

- **Dashboard** (`GET /admin/dashboard`): live counts of users, bookings, payments by status and open work queues. Counts only, no money figures.
- **Users** (`user.manage`): search by e-mail, filter active/suspended, page through the list, open one account and **suspend** (a reason of at least 3 characters is required) or **reactivate** it. You cannot change your own account. Every change is audited by the server and takes effect on the next request.
- **Audit trail** (`audit.read`): read-only, newest first, filter by event name, expand a row to see before/after. System Admin deliberately cannot read it.
- Offline mock: sign in as `admin@…` (System Admin), `auditor@…` (Auditor) or `staff@…` (moderator) to try each role. The mock enforces the same rules (reason required, no self-change, no-op on repeat).
- Not included yet: role approval, work queues (bookings, tickets, disputes), partner approval and system settings.

## Update: staff work queues (phones and desktop)

Profile → **คิวงานเจ้าหน้าที่** appears when `/me` reports `booking.manage`, `support.manage` or `partner.review`; each tab appears only for its own permission (a Booking Officer sees bookings and disputes, not partners).

- **Bookings:** search by booking code, filter by status, confirm or cancel (with an optional note), open a dispute (reason required).
- **Disputes:** start review, then resolve or reject.
- **Partners:** approve or reject applications; suspend and reactivate approved partners.
- Every row shows only the actions the server lists in `next_statuses` (a PAID booking offers none), every change asks for confirmation and is audited by the server, and the list refreshes afterwards (also after a conflict, since the usual cause is a row someone else just moved).
- Offline mock: `staff@…` (all queues) or `officer@…` (bookings and disputes) with the same transition rules as the backend.
- Not included: support tickets (customers cannot open tickets yet), refunds and settlements (finance permissions, separate screens), role approval.

## Update: feature switches (admin console)

Console → **ฟีเจอร์ที่ปิดเปิดได้** appears when `/me` reports `config.manage` (System Admin). It lists the runtime flags from `GET /admin/feature-flags` (`community.posting`, `coupons.claiming`) as switches.

- Turning a flag **off** asks for a reason (at least 3 characters), which the server writes to the audit trail; turning it back on needs none. Repeating the current value changes nothing.
- While a flag is off the server answers `503 FEATURE_DISABLED` for that one action (posting, or claiming a coupon); reading and everything else keeps working. The app shows "ฟีเจอร์นี้ถูกปิดชั่วคราวโดยผู้ดูแลระบบ".
- After every switch the list is reloaded, so it always shows what the server holds, even after a failure.
- Offline mock: sign in as `admin@…`. Auditors and staff do not see the entry.
- Not included: hiding the post box or coupon field when a flag is off (`GET /config/flags` exists for that and is not used by the app yet), and system settings (no setting is read by anything yet).
