# Environments and release

| Env | API mode | Notes |
|---|---|---|
| DEV | mock (default) or beta | `.env.development` committed |
| BETA | mock or beta, never production | copy `.env.beta.example` |
| PRODUCTION | production only, https, non-local | copy `.env.production.example` |

Note: `vite build` itself succeeds without variables; the guard runs at app start (ConfigError screen).
The release pipeline must therefore supply the variables and smoke-test that the app boots.

## Release gates (status as of this change)
| Gate | Status |
|---|---|
| Lint | PASS (0 errors) |
| Unit + UI tests | PASS — 83 tests / 11 files |
| Build (dev/beta/production modes) | PASS |
| Coverage measurement | NOT MEASURED |
| E2E against real backend | NOT VERIFIED |
| Backend build | NOT VERIFIED |
| Security review, load, accessibility audit | NOT DONE |
| Deployment | NOT DONE — nothing was deployed |
