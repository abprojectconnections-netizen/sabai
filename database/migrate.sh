#!/usr/bin/env bash
# Minimal, dependency-free migration runner (needs only the `mysql` client).
#
#   migrate.sh up        apply every pending NNNNNN_name.up.sql in order (default)
#   migrate.sh status    list applied and pending versions
#   migrate.sh down      revert ONLY the latest applied version; requires CONFIRM_DESTRUCTIVE=yes
#
# Connection (environment): MYSQL_DATABASE (required), MYSQL_USER (default root), MYSQL_PASSWORD,
# MYSQL_HOST (default 127.0.0.1), MYSQL_PORT (default 3306) or MYSQL_SOCKET.
#
# Why not "mount the folder into /docker-entrypoint-initdb.d": that directory executes EVERY *.sql file in
# name order, including the *.down.sql files, which fails on a fresh database and could drop data.
# Applied versions and their SHA-256 are stored in `schema_migrations`; editing an already-applied file
# is refused. MySQL DDL is not transactional, so a failed migration must be fixed by hand and re-run.
set -euo pipefail

cmd="${1:-up}"
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/migrations"
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
args=(--default-character-set=utf8mb4 -u "${MYSQL_USER:-root}")
if [[ -n "${MYSQL_SOCKET:-}" ]]; then args+=(--socket "$MYSQL_SOCKET"); else args+=(-h "${MYSQL_HOST:-127.0.0.1}" -P "${MYSQL_PORT:-3306}" --protocol=TCP); fi
[[ -n "${MYSQL_PASSWORD:-}" ]] && export MYSQL_PWD="$MYSQL_PASSWORD"
sql() { mysql "${args[@]}" "$MYSQL_DATABASE" "$@"; }
q() { sql -N -B -e "$1"; }

sql -e "CREATE TABLE IF NOT EXISTS schema_migrations (
  version VARCHAR(32) NOT NULL PRIMARY KEY,
  name VARCHAR(200) NOT NULL,
  checksum CHAR(64) NOT NULL,
  applied_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4"

sha() { sha256sum "$1" | cut -d' ' -f1; }
versions() { for f in "$dir"/*.up.sql; do b="$(basename "$f")"; echo "${b%%_*}"; done | sort; }
file_for() { ls "$dir"/"$1"_*."$2".sql 2>/dev/null | head -n1; }

case "$cmd" in
  up)
    applied=0
    for v in $(versions); do
      f="$(file_for "$v" up)"; name="$(basename "$f" .up.sql)"; sum="$(sha "$f")"
      old="$(q "SELECT checksum FROM schema_migrations WHERE version='$v'")"
      if [[ -n "$old" ]]; then
        [[ "$old" == "$sum" ]] || { echo "ERROR: $name was modified after it was applied (checksum mismatch). Add a new migration instead." >&2; exit 1; }
        continue
      fi
      echo "applying $name"
      sql < "$f" >/dev/null
      q "INSERT INTO schema_migrations (version, name, checksum) VALUES ('$v', '$name', '$sum')"
      applied=$((applied+1))
    done
    echo "done: $applied migration(s) applied"
    ;;
  status)
    for v in $(versions); do
      name="$(basename "$(file_for "$v" up)" .up.sql)"
      if [[ -n "$(q "SELECT 1 FROM schema_migrations WHERE version='$v'")" ]]; then echo "applied  $name"; else echo "pending  $name"; fi
    done
    ;;
  down)
    [[ "${CONFIRM_DESTRUCTIVE:-}" == "yes" ]] || { echo "refusing: set CONFIRM_DESTRUCTIVE=yes to revert the latest migration" >&2; exit 1; }
    v="$(q "SELECT version FROM schema_migrations ORDER BY version DESC LIMIT 1")"
    [[ -n "$v" ]] || { echo "nothing to revert"; exit 0; }
    f="$(file_for "$v" down)"; [[ -n "$f" ]] || { echo "ERROR: no down file for $v" >&2; exit 1; }
    echo "reverting $(basename "$f" .down.sql)"
    sql < "$f" >/dev/null
    q "DELETE FROM schema_migrations WHERE version='$v'"
    ;;
  *) echo "usage: $0 up|status|down" >&2; exit 2 ;;
esac
