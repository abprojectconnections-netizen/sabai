#!/usr/bin/env bash
# Restore a backup made by backup.sh into an EMPTY database. It never drops or overwrites existing data:
# if the target database already contains tables, it refuses. To replace a database, create a new empty one
# (or have an operator drop the old one deliberately) and restore into that.
#
#   CONFIRM_DESTRUCTIVE=yes database/restore.sh <backup.sql.gz>
#
# Connection (environment): MYSQL_DATABASE (required, must exist and be empty), MYSQL_USER, MYSQL_PASSWORD, MYSQL_HOST, MYSQL_PORT.
# Refuses when APP_ENV is prod/production.
set -euo pipefail
file="${1:?usage: restore.sh <backup.sql.gz>}"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
case "${APP_ENV:-}" in prod|production) echo "refusing: restore is not allowed when APP_ENV=${APP_ENV}" >&2; exit 1;; esac
[[ "${CONFIRM_DESTRUCTIVE:-}" == "yes" ]] || { echo "refusing: set CONFIRM_DESTRUCTIVE=yes to restore" >&2; exit 1; }
[[ -f "$file" ]] || { echo "ERROR: $file not found" >&2; exit 1; }
gzip -t "$file"
[[ -n "${MYSQL_PASSWORD:-}" ]] && export MYSQL_PWD="$MYSQL_PASSWORD"
args=(-h "${MYSQL_HOST:-127.0.0.1}" -P "${MYSQL_PORT:-3306}" --protocol=TCP -u "${MYSQL_USER:-root}" --default-character-set=utf8mb4)
n="$(mysql "${args[@]}" -N -B -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = '${MYSQL_DATABASE//\'/}'")"
[[ "$n" == 0 ]] || { echo "refusing: database $MYSQL_DATABASE already has $n table(s); restore only into an empty database" >&2; exit 1; }
gunzip -c "$file" | mysql "${args[@]}" "$MYSQL_DATABASE"
echo "restored $file into $MYSQL_DATABASE"
