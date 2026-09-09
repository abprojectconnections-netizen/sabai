# Database

The MySQL 8.0 core schema contains 95 tables, deliberately scoped for the first production release. It covers identity, catalog, trip planning, booking, payments, wallet and coin, partners, marketing, support and chat, AI, and operations.

Apply `migrations/000001_travel_super_app_schema.up.sql` only to a new, empty database. The paired down migration is destructive and permanently removes the schema data.

`tools/generate_core_schema.mjs` is the source for the migration. It supersedes the earlier 223-table blueprint so the application, API, and operations team can ship in manageable phases.
