# Known limitations
- Prototype data is in-memory; refresh resets everything. Wallet/payments/bookings are simulated.
- Flights are deterministic simulations, not a real provider.
- Backend: auth, trips, notifications, reviews, catalogue, bookings, payments (mock provider), refunds, wallet reads, settlement and RBAC are implemented and covered by integration tests on a real MySQL 8.4 in CI. Financial transactions are OFF by default (`FINANCIAL_TRANSACTIONS_ENABLED=false`) and the payment provider is a mock.
- In BETA/PRODUCTION the account snapshot (bookings, wallet, notifications, reviews) and the cancel/refund request come from the API. **Checkout is still simulated locally**: the search/detail screens use the built-in prototype catalogue, whose ids are not inventory UUIDs, so `POST /bookings` and `POST /payments/intents` are not called yet. Wiring it needs the screens to browse `GET /catalog/items` and a payment step that works with the mock provider.
- Trips are persisted through the repository; community, coupons, support tickets and calendar events remain local state (no endpoints yet).
- Only BootGate and auth have UI tests; most feature screens are covered by build/lint only.
- Coverage is not measured; `@vitest/coverage-v8` is not installed.
- Repo root has a committed `node_modules`; the superseded `sabai-travel-app-prototype.jsx` remains at repo root.
- Bundle is a single 395 kB chunk (no route splitting).
