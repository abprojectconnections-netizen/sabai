#!/usr/bin/env bash
# Validates config/env/*.env.example against the environment-separation rules (see config/env/README.md).
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/../config/env"
fail=0
err() { echo "ERROR: $*" >&2; fail=1; }
val() { grep -E "^$2=" "$1" | tail -n1 | cut -d= -f2-; }

declare -A want=([local]=development [test]=test [staging]=staging [production]=production)
for name in local test staging production; do
  f="$name.env.example"
  [[ -f "$f" ]] || { err "missing $f"; continue; }
  [[ "$(val "$f" APP_ENV)" == "${want[$name]}" ]] || err "$f: APP_ENV must be ${want[$name]}"
  if [[ "$name" == staging || "$name" == production ]]; then
    for k in MYSQL_DSN JWT_SECRET MOCK_PSP_SECRET CORS_ALLOWED_ORIGINS; do
      [[ "$(val "$f" "$k")" == "CHANGE_ME" ]] || err "$f: $k must be the placeholder CHANGE_ME"
    done
    grep -qiE "localhost|127\.0\.0\.1" "$f" && err "$f: must not point at a local host"
  fi
  [[ "$(val "$f" PAYMENT_PROVIDER)" == "mock" ]] || err "$f: PAYMENT_PROVIDER must stay mock in templates"
  [[ "$(val "$f" SUPPLIER_MODE)" == "mock" ]] || err "$f: SUPPLIER_MODE must stay mock in templates"
done
[[ "$(val production.env.example FINANCIAL_TRANSACTIONS_ENABLED)" == "false" ]] || err "production.env.example: FINANCIAL_TRANSACTIONS_ENABLED must be false"
# No two environments may share a database DSN.
dups="$(for n in local test; do val "$n.env.example" MYSQL_DSN; done | sort | uniq -d)"
[[ -z "$dups" ]] || err "local and test share a database DSN"
[[ $fail -eq 0 ]] && echo "config templates OK"
exit $fail
