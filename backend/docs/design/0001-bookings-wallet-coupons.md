# Design proposal 0001 — Bookings, Payments, Wallet, Coupons

Status: **PROPOSAL — for owner review, no code written.** Money is involved, so nothing is implemented until the open decisions (section 7) are answered.

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

## 2. Principles

1. **The server computes every amount.** The client sends *what* to buy (item type + reference + quantity) and an optional coupon code, never prices or totals.
2. **Money is `DECIMAL(14,2)` in one currency per wallet** (THB first), never floats; Go side uses integer satang (int64) for arithmetic.
3. **The wallet is a ledger.** `wallets.available_balance` is a cached sum of `wallet_transactions`; every change is one row in the same DB transaction, with a CHECK-like guard (`UPDATE … SET available_balance = available_balance - ? WHERE user_id = ? AND available_balance >= ?` and require 1 row affected).
4. **Idempotency.** Every money-moving POST requires an `Idempotency-Key` header, stored with a unique index, so a retried request cannot charge or refund twice.
5. **No fake payments in production.** Wallet top-up and card/PromptPay need a real provider. Until one is chosen, those endpoints exist only behind `PAYMENT_MODE=sandbox` and are refused when `APP_ENV=production`.
6. **Every status change is audited** with the existing `audit` service, and bookings/payments/refunds only move along the allowed transitions below.

## 3. Proposed migration `000004_bookings_wallet_coupons` (sketch)

```sql
-- wallet ledger
ALTER TABLE wallet_transactions
  ADD COLUMN wallet_id CHAR(36) NOT NULL,
  ADD COLUMN type VARCHAR(20) NOT NULL,              -- TOPUP, PAYMENT, REFUND, ADJUSTMENT
  ADD COLUMN direction CHAR(3) NOT NULL,             -- IN / OUT
  ADD COLUMN amount DECIMAL(14,2) NOT NULL,
  ADD COLUMN balance_after DECIMAL(14,2) NOT NULL,
  ADD COLUMN reference_type VARCHAR(30) NULL,        -- booking, refund, payment
  ADD COLUMN reference_id CHAR(36) NULL,
  ADD COLUMN description VARCHAR(255) NULL,
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD UNIQUE KEY uq_wallet_tx_idem (wallet_id, idempotency_key),
  ADD INDEX idx_wallet_tx_wallet (wallet_id, created_at);

-- bookings: what was bought, how it was priced
ALTER TABLE bookings
  ADD COLUMN subtotal_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN discount_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN fee_amount DECIMAL(14,2) NOT NULL DEFAULT 0,     -- the prototype's 5% (confirm what it is)
  ADD COLUMN coupon_id CHAR(36) NULL,
  ADD COLUMN trip_id CHAR(36) NULL,
  ADD COLUMN title VARCHAR(200) NULL, ADD COLUMN subtitle VARCHAR(255) NULL,  -- snapshot for display
  ADD COLUMN idempotency_key VARCHAR(64) NULL,
  ADD UNIQUE KEY uq_bookings_idem (user_id, idempotency_key),
  ADD INDEX idx_bookings_user (user_id, created_at);
ALTER TABLE booking_items
  ADD COLUMN title VARCHAR(200) NULL, ADD COLUMN service_date DATE NULL;   -- price snapshot lives in unit_amount

-- cancellations and refunds
ALTER TABLE cancellations
  ADD COLUMN booking_id CHAR(36) NOT NULL, ADD COLUMN user_id CHAR(36) NOT NULL,
  ADD COLUMN reason VARCHAR(255) NULL, ADD COLUMN refund_amount DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD UNIQUE KEY uq_cancellations_booking (booking_id);        -- a booking can be cancelled once
ALTER TABLE refunds
  ADD COLUMN booking_id CHAR(36) NOT NULL, ADD COLUMN payment_id CHAR(36) NULL,
  ADD COLUMN amount DECIMAL(14,2) NOT NULL, ADD COLUMN currency_code CHAR(3) NOT NULL,
  ADD COLUMN destination VARCHAR(20) NOT NULL DEFAULT 'WALLET',   -- WALLET or ORIGINAL_METHOD
  ADD INDEX idx_refunds_booking (booking_id);

-- coupons: an actual rule
ALTER TABLE coupons
  ADD COLUMN title VARCHAR(200) NULL, ADD COLUMN detail VARCHAR(255) NULL,
  ADD COLUMN discount_type VARCHAR(10) NOT NULL,                 -- PERCENT / FIXED
  ADD COLUMN discount_value DECIMAL(10,2) NOT NULL,
  ADD COLUMN min_spend DECIMAL(14,2) NOT NULL DEFAULT 0,
  ADD COLUMN max_discount DECIMAL(14,2) NULL,
  ADD COLUMN applies_to VARCHAR(100) NULL,                       -- e.g. HOTEL,FLIGHT; NULL = all
  ADD COLUMN per_user_limit INT NOT NULL DEFAULT 1,
  ADD COLUMN starts_at DATETIME(6) NULL,
  ADD COLUMN redeemed_count INT NOT NULL DEFAULT 0;
ALTER TABLE coupon_redemptions
  ADD COLUMN coupon_id CHAR(36) NOT NULL, ADD COLUMN user_id CHAR(36) NOT NULL, ADD COLUMN booking_id CHAR(36) NOT NULL,
  ADD COLUMN discount_amount DECIMAL(14,2) NOT NULL,
  ADD UNIQUE KEY uq_redemption_booking (booking_id);

-- payments: provider audit trail and webhook de-duplication
ALTER TABLE payment_logs ADD COLUMN payment_id CHAR(36) NOT NULL, ADD COLUMN event VARCHAR(50) NOT NULL, ADD COLUMN payload JSON NULL;
ALTER TABLE webhook_events ADD COLUMN provider VARCHAR(50) NOT NULL, ADD COLUMN external_id VARCHAR(150) NOT NULL, ADD COLUMN payload JSON NULL, ADD COLUMN processed_at DATETIME(6) NULL,
  ADD UNIQUE KEY uq_webhook_event (provider, external_id);
```
A matching `.down.sql` drops the added columns/keys. Because these tables have no production data yet, the `NOT NULL` additions are safe now and would not be after launch — another reason to decide before go-live.

## 4. State machines

- **Booking:** `PENDING → CONFIRMED → COMPLETED`; `PENDING|CONFIRMED → CANCELLED`. (`PENDING → EXPIRED` after a timeout if unpaid — optional.) The portal's existing status endpoint must be restricted to these transitions.
- **Payment:** `PENDING → PAID | FAILED`; `PAID → REFUNDED`.
- **Refund:** `PENDING → APPROVED → PAID` or `REJECTED` (staff review exists in migration 000003).

## 5. API surface (all `/api/v1`, bearer auth, owner-scoped, envelope as today)

| Endpoint | Purpose |
|---|---|
| `GET /wallet`, `GET /wallet/transactions` | balance and ledger |
| `POST /wallet/topups` (sandbox only) | credit the wallet via the payment provider |
| `GET /coupons`, `POST /coupons/validate` | the user's usable coupons; price preview for a basket |
| `POST /bookings` | create from items + coupon + payment method; server prices it, applies the coupon, charges the wallet or creates a pending provider payment, all in one DB transaction |
| `GET /bookings`, `GET /bookings/{id}` | list/detail |
| `POST /bookings/{id}/cancel` | applies the refund policy, writes cancellation + refund + wallet credit in one transaction |
| `POST /webhooks/payments/{provider}` | signature-verified, de-duplicated by `(provider, external_id)` |

Booking-created / cancelled / paid events also create a notification (the service from this release).

## 6. Test plan

Unit tests for pricing, coupon eligibility and refund calculation using integer satang; sqlmock tests for each handler (ownership, validation, idempotent replay, insufficient balance, double cancel, coupon over-redemption); **plus integration tests against a real MySQL 8.4 in CI** (a `services: mysql` job). For money paths sqlmock alone is not acceptable: concurrency (two simultaneous wallet payments, two redemptions of a last-use coupon) must be tested against a real database.

## 7. Decisions needed from the owner (blocking)

1. **Currency and fees.** THB only for now? What is the prototype's extra 5% on the total (VAT, service fee, payment fee)? Is it shown inside or on top of the price?
2. **Refund policy.** Prototype: 80% for flights, 100% for everything else, any time. Real policy by type and by time before the service date? Refund to wallet only, or back to the original method?
3. **Price source.** Server must price from the catalog. Hotel/flight/tour price tables are skeletons and flights are simulated. Which inventory source is first (own partner inventory, a flight API)? Until one exists, bookings cannot be safely priced server-side and must not go to production.
4. **Payment provider** for card and PromptPay (and whether wallet top-up is in scope for launch). Without it the wallet can only be spent, not funded, outside sandbox.
5. **Coupon rules.** One coupon per booking? Per-user limit default? Can coupons combine with wallet payment? Who creates coupons (staff portal)?
6. **Cancellation of paid provider payments.** Manual staff approval of refunds (existing portal queue) or automatic?
7. **Legal/finance:** receipts/tax invoices required for Thailand (e-Tax)? This affects `invoices`/`receipts`, currently skeletons.

## 8. Proposed order once approved

1. Migration 000004 + real-MySQL CI job (so later steps are verifiable).
2. Wallet ledger + `GET /wallet` (read paths first).
3. Coupons (validate/list) and pricing engine.
4. Bookings create/list/detail with wallet payment.
5. Cancel + refund.
6. Provider integration + webhooks (sandbox → production).
7. Wire the web repository and replace the mock wallet/booking state.
