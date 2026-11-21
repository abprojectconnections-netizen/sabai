#!/usr/bin/env bash
# Logical backup of one MySQL database to a gzip file (needs the `mysqldump` client). Read-only against the database.
#
#   database/backup.sh [output-file]      default: backups/<database>-<UTC timestamp>.sql.gz
#
# Connection (environment): MYSQL_DATABASE (required), MYSQL_USER (default root), MYSQL_PASSWORD,
# MYSQL_HOST (default 127.0.0.1), MYSQL_PORT (default 3306).
set -euo pipefail
: "${MYSQL_DATABASE:?MYSQL_DATABASE is required}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
out="${1:-$root/backups/${MYSQL_DATABASE}-$(date -u +%Y%m%dT%H%M%SZ).sql.gz}"
mkdir -p "$(dirname "$out")"
[[ -n "${MYSQL_PASSWORD:-}" ]] && export MYSQL_PWD="$MYSQL_PASSWORD"
tmp="$out.partial"
trap 'rm -f "$tmp"' EXIT
# --single-transaction: consistent InnoDB snapshot without locking writers.
mysqldump -h "${MYSQL_HOST:-127.0.0.1}" -P "${MYSQL_PORT:-3306}" --protocol=TCP -u "${MYSQL_USER:-root}" \
  --single-transaction --routines --triggers --events --no-tablespaces --default-character-set=utf8mb4 \
  "$MYSQL_DATABASE" | gzip -9 > "$tmp"
gzip -t "$tmp"
mv "$tmp" "$out"
trap - EXIT
echo "backup written: $out ($(du -h "$out" | cut -f1))"
