# Known limitations
- Prototype data is in-memory; refresh resets everything. Wallet/payments/bookings are simulated.
- Flights are deterministic simulations, not a real provider.
- Backend: auth, trips (+itinerary), notifications and reviews are implemented; bookings, payments, wallet and coupons are not. The Go tests use sqlmock, so SQL has never run on a real MySQL.
- The UI still renders trips/notifications/reviews from mock data; the repository methods for trips exist but the screens are not wired to them.
- Only BootGate and auth have UI tests; most feature screens are covered by build/lint only.
- Coverage is not measured; `@vitest/coverage-v8` is not installed.
- Repo root has a committed `node_modules`; the superseded `sabai-travel-app-prototype.jsx` remains at repo root.
- Bundle is a single 395 kB chunk (no route splitting).
