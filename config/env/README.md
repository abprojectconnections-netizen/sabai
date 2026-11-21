# Environment configuration

One template per environment. Templates contain **only placeholders and development-only values**; real secrets come from
your secret manager or from an untracked `config/env/<name>.env` (ignored by Git).

| File | Purpose | Payments | Database |
|---|---|---|---|
| `local.env.example` | developer machine | mock provider + simulator | local Docker MySQL (:3308) |
| `test.env.example` | automated tests / CI | mock provider | disposable database |
| `staging.env.example` | pre-production | mock or provider **sandbox** only | staging-only database |
| `production.env.example` | production (disabled until explicitly approved) | financial transactions OFF until go-live approvals | production-only database |

Rules enforced by `scripts/check-config.sh` (also runs in CI):

- `APP_ENV` matches the file name's environment.
- Every secret value in `staging`/`production` is the literal `CHANGE_ME`.
- `production` keeps `FINANCIAL_TRANSACTIONS_ENABLED=false` and `PAYMENT_PROVIDER=mock` in the template; turning live payments on
  is a deliberate, approved change made outside this repository (go-live gates: PSP, LEGAL, ACCOUNTING, SECURITY).
- No template points at another environment's database host.

Ports: `go run ./cmd/api` listens on `APP_PORT` (8088 in the local template). The Docker `api` service is published on
**8082** (kept because the OpenAPI servers and older clients reference it).
