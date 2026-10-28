# Architecture

```
main.jsx → BootGate → loadConfig() → createRepository(config) → loadAccountSnapshot() → SabaiTravelApp({repo, snapshot})
```
- **Config** (`src/config/env.js`): single place that reads `import.meta.env`; frozen result.
- **Repository boundary** (`AppRepository`): `mode`, `loadAccountSnapshot()`, `auth.{login,register,logout}`, `trips.{list,create}`. The UI never calls `fetch`.
- **Mock repository**: seeded from `data/fixtures`, deterministic, supports `latencyMs` and `failLoad`.
- **HTTP repository**: snake_case ↔ camelCase mapping, `{data, request_id}` / `{error:{code,message}}` envelope, in-memory bearer token, `AbortController` timeout, `X-Request-ID`, `onUnauthorized`.
- **Domain** is pure (no React), unit-tested.
- **State** remains in `SabaiTravelApp` plus feature hooks (`useCommunity`, `useTravelHub`, `useReminderEngine`).

ADR-1 Repository pattern with DI — lets DEV/BETA/PROD differ only by implementation, never by UI code.
ADR-2 Fail-safe config — an invalid or ambiguous environment stops the app (ConfigError), never falls back to mock outside DEV.
ADR-3 Snapshot-on-boot — one validated load; invalid data is rejected rather than rendered.
ADR-4 Simulated flights stay in domain code and are labelled simulated until a real provider exists.
