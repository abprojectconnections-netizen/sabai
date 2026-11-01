# Design proposal 0001 — Bookings, Payments, Wallet, Coupons

Status: **REVISION 2 — owner policy received (spec section 7, "Payment, Pricing, Refund & Financial Policies"); still no code written.**
Revision 1 asked seven questions; section 7 below records the answers and what remains open. Where this document and the owner's policy differ, the policy wins.

## 1. Starting point (from `database/migrations/000001..000003` and the web prototype)

| Table | State today |
|---|---|
| `bookings` | usable: user_id, booking_code (unique), currency_code, total_amount, status |
| `booking_items` | usable: booking_id, item_type, reference_id, quantity, unit_amount |
| `payments` | usable: booking_id, user_id, payment_method_id, provider, provider_reference, amount, currency_code, status |
| `wallets` | usable: user_id (unique), currency_code, available_balance, pending_balance |
| `coupons` | thin: promotion_id, code (unique), max_redemptions, expires_at |
| `promotions` | thin: name, starts_at, ends_at, status — no discount rule |
| `wallet_transactions`, `cancellations`, `coupon_redemptions`, `payment_logs`, `invoices`, `receipts`, `webhook_events`, `payment_methods` | **skeletons: only id + timestamps** |
| `refunds` | skeleton + migration 000003 added status/reviewed_by/reviewed_at (no booking, amount, reason) |

The prototype currently does all of this in the browser: wallet math, 5% fee on the total, coupon discount with min-spend/max-discount, refund = 80% for flights and 100% otherwise. None of that is enforced anywhere a user cannot tamper with.

## 1a. What the owner's policy changes (vs. revision 1)

| Revision 1 assumption | Owner policy | Consequence |
|---|---|---|
| Customer pays an extra 5% on top (as in the prototype) | 5% is the **platform commission**, deducted from the **partner's settlement**; it is not VAT and not charged to the customer | The prototype's `price × 1.05` total is wrong and must be removed. Customer total = supplier price − coupon + separately recorded VAT (if applicable). Commission lives in settlements. |
| Refund = 80% flights / 100% other | Refund amount follows each **supplier's policy**; no fixed percentages or unlimited cancellation; original payment method by default, AB Wallet only with explicit consent | `refundFor()` in the web app is a mock and must not be ported. Refund amount comes from supplier cancellation terms captured at booking (price/fare-rule snapshot). |
| Server prices from tables we own | Prices come from **authorized suppliers/APIs**; MySQL pricing only for internal products; price snapshot, expiry, inventory check and **revalidation before payment** | A supplier-adapter layer is a prerequisite. Real bookings/payments stay **disabled** until a verified supplier exists. |
| Wallet can be topped up | **Top-up deferred from launch**; ledger, balance validation, audit still required; stored-value needs legal/payment compliance review before activation | Wallet balance can only come from consented refunds (and staff adjustments). No top-up endpoint is built. |
| Card/PromptPay provider TBD | PromptPay + cards through an **approved PSP** behind a modular adapter; server-side webhooks with signature, idempotency, reconciliation; frontend never marks PAID; Mock Payment only in Dev/Prototype | PSP not chosen yet (open). |
| Coupon rules open | One coupon per booking, no stacking, combinable with wallet; fixed or percent; validity, min amount, max discount, categories, usage limits, customer eligibility; Admin and approved Partners (own scope) create coupons; server-side validation; safe under concurrency | Coupons get an owner (`platform` or `partner_id`) and a scope check. |
| Refund approval open | **Hybrid**: auto only when supplier approval is verified and there is no penalty; otherwise staff approval. Statuses: requested, pending review, approved, processing, completed, rejected, failed. Audit every decision; notify customer; idempotent disbursement | Refund state machine below replaces revision 1's. |
| Documents open | Booking Confirmation, Receipt, Tax Invoice, Credit Note; issuer must be the legally responsible VAT-registered party (or authorized agent); tax rates effective-dated and configurable | Document tables and numbering; the issuer model needs legal input (open). |
| — | Separate **Orders, Payments, Refunds, Wallet Transactions, Coupons, Partner Settlements, Tax Documents**; immutable financial records; decimal-safe math; ISO currency; multi-currency-ready | Do not overload `bookings`; see revised schema. |

## 2. Principles

1. **The server computes every amount.** The client sends *what* to buy (item type + reference + quantity) and an optional coupon code, never prices or totals.
2. **Money is `DECIMAL(14,2)` in one currency per wallet** (THB first), never floats; Go side uses integer satang (int64) for arithmetic.
3. **The wallet is a ledger.** `wallets.available_balance` is a cached sum of `wallet_transactions`; every change is one row in the same DB transaction, with a CHECK-like guard (`UPDATE … SET available_balance = available_balance - ? WHERE user_id = ? AND available_balance >= ?` and require 1 row affected).
4. **Idempotency.** Every money-moving POST requires an `Idempotency-Key` header, stored with a unique index, so a retried request cannot charge or refund twice.
5. **No fake payments in production.** Wallet top-up and card/PromptPay need a real provider. Until one is chosen, those endpoints exist only behind `PAYMENT_MODE=sandbox` and are refused when `APP_ENV=production`.
6. **Every status change is audited** with the existing `audit` service, and bookings/payments/refunds only move along the allowed transitions below.

## 3. Revised data model (sketch — replaces revision 1's DDL)

Money columns are `DECIMAL(14,2)` plus `currency_code CHAR(3)` everywhere (THB at launch, never hard-coded). Financial rows are **append-only**: corrections are new rows (credit note, reversal, adjustment), never UPDATE/DELETE of amounts. Status columns are the only mutable fields and every change writes an audit row.

| Concern | Tables | Notes |
|---|---|---|
| Orders | `bookings` (the order), `booking_items` | Add: `subtotal_amount`, `discount_amount`, `tax_amount`, `total_amount`, `currency_code`, `coupon_id`, `price_snapshot_id`, `idempotency_key`. **No commission on the customer order.** Item rows carry supplier id, supplier reference, supplier price, `price_expires_at`, and the supplier's cancellation-policy snapshot (JSON). |
| Price snapshots | new `price_quotes` | Quote id, supplier, items, amounts, `expires_at`, `revalidated_at`. A booking can only be created from an unexpired quote and must revalidate before payment. |
| Payments | `payments`, `payment_logs`, `webhook_events` | `payments` already has provider/reference/amount/status; add idempotency key, `paid_at`, raw provider status. `webhook_events` unique on `(provider, external_id)`; signature verified before any state change. `payment_logs` append-only. |
| Refunds | `refunds` (+ `refund_events`) | booking, payment, amount, currency, reason, `destination` (`ORIGINAL_METHOD` default / `WALLET` requires recorded customer consent), supplier approval reference, penalty amount, status, idempotency key; `refund_events` is the status history with actor. Partial and full supported (sum of non-failed refunds ≤ captured amount, enforced in the transaction). |
| Cancellation | `cancellations` | One per booking; reason; supplier confirmation reference. |
| Wallet | `wallets`, `wallet_transactions` | Immutable ledger with `balance_after`, type (`REFUND_CREDIT`, `PAYMENT`, `ADJUSTMENT`; `TOPUP` reserved, not enabled), reference, idempotency key. Balance guard in the same transaction. |
| Coupons | `coupons`, `coupon_redemptions` | Add: owner (`PLATFORM` or partner id), `discount_type` (FIXED/PERCENT), value, `min_amount`, `max_discount`, `applies_to` categories, `starts_at`/`expires_at`, `usage_limit_total`, `usage_limit_per_user`, eligibility (e.g. new customers), `status`. Redemption row unique per booking; counter updated with a conditional `UPDATE … WHERE redeemed_count < limit` for concurrency. |
| Settlements | new `partner_settlements`, `settlement_lines` | Per partner/period: gross supplier amount, **commission** (configurable rate/base/categories, default 5%), taxes recorded separately, net payable, status. Commission rules in a new `commission_rules` table (effective-dated), not constants in code. |
| Tax | new `tax_rates` (effective-dated, configurable), `tax_documents`, `tax_document_lines`, `document_sequences` | Types: BOOKING_CONFIRMATION, RECEIPT, TAX_INVOICE, CREDIT_NOTE. Issuer, customer tax id/address/branch, numbering, issue date, taxable amount, VAT, total. Credit notes reference the original document. |
| Audit | `audit_logs` (exists) | Every approval/rejection/status change, with actor, request id, before/after. |

The matching `.down.sql` and a data-safety note (these tables hold no production data yet, so structural changes are cheap now and expensive after launch) accompany the real migration.

## 4. State machines

- **Order (booking):** `PENDING_PAYMENT → CONFIRMED → COMPLETED`; `PENDING_PAYMENT → EXPIRED` (quote/price expiry); `CONFIRMED → CANCELLATION_REQUESTED → CANCELLED`.
- **Payment:** `PENDING → PAID | FAILED | EXPIRED`; `PAID → PARTIALLY_REFUNDED → REFUNDED`. Only a verified webhook (or server-side status check) may set `PAID`.
- **Refund:** `REQUESTED → PENDING_REVIEW → APPROVED → PROCESSING → COMPLETED`, with `REJECTED` and `FAILED` terminal branches; `REQUESTED → APPROVED` is allowed automatically only when supplier approval is verified and penalty = 0.

## 5. API surface (all `/api/v1`, bearer auth, owner-scoped, envelope as today)

| Endpoint | Purpose |
|---|---|
| `POST /quotes` | Price a basket from suppliers; returns a snapshot with `expires_at`; coupon preview |
| `POST /bookings` | From a valid quote + optional single coupon + payment method; revalidates price/inventory; creates order + pending payment in one transaction; requires `Idempotency-Key` |
| `GET /bookings`, `GET /bookings/{id}` | List/detail (includes policy snapshot and documents) |
| `POST /bookings/{id}/cancel` | Creates cancellation + refund request; auto-approves only under the hybrid rules |
| `GET /refunds/{id}` | Status and history |
| `GET /wallet`, `GET /wallet/transactions` | Balance and ledger (no top-up) |
| `GET /coupons`, `POST /coupons/validate` | Usable coupons; eligibility check |
| `POST /webhooks/payments/{provider}` | Signature-verified, de-duplicated PSP callback (not user-authenticated) |
| `GET /documents/{id}` | Receipt / tax invoice / credit note |
| Portal/Admin: refund approve/reject, coupon CRUD (Admin platform-wide, Partner own scope), commission/tax config, settlement runs | Staff/Admin/Partner roles, all audited |

Notifications (this release) are created for booking, payment and refund status changes.

## 6. Environments and safety switches

- `PAYMENT_MODE=mock|sandbox|live` and `SUPPLIER_MODE=mock|sandbox|live`; **the process refuses to start** with `APP_ENV=production` unless both are `live` **and** an explicit `FINANCIAL_TRANSACTIONS_ENABLED=true` is set (default false). In Dev/Prototype only mock providers are allowed.
- Until verified supplier pricing and availability exist, `POST /bookings` returns a clear `503 FEATURE_DISABLED` outside mock mode.
- No endpoint accepts amounts from the client; no endpoint lets the client set status.

## 7. Tests

Unit tests for pricing, coupon eligibility/limits, commission and settlement, refund calculation, tax (integer satang arithmetic); sqlmock handler tests for ownership, validation, idempotent replay, double cancel, over-refund; **CI integration tests against real MySQL 8.4** for the concurrency cases (two simultaneous wallet debits, last-use coupon, duplicate webhook, double refund). The spec (7.8) requires automated tests for pricing, commissions, coupons, payment verification, wallet balance, refunds and settlements — each gets a named test suite.

## 8. Decisions

**Answered by the owner policy:** commission semantics, currency, refund basis and destination, price sources, payment methods, wallet top-up deferral, coupon rules, hybrid refunds, document types.

**Still open (these block implementation):**
1. **PSP**: which approved provider (e.g. one supporting PromptPay + cards in Thailand)? Needed for the adapter, webhook signature scheme and reconciliation file format.
2. **First supplier(s)** for each category at launch (flights, hotels, tours, …) and their API terms; internal products first?
3. **Legal issuer model**: is the platform the seller of record (it issues tax invoices for its own services/commission) or an agent for partners? Which entity and VAT registration appear on documents? This decides who issues the Tax Invoice and how settlements/credit notes are structured. Needs an accountant/lawyer.
4. **Commission details**: base (supplier price excl./incl. VAT?), which categories, and settlement cycle/payout method to partners.
5. **Tax configuration**: VAT rate handling per category and whether prices shown to customers are VAT-inclusive.
6. **Naming**: the prototype says "Sabai Wallet"; the policy says "AB Wallet". Which is the product name?
7. **Customer consent** wording/versioning for refund-to-wallet, and retention rules for financial records (Thai accounting/PDPA).
8. Who may approve refunds (roles) and any monetary approval limits.

## 9. Proposed order once the open items above are answered

1. Migration 000004 (+ down) and a **real-MySQL CI job**.
2. Provider/supplier **adapter interfaces with mock implementations**, safety switches (section 6), price quotes.
3. Coupon engine and pricing (server-side), commission rules, tax config.
4. Orders + payments with the **mock payment provider**; webhook handler with signature/idempotency tests.
5. Wallet ledger (credit via refund only) and read endpoints.
6. Cancellation, hybrid refund workflow, notifications, audit.
7. Tax documents and settlements.
8. Real PSP and supplier adapters (sandbox, then live behind the safety switches).
9. Replace the web app's mock wallet/booking/coupon state with repository calls and delete the client-side money math (including the 5% and the 80% rules).

Steps 1–6 can proceed with mocks and do not need the open decisions; steps 7–8 do.
