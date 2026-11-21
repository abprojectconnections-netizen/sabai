#!/usr/bin/env bash
# One entry point for the local stack. Development only: it refuses to run with APP_ENV=prod|production.
#
#   scripts/local.sh up        start MySQL (Docker) and apply migrations
#   scripts/local.sh seed      load the demo catalogue (idempotent)
#   scripts/local.sh api       run the API in the foreground using config/env/local.env (or the .example)
#   scripts/local.sh smoke     end-to-end smoke test against the running API
#   scripts/local.sh test      go vet + unit tests (integration tests: see backend/docs/run-local.md)
#   scripts/local.sh backup    dump the local database to backups/
#   scripts/local.sh restore F restore backup F into a NEW empty database <name>_restore (never overwrites)
#   scripts/local.sh down      stop containers (data volume is kept)
#   scripts/local.sh status    migration status
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
envfile="${ENV_FILE:-config/env/local.env}"
[[ -f "$envfile" ]] || envfile=config/env/local.env.example
# Read KEY=VALUE lines without executing the file (a DSN contains "(" and "&"). Variables already set in the
# environment win, so `APP_PORT=9000 scripts/local.sh api` works.
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" =~ ^[A-Za-z_][A-Za-z0-9_]*= ]] || continue
  k="${line%%=*}"; v="${line#*=}"
  [[ -z "${!k+x}" ]] && export "$k=$v"
done < "$envfile"
case "${APP_ENV:-}" in prod|production) echo "refusing: scripts/local.sh is for development only" >&2; exit 1;; esac
export MYSQL_HOST="${DB_HOST:-127.0.0.1}" MYSQL_PORT="${DB_PORT:-3308}" MYSQL_DATABASE="${DB_NAME:-travel_super_app}"
export MYSQL_USER="${DB_USER:-travel}" MYSQL_PASSWORD="${DB_PASSWORD:-travel}"

case "${1:-}" in
  up)
    docker compose up -d mysql migrate
    echo "MySQL on 127.0.0.1:$MYSQL_PORT, migrations applied. Next: scripts/local.sh seed"
    ;;
  seed) (cd backend && go run ./cmd/seed -yes) ;;
  api)  (cd backend && go run ./cmd/api) ;;
  smoke) API="http://localhost:${APP_PORT:-8088}/api/v1" bash backend/scripts/e2e-smoke.sh ;;
  test) (cd backend && go vet ./... && go test -race ./...) ;;
  status) bash database/migrate.sh status ;;
  backup) bash database/backup.sh ;;
  restore)
    f="${2:?usage: scripts/local.sh restore <backup.sql.gz>}"
    target="${MYSQL_DATABASE}_restore"
    MYSQL_PWD=root mysql -h "$MYSQL_HOST" -P "$MYSQL_PORT" --protocol=TCP -u root -e "CREATE DATABASE IF NOT EXISTS \`$target\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci"
    MYSQL_USER=root MYSQL_PASSWORD=root MYSQL_DATABASE="$target" CONFIRM_DESTRUCTIVE=yes bash database/restore.sh "$f"
    ;;
  down) docker compose down ;;
  *) sed -n '2,14p' "$0"; exit 2 ;;
esac
