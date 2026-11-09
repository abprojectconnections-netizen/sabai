//go:build integration

package integration

import (
	"strings"
	"sync"
	"testing"

	"github.com/google/uuid"
)

// These tests prove that the financial invariants hold in the DATABASE itself (CHECKs, unique keys, triggers),
// independent of any application code. A buggy or malicious service must still be unable to violate them.

func exec(t *testing.T, q string, args ...any) error {
	t.Helper()
	_, err := db.Exec(q, args...)
	return err
}

func mustOK(t *testing.T, what, q string, args ...any) {
	t.Helper()
	if err := exec(t, q, args...); err != nil {
		t.Fatalf("%s should succeed: %v", what, err)
	}
}

func mustFail(t *testing.T, what, contains, q string, args ...any) {
	t.Helper()
	err := exec(t, q, args...)
	if err == nil {
		t.Fatalf("%s must be rejected by the database, but it succeeded", what)
	}
	if contains != "" && !strings.Contains(err.Error(), contains) {
		t.Fatalf("%s rejected for the wrong reason: %v (want %q)", what, err, contains)
	}
}

const now = "UTC_TIMESTAMP(6)"

type fixture struct{ user, partner, booking, payment string }

func newFixture(t *testing.T) fixture {
	t.Helper()
	u := newUser(t)
	f := fixture{user: u.ID, partner: uuid.NewString(), booking: uuid.NewString(), payment: uuid.NewString()}
	mustOK(t, "partner", "INSERT INTO partners (id, created_at, updated_at, owner_user_id, legal_name, status) VALUES (?, "+now+", "+now+", ?, 'ร้านทดสอบ', 'APPROVED')", f.partner, f.user)
	mustOK(t, "booking", "INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status, partner_id) VALUES (?, "+now+", "+now+", ?, ?, 'THB', 10000.00, 'PAID', ?)", f.booking, f.user, "FB"+f.booking[:10], f.partner)
	mustOK(t, "payment", "INSERT INTO payments (id, created_at, updated_at, booking_id, user_id, provider, provider_reference, amount, currency_code, status, captured_amount) VALUES (?, "+now+", "+now+", ?, ?, 'mock', ?, 10000.00, 'THB', 'SUCCEEDED', 10000.00)", f.payment, f.booking, f.user, "pr-"+f.payment)
	return f
}

func TestSeededConfigurationIsDataNotCode(t *testing.T) {
	var rate string
	if err := db.QueryRow("SELECT rate FROM commission_policies WHERE scope='DEFAULT' AND status='ACTIVE'").Scan(&rate); err != nil || rate != "0.050000" {
		t.Fatalf("the 5%% default commission must be a seeded policy row, got %q (%v)", rate, err)
	}
	mustFail(t, "editing a commission rate in place", "versioned", "UPDATE commission_policies SET rate = 0.5")
	mustFail(t, "deleting a policy", "cannot be deleted", "DELETE FROM commission_policies")
	mustFail(t, "a rate above 100%", "", "INSERT INTO commission_policies (id, created_at, scope, commission_type, rate, effective_from, policy_version) VALUES (UUID(), "+now+", 'CATEGORY', 'PERCENT', 5, "+now+", 9)")
	mustFail(t, "a percent policy that also carries a fixed amount", "", "INSERT INTO commission_policies (id, created_at, scope, commission_type, rate, fixed_amount, effective_from, policy_version) VALUES (UUID(), "+now+", 'CATEGORY', 'PERCENT', 0.1, 5, "+now+", 9)")
	var n int
	db.QueryRow("SELECT COUNT(*) FROM approval_limits WHERE status = 'PROPOSAL'").Scan(&n)
	if n != 4 {
		t.Errorf("approval matrix must be seeded as a PROPOSAL (4 tiers), got %d", n)
	}
	db.QueryRow("SELECT COUNT(*) FROM retention_policies WHERE status='APPROVED'").Scan(&n)
	if n != 1 {
		t.Errorf("only the 5-year tax-document policy may be approved, got %d approved", n)
	}
	mustFail(t, "approving a retention policy without years", "", "UPDATE retention_policies SET status='APPROVED' WHERE data_class='PAYMENT'")
	mustFail(t, "a second currency that is not 3 uppercase letters", "", "INSERT INTO currencies (id, created_at, updated_at, code, name) VALUES (UUID(), "+now+", "+now+", 'th', 'x')")
}

func TestPriceSnapshotMustAddUpAndIsImmutable(t *testing.T) {
	id := uuid.NewString()
	ins := "INSERT INTO booking_price_snapshots (id, created_at, base_total, discount_total, tax_total, mandatory_fee_total, payable_total, currency_code, terms_json, captured_at) VALUES (?, " + now + ", ?, ?, ?, ?, ?, 'THB', '{}', " + now + ")"
	mustFail(t, "payable total that does not equal its parts", "", ins, uuid.NewString(), 1000, 100, 70, 0, 1000)
	mustOK(t, "consistent snapshot", ins, id, 1000, 100, 70, 30, 1000)
	mustFail(t, "changing a snapshot", "immutable", "UPDATE booking_price_snapshots SET payable_total = 1 WHERE id = ?", id)
	mustFail(t, "deleting a snapshot", "immutable", "DELETE FROM booking_price_snapshots WHERE id = ?", id)
	mustFail(t, "an unknown currency", "", "INSERT INTO booking_price_snapshots (id, created_at, base_total, payable_total, currency_code, terms_json, captured_at) VALUES (UUID(), "+now+", 1, 1, 'XXX', '{}', "+now+")")
}

func TestPaymentsCannotBeRewrittenOrOverRefunded(t *testing.T) {
	f := newFixture(t)
	mustFail(t, "refunding more than was captured", "", "UPDATE payments SET refunded_amount = 10000.01 WHERE id = ?", f.payment)
	mustOK(t, "a partial refund within the captured amount", "UPDATE payments SET refunded_amount = 4000.00 WHERE id = ?", f.payment)
	mustFail(t, "capturing more than the payment amount", "", "UPDATE payments SET captured_amount = 10000.01 WHERE id = ?", f.payment)
	mustFail(t, "changing the amount of a payment", "immutable", "UPDATE payments SET amount = 1.00 WHERE id = ?", f.payment)
	mustFail(t, "moving a payment to another booking", "immutable", "UPDATE payments SET booking_id = ? WHERE id = ?", uuid.NewString(), f.payment)
	mustFail(t, "reopening a SUCCEEDED payment", "terminal", "UPDATE payments SET status = 'PENDING' WHERE id = ?", f.payment)
	mustFail(t, "an invented payment status", "", "UPDATE payments SET status = 'PAID_BY_STAFF' WHERE id = ?", f.payment)
	mustFail(t, "deleting a payment", "cannot be deleted", "DELETE FROM payments WHERE id = ?", f.payment)
	mustFail(t, "changing a booking's total", "immutable", "UPDATE bookings SET total_amount = 1 WHERE id = ?", f.booking)
	mustFail(t, "deleting a booking", "cannot be deleted", "DELETE FROM bookings WHERE id = ?", f.booking)
	mustFail(t, "an invented booking status", "", "UPDATE bookings SET status = 'DONE' WHERE id = ?", f.booking)
}

func TestWebhookDuplicateDeliveryIsRejectedByTheDatabase(t *testing.T) {
	ev := "evt-" + uuid.NewString()
	ins := "INSERT INTO payment_webhook_events (id, created_at, provider, event_id, signature_valid, event_timestamp, received_at, payload_hash) VALUES (UUID(), " + now + ", 'mock', ?, 1, " + now + ", " + now + ", ?)"
	h := strings.Repeat("a", 64)
	mustOK(t, "first delivery", ins, ev, h)
	mustFail(t, "the same event delivered twice", "Duplicate", ins, ev, h)
	mustOK(t, "same id from another provider is a different event", strings.Replace(ins, "'mock'", "'other'", 1), ev, h)
	mustFail(t, "deleting a webhook event", "cannot be deleted", "DELETE FROM payment_webhook_events WHERE event_id = ?", ev)
}

func TestOneCouponPerBookingAndCouponLimit(t *testing.T) {
	f := newFixture(t)
	d := uuid.NewString()
	mustOK(t, "discount", "INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, funded_by, status) VALUES (?, "+now+", 'PLATFORM', 'FIXED', 100, "+now+", 'PLATFORM', 'ACTIVE')", d)
	mustFail(t, "a percent discount above 100", "", "INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, funded_by) VALUES (UUID(), "+now+", 'PLATFORM', 'PERCENT', 150, "+now+", 'PLATFORM')")
	mustFail(t, "a partner-owned discount without a partner", "", "INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, funded_by) VALUES (UUID(), "+now+", 'PARTNER', 'FIXED', 10, "+now+", 'PARTNER')")
	alloc := "INSERT INTO discount_allocations (id, created_at, booking_id, discount_id, funded_by, amount, currency_code) VALUES (UUID(), " + now + ", ?, ?, 'PLATFORM', 100, 'THB')"
	mustOK(t, "first allocation", alloc, f.booking, d)
	mustFail(t, "a second coupon on the same booking", "Duplicate", alloc, f.booking, d)

	c := uuid.NewString()
	mustOK(t, "coupon", "INSERT INTO coupons (id, created_at, updated_at, code, max_redemptions, discount_id) VALUES (?, "+now+", "+now+", ?, 2, ?)", c, "C"+c[:8], d)
	// the redemption counter pattern used by the service: conditional UPDATE, race-safe
	var wg sync.WaitGroup
	var mu sync.Mutex
	won := 0
	for i := 0; i < 10; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			res, err := db.Exec("UPDATE coupons SET redeemed_count = redeemed_count + 1 WHERE id = ? AND (max_redemptions IS NULL OR redeemed_count < max_redemptions)", c)
			if err == nil {
				if n, _ := res.RowsAffected(); n == 1 {
					mu.Lock()
					won++
					mu.Unlock()
				}
			}
		}()
	}
	wg.Wait()
	if won != 2 {
		t.Fatalf("a coupon limited to 2 redemptions was redeemed %d times under concurrency", won)
	}
	mustFail(t, "forcing the counter past the limit", "", "UPDATE coupons SET redeemed_count = 3 WHERE id = ?", c)
}

func TestCommissionFormulaIsEnforcedByTheDatabase(t *testing.T) {
	f := newFixture(t)
	var policy string
	db.QueryRow("SELECT id FROM commission_policies WHERE scope='DEFAULT' AND status='ACTIVE'").Scan(&policy)
	ins := `INSERT INTO commission_calculations (id, created_at, booking_id, partner_id, kind, refund_request_id, commission_policy_id, policy_version, commission_type, commission_rate,
		eligible_service_amount, partner_funded_discount, excluded_pass_through, commission_base_amount, commission_amount, currency_code, calculation_timestamp)
		VALUES (UUID(), ` + now + `, ?, ?, ?, ?, ?, 1, 'PERCENT', 0.05, ?, ?, ?, ?, ?, 'THB', ` + now + `)`
	// Spec example (8.4): 10,000 at 5% = 500, partner net 9,500
	mustOK(t, "10,000 at 5% = 500", ins, f.booking, f.partner, "ORIGINAL", nil, policy, 10000, 0, 0, 10000, 500)
	b2 := uuid.NewString()
	mustOK(t, "second booking", "INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, "+now+", "+now+", ?, ?, 'THB', 1, 'PAID')", b2, f.user, "FB"+b2[:10])
	mustFail(t, "commission that is not base x rate", "", ins, b2, f.partner, "ORIGINAL", nil, policy, 10000, 0, 0, 10000, 501)
	mustFail(t, "a base that ignores a partner-funded discount", "", ins, b2, f.partner, "ORIGINAL", nil, policy, 10000, 1000, 0, 10000, 500)
	mustOK(t, "partner-funded discount reduces the base: (10,000-1,000)*5% = 450", ins, b2, f.partner, "ORIGINAL", nil, policy, 10000, 1000, 0, 9000, 450)
	mustFail(t, "a negative original commission", "", ins, uuid.NewString(), f.partner, "ORIGINAL", nil, policy, 0, 0, 0, 0, -1)
	mustFail(t, "editing a calculation", "immutable", "UPDATE commission_calculations SET commission_amount = 0")
	mustFail(t, "deleting a calculation", "immutable", "DELETE FROM commission_calculations")
}

func TestSettlementSeparationOfDutiesAndNoDuplicatePayout(t *testing.T) {
	f := newFixture(t)
	maker, other := newUser(t).ID, newUser(t).ID
	batch := uuid.NewString()
	ins := `INSERT INTO partner_settlement_batches (id, created_at, updated_at, partner_id, period_from, period_to, currency_code, gross_sales, commission_total, net_amount, status, created_by, approved_by, approved_at)
		VALUES (?, ` + now + `, ` + now + `, ?, '2026-11-01', '2026-11-07', 'THB', 10000, 500, ?, ?, ?, ?, ` + now + `)`
	mustFail(t, "a batch whose net is not gross - commission", "", ins, uuid.NewString(), f.partner, 9000, "PENDING", maker, nil)
	mustFail(t, "the maker approving their own batch", "", ins, uuid.NewString(), f.partner, 9500, "APPROVED", maker, maker)
	mustFail(t, "an APPROVED batch with no approver", "", ins, uuid.NewString(), f.partner, 9500, "APPROVED", maker, nil)
	mustOK(t, "approval by a different person", ins, batch, f.partner, 9500, "APPROVED", maker, other)
	mustFail(t, "changing frozen amounts after approval", "frozen", "UPDATE partner_settlement_batches SET net_amount = 1, gross_sales = 501 WHERE id = ?", batch)
	mustFail(t, "a second batch for the same partner and period", "Duplicate", ins, uuid.NewString(), f.partner, 9500, "APPROVED", maker, other)

	po := "INSERT INTO partner_payouts (id, created_at, updated_at, batch_id, attempt_no, amount, currency_code, status, idempotency_key, failed_reason) VALUES (UUID(), " + now + ", " + now + ", ?, ?, 9500, 'THB', ?, ?, ?)"
	mustOK(t, "first payout attempt", po, batch, 1, "PROCESSING", "k1-"+batch, nil)
	mustFail(t, "a second live payout for the same batch", "Duplicate", po, batch, 2, "PROCESSING", "k2-"+batch, nil)
	mustFail(t, "the same idempotency key again", "Duplicate", po, batch, 3, "FAILED", "k1-"+batch, "x")
	mustOK(t, "a failed attempt is recorded", po, batch, 4, "FAILED", "k4-"+batch, "bank rejected")
	mustFail(t, "a FAILED payout without a reason", "", po, batch, 5, "FAILED", "k5-"+batch, nil)
	mustOK(t, "a failed payout may be retried once the live one failed", "UPDATE partner_payouts SET status='FAILED', failed_reason='timeout' WHERE batch_id = ? AND attempt_no = 1", batch)
	mustOK(t, "retry", po, batch, 6, "PROCESSING", "k6-"+batch, nil)
}

func TestRefundWalletConsentAndAmounts(t *testing.T) {
	f := newFixture(t)
	rr := uuid.NewString()
	req := "INSERT INTO refund_requests (id, created_at, updated_at, booking_id, payment_id, requested_by, reason_code, requested_amount, approved_amount, currency_code, method, status, idempotency_key) VALUES (?, " + now + ", " + now + ", ?, ?, ?, 'CUSTOMER', 4000, ?, 'THB', ?, ?, ?)"
	mustFail(t, "a refund request with no method", "", strings.Replace(req, "?, ?, 'THB', ?, ?, ?)", "?, ?, 'THB', NULL, ?, ?)", 1), rr, f.booking, f.payment, f.user, nil, "REQUESTED", "x-"+rr)
	mustFail(t, "an approved amount larger than requested", "", req, rr, f.booking, f.payment, f.user, 4000.01, "ORIGINAL_METHOD", "APPROVED", "x-"+rr)
	mustFail(t, "APPROVED with no approved amount", "", req, rr, f.booking, f.payment, f.user, nil, "ORIGINAL_METHOD", "APPROVED", "x-"+rr)
	mustOK(t, "wallet-method request", req, rr, f.booking, f.payment, f.user, 4000, "SABAI_WALLET", "APPROVED", "x-"+rr)
	mustFail(t, "switching the method after the request", "immutable", "UPDATE refund_requests SET method = 'ORIGINAL_METHOD' WHERE id = ?", rr)

	tx := "INSERT INTO refund_transactions (id, created_at, updated_at, refund_request_id, attempt_no, destination, amount, currency_code, status, idempotency_key) VALUES (UUID(), " + now + ", " + now + ", ?, 1, ?, ?, 'THB', 'PENDING', ?)"
	mustFail(t, "a wallet refund without recorded consent", "consent", tx, rr, "SABAI_WALLET", 4000, "t1-"+rr)

	cv := uuid.NewString()
	mustOK(t, "consent wording", "INSERT INTO consent_versions (id, created_at, version, locale, text, text_sha256) VALUES (?, "+now+", ?, 'th', 'ยินยอมรับเป็นเครดิต', ?)", cv, int(uuid.New().ID()>>1), strings.Repeat("b", 64))
	mustFail(t, "making unapproved wording effective", "", "UPDATE consent_versions SET effective_from = "+now+" WHERE id = ?", cv)
	mustOK(t, "consent", "INSERT INTO wallet_consents (id, created_at, user_id, booking_id, refund_request_id, consent_version_id, text_sha256_shown, presented_at, accepted_at) VALUES (UUID(), "+now+", ?, ?, ?, ?, ?, "+now+", "+now+")", f.user, f.booking, rr, cv, strings.Repeat("b", 64))
	mustFail(t, "an amount that differs from the approved amount", "approved amount", tx, rr, "SABAI_WALLET", 4000.01, "t2-"+rr)
	mustOK(t, "wallet refund with consent and the approved amount", tx, rr, "SABAI_WALLET", 4000, "t3-"+rr)
	mustFail(t, "a second live disbursement for the same refund", "Duplicate", strings.Replace(tx, "attempt_no, destination", "attempt_no, destination", 1), rr, "SABAI_WALLET", 4000, "t4-"+rr)
	mustFail(t, "editing consent", "immutable", "UPDATE wallet_consents SET accepted_at = "+now)

	rr2 := uuid.NewString()
	mustOK(t, "request for a not yet approved refund", req, rr2, f.booking, f.payment, f.user, nil, "ORIGINAL_METHOD", "REQUESTED", "x-"+rr2)
	mustFail(t, "executing a refund that is not approved", "APPROVED", tx, rr2, "ORIGINAL_METHOD", 4000, "t5-"+rr2)
	ap := "INSERT INTO refund_approvals (id, created_at, refund_request_id, approver_user_id, approver_role, decision, decided_at) VALUES (UUID(), " + now + ", ?, ?, 'REFUND_OFFICER', 'APPROVE', " + now + ")"
	mustOK(t, "approval", ap, rr, f.user)
	mustFail(t, "the same person approving twice", "Duplicate", ap, rr, f.user)
	mustFail(t, "editing an approval", "immutable", "UPDATE refund_approvals SET decision='REJECT'")
}

func TestWalletLedgerIsAnAppendOnlyChain(t *testing.T) {
	f := newFixture(t)
	w := uuid.NewString()
	mustOK(t, "wallet", "INSERT INTO wallets (id, created_at, updated_at, user_id, currency_code, available_balance, pending_balance) VALUES (?, "+now+", "+now+", ?, 'THB', 0, 0)", w, f.user)
	mustFail(t, "a second wallet for the same user and currency", "Duplicate", "INSERT INTO wallets (id, created_at, updated_at, user_id, currency_code, available_balance, pending_balance) VALUES (UUID(), "+now+", "+now+", ?, 'THB', 0, 0)", f.user)
	mustFail(t, "a negative wallet balance", "", "UPDATE wallets SET available_balance = -1 WHERE id = ?", w)
	mustFail(t, "deleting a wallet", "cannot be deleted", "DELETE FROM wallets WHERE id = ?", w)

	ins := "INSERT INTO wallet_ledger_entries (id, created_at, wallet_id, user_id, transaction_type, reference_type, reference_id, credit_amount, debit_amount, balance_after, currency_code, idempotency_key, prev_entry_id) VALUES (?, " + now + ", ?, ?, ?, 'REFUND', ?, ?, ?, ?, 'THB', ?, ?)"
	e1, e2 := uuid.NewString(), uuid.NewString()
	mustOK(t, "first credit 4,000", ins, e1, w, f.user, "REFUND_CREDIT", f.booking, 4000, 0, 4000, "i1", nil)
	mustFail(t, "a second ROOT entry", "Duplicate", ins, uuid.NewString(), w, f.user, "REFUND_CREDIT", f.booking, 1, 0, 1, "i-root", nil)
	mustFail(t, "a wrong running balance", "balance_after", ins, uuid.NewString(), w, f.user, "REFUND_CREDIT", f.booking, 100, 0, 9999, "i2", e1)
	mustFail(t, "debiting more than the balance", "", ins, uuid.NewString(), w, f.user, "PAYMENT_DEBIT", f.booking, 0, 5000, -1000, "i3", e1)
	mustFail(t, "a top-up (not allowed in this phase)", "", ins, uuid.NewString(), w, f.user, "TOPUP", f.booking, 100, 0, 4100, "i4", e1)
	mustFail(t, "credit and debit in the same row", "", strings.Replace(ins, "?, ?, ?, 'THB'", "100, 100, ?, 'THB'", 1), uuid.NewString(), w, f.user, "REFUND_CREDIT", f.booking, 4000, "i5", e1)
	mustFail(t, "a debit labelled as a credit", "", ins, uuid.NewString(), w, f.user, "REFUND_CREDIT", f.booking, 0, 100, 3900, "i6", e1)
	mustOK(t, "debit 1,500 by the wallet", ins, e2, w, f.user, "PAYMENT_DEBIT", f.booking, 0, 1500, 2500, "i7", e1)
	mustFail(t, "replaying the same idempotency key", "Duplicate", ins, uuid.NewString(), w, f.user, "PAYMENT_DEBIT", f.booking, 0, 1500, 1000, "i7", e2)
	mustFail(t, "editing a ledger row", "append-only", "UPDATE wallet_ledger_entries SET credit_amount = 9 WHERE id = ?", e1)
	mustFail(t, "deleting a ledger row", "append-only", "DELETE FROM wallet_ledger_entries WHERE id = ?", e1)

	// Two concurrent spends computed from the same balance: exactly one may extend the chain (no double spend).
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if err := exec(t, ins, uuid.NewString(), w, f.user, "PAYMENT_DEBIT", f.booking, 0, 2000, 500, "c"+uuid.NewString(), e2); err == nil {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}(i)
	}
	wg.Wait()
	if ok != 1 {
		t.Fatalf("%d concurrent spends from the same balance were accepted, want exactly 1", ok)
	}
	var sum string
	db.QueryRow("SELECT SUM(credit_amount - debit_amount) FROM wallet_ledger_entries WHERE wallet_id = ?", w).Scan(&sum)
	var last string
	db.QueryRow("SELECT balance_after FROM wallet_ledger_entries WHERE wallet_id = ? ORDER BY seq DESC LIMIT 1", w).Scan(&last)
	if sum != last {
		t.Fatalf("ledger sum %s does not equal the latest balance %s", sum, last)
	}
}

func TestFinancialAuditLogIsAppendOnly(t *testing.T) {
	id := uuid.NewString()
	mustOK(t, "audit row", "INSERT INTO financial_audit_logs (id, occurred_at, entity_type, entity_id, action, row_hash) VALUES (?, "+now+", 'payment', ?, 'payment.created', ?)", id, uuid.NewString(), strings.Repeat("c", 64))
	mustFail(t, "editing an audit row", "append-only", "UPDATE financial_audit_logs SET action = 'x' WHERE id = ?", id)
	mustFail(t, "deleting an audit row", "append-only", "DELETE FROM financial_audit_logs WHERE id = ?", id)
	mustFail(t, "an unknown actor type", "", "INSERT INTO financial_audit_logs (id, occurred_at, actor_type, entity_type, entity_id, action, row_hash) VALUES (UUID(), "+now+", 'ROBOT', 'payment', UUID(), 'x', ?)", strings.Repeat("c", 64))
	f := newFixture(t)
	mustOK(t, "history row", "INSERT INTO booking_status_histories (id, created_at, booking_id, from_status, to_status, actor_type) VALUES (?, "+now+", ?, 'PENDING_PAYMENT', 'PAID', 'WEBHOOK')", id, f.booking)
	mustFail(t, "editing a status history", "append-only", "UPDATE booking_status_histories SET to_status = 'CANCELLED' WHERE id = ?", id)
	mustFail(t, "deleting a status history", "append-only", "DELETE FROM booking_status_histories WHERE id = ?", id)
}
