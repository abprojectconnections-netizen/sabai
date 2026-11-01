# Changelog
## 0.1.0
- Restructured the single-file prototype into 35 modules.
- Added env policy (DEV/BETA/PRODUCTION), repository layer (mock + HTTP), BootGate, EnvBadge.
- Register: 8-character password rule. Login/register show server errors.
- Fixed: `.ics` text escaping did not escape `;`.
- Added tests (unit + UI), ESLint 9 config, CI workflow.
- Trips repository methods (get/update/remove/addActivity/removeActivity) for the new backend endpoints.
