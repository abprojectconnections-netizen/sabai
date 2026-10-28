# Sabai Travel — Web Prototype (User App MVP)

Interactive React prototype of the Travel Super App ("Sabai"), restructured from a single 3,700-line file into
modules with an environment-aware data layer, tests and docs. UI copy is Thai.

Flows: auth, home, search, AI planner, trips + secretary hub (calendar, conflicts, checklists, agenda),
multi-airline flight selection, Google Maps navigation, reminders, Google Calendar / `.ics` export,
booking, payment, wallet, coupons, reviews, notifications, community, help, settings, my bookings (cancel).

## Quick start
```bash
cd apps/web-prototype
npm install
npm run dev          # DEV, mock data (no backend needed)
npm run check        # lint + tests + build
```

| Script | Purpose |
|---|---|
| `dev` / `dev:beta` | Vite dev server (mock / BETA API) |
| `build` / `build:beta` / `build:prod` | Bundle for each environment |
| `lint`, `test`, `test:watch` | ESLint 9, Vitest |
| `check` | lint + test + build |

## Environments
See `docs/04-environments-and-release.md`. In short: DEV may use mock or beta API; BETA never uses production;
PRODUCTION requires `VITE_API_MODE=production` and an https, non-localhost `VITE_API_BASE_URL`.
Invalid configuration renders a ConfigError screen instead of starting. Only DEV defaults to mock.

## Layout
```
src/config        env parsing + validation
src/repositories  AppRepository contract, mock + HTTP implementations, error mapping
src/app           BootGate (config → repository → snapshot), EnvBadge, SabaiTravelApp (navigation/state)
src/domain        pure logic: dates, flights, trip plan, calendar export, reminders, bookings, maps
src/features      screens per feature
src/components    shared UI
src/data          catalog + fixtures (mock only)
tests/unit        domain, config, repositories
tests/ui          BootGate and auth flows
docs              audit, requirements, architecture, API, release, limitations
```

## Honest status
This is a **prototype**. Most data is in-memory mock data; flights are simulated; payments are not real.
Only auth (register/login) is wired to the real backend contract, and that integration is tested against a fake
`fetch`, **not** against a running server. See `docs/05-known-limitations.md`.
