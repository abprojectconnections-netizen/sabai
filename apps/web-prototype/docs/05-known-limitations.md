# Known limitations
- Prototype data is in-memory; refresh resets everything. Wallet/payments/bookings are simulated.
- Flights are deterministic simulations, not a real provider.
- Backend: only auth is real; `/trips` is a stub; itinerary has no server model.
- Only BootGate and auth have UI tests; most feature screens are covered by build/lint only.
- Coverage is not measured; `@vitest/coverage-v8` is not installed.
- Repo root has a committed `node_modules`; the superseded `sabai-travel-app-prototype.jsx` remains at repo root.
- Backend could not be built here (module proxy unreachable).
- Bundle is a single 395 kB chunk (no route splitting).
