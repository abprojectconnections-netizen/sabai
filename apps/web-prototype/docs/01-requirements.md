# Requirements and status

Legend: PASS = verified by automated test run in this workspace · PARTIAL · NOT IMPLEMENTED · NOT VERIFIED.

| ID | Requirement | Status | Evidence |
|---|---|---|---|
| R-ENV-1 | Config validated; invalid config blocks startup | PASS | `tests/unit/env.test.js`, `tests/ui/bootGate.test.jsx` |
| R-ENV-2 | PRODUCTION never uses mock; https + non-local API | PASS | env.test.js |
| R-ENV-3 | BETA/DEV never target production API | PASS | env.test.js |
| R-DATA-1 | Mock repository mirrors backend validation | PASS | repositories.test.js |
| R-DATA-2 | HTTP repository matches backend envelope, auth header, errors, timeout | PASS (fake fetch only) | repositories.test.js |
| R-DATA-3 | BETA/PROD never inject mock data | PASS | repositories.test.js |
| R-AUTH-1 | Login/register via repository, errors shown | PASS | tests/ui/auth.test.jsx |
| R-CAL-1 | Google Calendar links, RFC 5545 `.ics` (folding, escaping, alarms) | PASS | calendarExport.test.js |
| R-REM-1 | Reminders generated and fired once | PASS (logic) · UI engine NOT VERIFIED by UI test | reminders.test.js |
| R-PLAN-1 | Checklist, agenda, conflicts, pricing | PASS | tripPlan.test.js |
| R-FLT-1 | Multi-airline simulated flights | PASS (simulated, deterministic) | flights.test.js |
| R-BOOK-1 | Booking cancel + refund rule | PASS (rule) | bookings.test.js |
| R-UI-1 | Remaining screens (community, wallet, maps, checkout…) | PARTIAL — render and build; no UI flow tests | — |
| R-API-1 | Real trips/bookings/payments backend | NOT IMPLEMENTED (backend stub) | — |
| R-BE-1 | Backend builds and runs | NOT VERIFIED | module proxy unreachable |
| R-SEC-1 | Token storage / production hardening | PARTIAL — token in memory only; a client flag is not a security boundary | — |
