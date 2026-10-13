# Travel Super App delivery checklist

## Foundation

- [x] Core MySQL schema: 95 tables and 37 foreign-key relationships.
- [x] Go/Gin starter: request IDs, response envelope, Auth and Trip routes.
- [x] OpenAPI baseline contract.
- [x] Docker Compose: MySQL, Redis, MinIO, and API.
- [x] Flutter API client with Auth and Trip repositories.
- [x] Architecture, requirements, and developer documentation.
- [x] Docker verification: MySQL migration applied (95 tables), Redis, MinIO, and API healthy.

## Current vertical slice — Authentication and trips

- [x] Persist account registration in MySQL with a bcrypt password hash.
- [x] Implement signed JWT issue; authentication middleware is the next API security task.
- [ ] Persist and list trips for the authenticated user.
- [ ] Connect Flutter login and trip-planner UI to live endpoints.
- [ ] Add unit and integration tests for this slice.

## Delivery backlog

- [x] Portal RBAC: Customer, Partner, Staff, and Admin roles enforced server-side.
- [x] Portal operational queue API: bookings, payments, partners, tickets, and disputes.
- [x] Audit trail records actor, action, affected entity, before/after state, IP, request ID, and timestamp.
- [ ] Bind authenticated Flutter session state to PortalRepository and replace dashboard fixture cards per role.
- [ ] Bind authenticated Flutter session state to PortalRepository and replace dashboard fixture cards per role.
- [ ] OAuth adapters: Google, Facebook, and LINE.
- [ ] Booking engine and availability locking.
- [ ] Payment adapters: Stripe and PromptPay with verified webhooks.
- [ ] Wallet, coin, rewards, affiliate, commissions, and promotions.
- [ ] Chat, notifications, document storage, maps, live tracking, and AI adapters.
- [ ] Admin operational flows, monitoring, backups, security tests, and deployment runbooks.

