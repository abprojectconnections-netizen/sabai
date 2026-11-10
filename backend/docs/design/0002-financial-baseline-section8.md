# 0002 — Financial baseline from Section 8 (gap analysis, rules, RBAC, state machines)

Status: **DESIGN ONLY — Phase 1 of Section 8.18. No financial code, no migrations, nothing enabled.**
Baseline: owner's *Section 8 — Business Model & Financial Operations Specification V1.0* (Marketplace / Booking Agent). It supersedes the earlier "Section 7" policy text and design 0001. Directive (8.20): Business Model → **Financial ERD** → **OpenAPI** → Backend → Frontend → Mock Payment → Supplier → PSP → Reconciliation.
Companion documents: `0003-financial-erd.md` (data model) and `../openapi-financial-draft.yaml` (API draft, not served).

## 1. Decisions register applied

| ID | Decision | Status in spec | How this design applies it |
|---|---|---|---|
| DEC-08-01 | Marketplace / Booking Agent | LOCKED | Every booking carries `partner_id` and `seller_entity_id`; platform revenue (commission) and partner revenue are separate ledgers (principles 2–3). |
| DEC-08-02 | Internal inventory + approved partners first | LOCKED | Hotels and tours (P0) from our DB; flights/transport/attractions = adapter + mock (P1). |
| DEC-08-03 | PSP: evaluate, don't finalize | PENDING CONTRACT | Only a `PaymentProvider` interface + `mock` implementation. No PSP name appears in code or config defaults. |
| DEC-08-04 | Commission 5% default, configurable | LOCKED AS DEFAULT | A seeded **default policy row**, never a constant (prohibition 1, principle 8). |
| DEC-08-05 | Settlement weekly (Tuesday), 7-day reconciliation window | LOCKED AS DEFAULT | Stored in `partner_contracts` / `settlement_schedules`, overridable by category/risk/partner. |
| DEC-08-06 | Customer sees transparent final payable amount | LOCKED | Price snapshot with itemised lines; no "VAT included" wording unless verified for that partner. |
| DEC-08-07 | Tax-invoice issuer follows the legal seller | LEGAL/ACCOUNTING REVIEW | Documents modelled with an explicit issuer; issuing on a partner's behalf is blocked unless the contract flag says it is authorised **and** legal review is recorded. |
| DEC-08-08 | Wallet name **Sabai Wallet** (`sabai_wallet`, ledger `REFUND_CREDIT`) | LOCKED | Matches the prototype; resolves the "AB Wallet" wording of Section 7. |
| DEC-08-09 | Top-up / transfer / withdrawal | DEFERRED | Not modelled as enabled; ledger `transaction_type` list excludes them. |
| DEC-08-10/11 | Refund to original method by default; wallet only with explicit, recorded consent | LOCKED | `refund_requests.method` has no default to wallet; `wallet_consents` row required before a wallet refund can be executed. |
| DEC-08-12 | Approval matrix (≤3,000 auto / ≤5,000 officer / 5,001–50,000 finance manager / >50,000 CFO-CEO) | LOCKED AS INTERNAL PROPOSAL | Stored in `approval_limits` (config), not code. |
| DEC-08-13 | Retention policy | LEGAL/ACCOUNTING REVIEW | `retention_policies` table seeded only with what the spec states (VAT documents ≥ 5 years); every other class = `PENDING_LEGAL_REVIEW`, nothing is auto-purged. |
| DEC-08-14 | Split settlement / fund flow | PSP & LEGAL REVIEW | Design assumes **platform collects, then pays out** (settlement + payout tables). If the PSP provides split settlement the `partner_payouts` source changes, but the ledger model stays. |

## 2. What already exists in the repo and conflicts with Section 8

These are findings about code already on `main`. None is exploited today (no endpoint creates payments or bookings yet), but each must be fixed **before** any financial feature ships.

| # | Finding (evidence) | Violates | Proposed fix |
|---|---|---|---|
| F1 | `PATCH /api/v1/portal/payments/:id/verify` lets any STAFF or ADMIN set a payment to `PAID`/`FAILED`/`REFUNDED` with a bare status update (`portal/controller.go`). | 7.4 "frontend/humans never mark PAID"; 8.2.3 verify via PSP/webhook; prohibition 3 | **Remove** the endpoint. Payment status changes only from a verified webhook or a server-side PSP status query. **FIXED**: endpoint removed; an integration test asserts 404. |
| F2 | `PATCH /portal/bookings/:id/status` accepts any of PENDING/CONFIRMED/CANCELLED from any state. | 8.15 "every status change validated against permitted transitions" | Replace with transition-table-driven commands (section 5) and a `booking_status_histories` row in the same transaction. **FIXED (booking, partner, ticket, dispute)**: per-subject transition tables, row lock, 409 on illegal jump; history tables still to come with the financial schema. |
| F3 | Status updates and audit are two separate statements and the audit write error is ignored (`auditChange` discards the error). | 8.13 "database transactions for any change to financial status"; 8.11.2 | One DB transaction; if the audit insert fails, the change rolls back. **FIXED**: status change + audit row in one transaction; an audit failure rolls back (unit test) and concurrent changes apply once (integration test). |
| F4 | Roles are only CUSTOMER / PARTNER / STAFF / ADMIN; `ADMIN` can grant itself any role (`PUT /admin/users/:id/roles`). | 8.16 (9 roles, System Admin has **no** financial authority); separation of duties | Permission-based RBAC (section 4); role grants require a second approver and are audited. |  **PARTLY FIXED**: an ADMIN can no longer change their own roles (403). Permission-based RBAC and a second approver are still open.
| F5 | `user_roles` unique key is `(user_id, role_id, deleted_at)`; `deleted_at` is NULL for active rows and MySQL treats NULLs as distinct, so duplicates are not prevented. | integrity | Add a generated column `active_key = IF(deleted_at IS NULL, 1, NULL)` to the unique key (or drop soft delete on this table). Needs a real-MySQL test. **FIXED** by migration 000004 (reproduced on real MySQL first). Migration 000005 applies the same pattern to `reviews`. |
| F6 | `audit_logs` has no actor roles, reason, reference id or device info, and carries `updated_at`/`deleted_at`, i.e. it is editable by design. | 8.11.2, "not editable or deletable" | New `financial_audit_logs` (append-only, trigger-protected, hash-chained) — see ERD. Keep `audit_logs` for non-financial events. |
| F7 | Every table in migration 000001 has `deleted_at` (soft delete), including `payments`, `refunds`, `wallets`. | 8.13 "no hard deletes"; immutability | For financial tables `deleted_at` is never written; enforce with triggers and by withholding the DELETE privilege from the application DB user. |
| F8 | Skeleton tables (`commissions`, `commission_transactions`, `wallet_transactions`, `cancellations`, `invoices`, `receipts`, `webhook_events`, `payment_logs`, `partner_users`, `partner_documents`) contain only id and timestamps. | — | Replace by the Section 8.13 entities (ERD maps old → new; nothing in them holds data). |

## 3. Interpretation questions I need answered

Section 8 is clear on most points; these are the places where it is silent or two readings are possible. I have **not** guessed — the draft uses the safest reading and marks the item.

1. **Customer "Service fees" (8.6.1)** vs principle that commission is deducted from the partner. Is any fee ever charged *to the customer* by the platform? Draft: supported as an optional price line, **disabled by default**, and only enabled per contract/legal approval.
2. **Wallet-paid portion of a booking.** Credits may pay for bookings (8.8.2). If a booking is paid partly by wallet and partly by card, is the wallet portion refunded to the wallet as its "original payment method" (my reading, no extra consent needed) while the card portion needs the consent flow to become wallet credit? Draft assumes yes.
3. **"High-risk transaction" (8.10) needing two approvers** is undefined. Draft: a configurable flag set by rules (amount tier, fraud signal, supplier dispute, manual escalation); rules to be agreed with Finance.
4. **Chargebacks.** 8.10 mentions chargeback/fraud holds but there is no chargeback status model. Draft links the existing `disputes` table to payments and adds `on_hold` flags to settlement items and refunds.
5. **Timeouts** (payment intent expiry, supplier confirmation SLA, price-quote lifetime) have no values. Draft makes them configuration, defaulting to conservative placeholders marked `UNCONFIRMED`.
6. **Supplier confirmation mode per service** (instant vs request-based) — Section 8 says "per specific service workflow". Draft: `supplier_products.confirmation_mode = INSTANT | MANUAL | ADAPTER` defined per product.
7. **Who is the "seller" when a partner is not VAT-registered or where the platform sells in its own name** (8.1.2 principle 1: "unless otherwise specified through a separate contract")? Draft: `partner_contracts.seller_of_record = PARTNER | PLATFORM`, default PARTNER; PLATFORM requires an explicit legal-review record.
8. **Inventory model.** Hotels/tours tables exist but have no availability/rate calendar. 8.3.2 requires an availability check before confirmation, so the ERD adds `inventory_items`, `inventory_availability`, `inventory_holds` (beyond the 8.13 minimum list). Please confirm that is wanted for the hotel/tour P0 scope.
9. **Existing role names.** Migrating CUSTOMER/PARTNER/STAFF/ADMIN to the nine Section 8.16 roles needs a mapping decision (draft in section 4).

Blocked outside engineering (Section 8.7.3 / 8.5.3 / 8.19): PSP contract, legal/accounting review of tax-document issuance and fund flow, retention periods other than the 5-year VAT floor. Nothing in this design assumes those outcomes.

## 4. RBAC

Permission-based, enforced on the backend only (8.14, 8.17). Roles are bundles of permission codes; approval limits are data, not code.

| Role (8.16) | Key permissions | Explicitly **not** allowed |
|---|---|---|
| Customer | `booking.create`, `booking.read.own`, `payment.create.own`, `refund.request.own`, `wallet.read.own` | anything on other users' data |
| Partner Admin | `partner.manage.own`, `product.manage.own`, `booking.confirm.own` (supplier confirmation), `coupon.manage.own` | financial approvals, other partners' data |
| Partner Finance | `settlement.read.own`, `commission.read.own`, `statement.download.own` | edit anything |
| Booking Officer | `booking.read.assigned`, `booking.cancel.assigned`, `refund.request.assisted` | approve refunds, touch payments |
| Refund Officer | `refund.review`, `refund.approve` up to **their** `approval_limits` row | approve own request, exceed limit |
| Finance Manager | `refund.approve` (tier 2), `settlement.review`, `settlement.approve`, `reconciliation.run` | create-and-approve the same settlement |
| CFO / CEO | `refund.approve` (tier 3 / high-risk), `commission.policy.approve` | — |
| System Admin | `config.manage`, `user.manage`, `role.assign.request` | **any** financial approval, payment/refund/payout action |
| Auditor | read-only on audit, ledger, settlement, tax documents | any write |

Separation of duties (8.16, 8.10, enforced in the service layer *and* by DB constraints/triggers where possible): the creator of a refund request, settlement batch or payout cannot be its approver; the approver of a settlement cannot execute its payout; ≥2 distinct approvers for high-risk refunds; role assignment requires a second approver. Seeded `approval_limits`: AUTO 3,000.00 THB, REFUND_OFFICER 5,000.00, FINANCE_MANAGER 50,000.00, EXEC unlimited — editable by Finance Manager+CFO, audited.

Existing-role mapping proposal: `CUSTOMER`→Customer; `PARTNER`→Partner Admin (scoped by `partner_users`); `STAFF`→Booking Officer (no financial powers until explicitly granted another role); `ADMIN`→System Admin (financial powers removed). Requires owner confirmation (question 9).

## 5. State machines (8.15, validated server-side; transitions recorded in history tables)

**Payment (intent/transaction):** `PENDING → PROCESSING | SUCCEEDED | FAILED | EXPIRED`; `PROCESSING → SUCCEEDED | FAILED | EXPIRED`. Terminal: SUCCEEDED, FAILED, EXPIRED. Only verified webhook / PSP query may move it.

**Booking:** `DRAFT → PENDING_PAYMENT`; `PENDING_PAYMENT → PAYMENT_FAILED | PAID`; `PAID → PENDING_SUPPLIER_CONFIRMATION`; `PENDING_SUPPLIER_CONFIRMATION → CONFIRMED | REJECTED | CANCELLED`; `CONFIRMED → IN_PROGRESS | COMPLETED | CANCELLATION_REQUESTED | CANCELLED`; `IN_PROGRESS → COMPLETED`; `CANCELLATION_REQUESTED → CANCELLED | CONFIRMED` (request declined). **Invariant (8.15):** entering `REJECTED`, or a supplier-confirmation timeout, *automatically* creates a refund request for the full captured amount; a paid booking can never rest in a state with no owner.

**Refund:** `REQUESTED → UNDER_REVIEW → APPROVED | REJECTED`; `APPROVED → PROCESSING → COMPLETED | FAILED`; `FAILED → PROCESSING` (retry, new `refund_transactions` attempt). Auto path: `REQUESTED → APPROVED` only when supplier eligibility is verified, no dispute/chargeback/fraud flag, amount ≤ the AUTO limit, and cumulative refunds ≤ captured amount. Sub-statuses `supplier_refund_status` and `psp_refund_status` (PENDING/DONE/FAILED) cover "Supplier Refund Pending", "PSP Refund Pending".

**Settlement:** `PENDING → CALCULATED → UNDER_REVIEW → APPROVED | ON_HOLD`; `ON_HOLD → UNDER_REVIEW`; `APPROVED → PAYOUT_PROCESSING → PAID | FAILED`; `FAILED → PAYOUT_PROCESSING` (retry attempt). A batch has at most one non-failed payout; duplicate payout is prevented by a unique key plus a conditional status update.

## 6. Modules (8.12) and how they map to this repo

`partner`, `supplier`, `inventory`, `pricing`, `booking`, `payment`, `commission`, `settlement`, `refund`, `wallet`, `tax_document`, `reconciliation`, `audit`, `notification` become packages under `backend/internal/`. They talk through Go interfaces (e.g. `payment.Provider`, `supplier.Adapter`, `wallet.Ledger`); controllers never touch another module's tables. `notification` and `audit` already exist and are reused; `audit` gets the financial variant.

## 7. Safety switches (prohibition 6, 8.18 Phase 3–4)

Config, validated at start-up, process refuses to boot on an unsafe combination:
`PAYMENT_PROVIDER=mock|<psp>`, `SUPPLIER_MODE=mock|sandbox|live`, `FINANCIAL_TRANSACTIONS_ENABLED=false` (default). In `production`, `FINANCIAL_TRANSACTIONS_ENABLED=true` additionally requires four recorded sign-offs stored in the database (`go_live_approvals`: PSP, LEGAL, ACCOUNTING, SECURITY, each with approver and timestamp). Dev/Prototype may only use mock providers. Live payouts need an approved settlement batch (no payout without settlement approval, prohibition 4).

## 8. Impact on the web prototype (to change when it is wired to the backend)

| Prototype behaviour | Section 8 requirement | Action |
|---|---|---|
| Total = price × 1.05 | commission is not a customer charge; no uniform VAT treatment | Remove; render the server's price snapshot lines only. |
| Wallet top-up button credits ฿1,000 | top-up deferred | Hide in BETA/PROD (mock mode only, labelled "demo"). |
| Cancellation refund = 80% / 100% into the wallet automatically | supplier-policy amount; original method default; wallet needs consent | Replace with a refund *request* flow and the consent screen (wording needs legal review, 8.9.2). |
| Wallet balance computed in the browser | ledger-backed, server-side | Read `GET /wallet` only. |
| Coupons validated and applied client-side | server-side, one per booking | Call pricing quote with the coupon code. |

## 9. Phase mapping (8.18)

- **Phase 1 (this change):** role confirmation (§1, §4), contract/commission/payment/refund/settlement workflows (§5), financial ERD (0003), OpenAPI draft, RBAC matrix (§4). Remaining Phase 1 item: **partner contract model** is drafted in the ERD (`partner_contracts`, `commission_policies`) and needs Finance/Legal review of the fields.
- **Phase 2 (can start without external decisions, mock integrations only):** first, fix F1–F3, F5; then migration + a real-MySQL CI job; then `partner/supplier/pricing/booking/payment(mock)/commission/refund/wallet/settlement/reconciliation` with the state machines under test.
- **Phase 3–4:** blocked on PSP contract, legal/accounting reviews, supplier readiness, UAT, security testing, PDPA check.

## 10. Test obligations (8.17)

Each acceptance-criteria line gets a named test: price snapshot immutability, availability check before confirmation, supplier-confirmation failure → refund, commission formula (incl. the 10,000 → 500 / 9,500 example and partner-funded vs platform-funded discounts), duplicate payout prevention, refund ≤ charged − prior refunds (concurrent), approval-matrix and creator≠approver rules, consent required for wallet refunds, ledger balance invariants, webhook signature/replay/duplicate, ownership checks, no endpoint accepts amounts or statuses from the client. Concurrency tests run against a real MySQL 8.4 in CI; sqlmock alone does not count as evidence for money paths.


## Implementation status (2026-11-10)

Built and verified on a real MySQL 8.0.46 (CI repeats on 8.4): schema migrations 000006–000012, permission RBAC with two-person role grants,
mock-provider booking/payment/refund/wallet/settlement flows, hash-chained audit log. The web prototype no longer adds a 5% fee,
no longer shows top-up/withdraw, and no longer credits refunds to the wallet itself (a cancellation is a request; amount and method are server decisions).
Gaps F4 (permission-based RBAC), F6 (immutability) and F7 (audit fields) are closed for the new tables; the older `audit_logs` table is unchanged.
Defaults still waiting for business/legal confirmation: service fee off, wallet-leg refund rules, "high risk" = partner risk_level HIGH,
payment window 15 minutes, 48-hour free cancellation, two approvers above 50,000 THB (CFO required), seller of record = partner.
