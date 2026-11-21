# Database

The MySQL core schema has 139 tables after 19 migrations (counted on a real MySQL after applying every migration; 95 at the first release). It covers identity, catalog, trip planning, booking, payments, wallet and coin, partners, marketing, support and chat, AI, and operations.

## Applying migrations

Use the runner (needs only the `mysql` client); it records versions and SHA-256 checksums in `schema_migrations`, refuses to run if an already-applied migration file was edited, and `down` reverts only the latest migration and requires `CONFIRM_DESTRUCTIVE=yes`.

```bash
MYSQL_HOST=127.0.0.1 MYSQL_PORT=3306 MYSQL_DATABASE=travel_super_app MYSQL_USER=root MYSQL_PASSWORD=... database/migrate.sh up
database/migrate.sh status
CONFIRM_DESTRUCTIVE=yes database/migrate.sh down   # destructive: reverts the latest migration only
```

`docker compose up` runs it automatically through the `migrate` service; the API starts only after it succeeds. Do not mount the migrations folder into `docker-entrypoint-initdb.d` (it would also execute the `.down.sql` files).

Never edit an applied migration; add a new numbered one. 000002 is intentionally a no-op (000001 already had its column).

Verification status: all migrations were applied, rolled back and re-applied on MySQL 8.0.46 locally, and CI repeats this on MySQL 8.4 (the version docker-compose uses) before running the integration tests.

`tools/generate_core_schema.mjs` is the source for the migration. It supersedes the earlier 223-table blueprint so the application, API, and operations team can ship in manageable phases.

## Backup and restore

```bash
MYSQL_DATABASE=travel_super_app MYSQL_USER=root MYSQL_PASSWORD=... database/backup.sh [file.sql.gz]   # read-only, consistent snapshot
CONFIRM_DESTRUCTIVE=yes MYSQL_DATABASE=<new empty db> ... database/restore.sh file.sql.gz
```

`restore.sh` is non-destructive by design: it restores **only into an empty database** and refuses when the target already has
tables, when `APP_ENV` is `prod`/`production`, or without `CONFIRM_DESTRUCTIVE=yes`. To replace a database, restore into a new
one and switch over (or have an operator drop the old one deliberately). CI backs up a seeded database, restores it into a new
one, compares table and row counts, and checks all three refusals. Verified locally on MySQL 8.0.46 (139 tables,
61 triggers identical after restore). `scripts/local.sh backup|restore` wraps both for the local Docker database.
