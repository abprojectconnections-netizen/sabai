//go:build integration

package integration

import (
	"fmt"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/google/uuid"
)

// paid creates a booking for qty items and drives it to PAID through the real payment + webhook path.
func paid(t *testing.T, i inv, u user, qty int, coupon string) (bookingID string, total string) {
	t.Helper()
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "b-"+uuid.NewString(), i.body(qty, coupon))
	if b.Status != 201 {
		t.Fatalf("booking: %d %v", b.Status, b.Body)
	}
	bid := b.data()["id"].(string)
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, "i-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR"})
	if in.Status != 201 {
		t.Fatalf("intent: %d %v", in.Status, in.Body)
	}
	amount := in.data()["amount"].(string)
	if r := sendWebhook(t, webhookBody("ev-"+uuid.NewString(), "CHARGE_SUCCEEDED", in.data()["payment_reference"].(string), amount, time.Now()), ""); r.data()["result"] != "APPLIED" {
		t.Fatalf("webhook: %v", r.Body)
	}
	return bid, amount
}

func refundReq(t *testing.T, u user, bid, method string) resp {
	return idem(t, "POST", "/api/v1/refunds", u.Token, "r-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": method, "reason_code": "CUSTOMER_CANCELLATION"})
}

func col(t *testing.T, q string, args ...any) string {
	var s string
	if err := db.QueryRow(q, args...).Scan(&s); err != nil {
		t.Fatalf("%s: %v", q, err)
	}
	return s
}

func TestSmallRefundInsideTheFreeWindowIsAutomatic(t *testing.T) {
	i := newInventory(t, 10, "1000.00")
	u := newUser(t)
	bid, _ := paid(t, i, u, 2, "")
	r := refundReq(t, u, bid, "ORIGINAL_METHOD")
	if r.Status != 201 || r.data()["status"] != "COMPLETED" || r.data()["auto_approved"] != true || r.data()["calculated_amount"] != "2000.00" {
		t.Fatalf("auto refund: %d %v", r.Status, r.Body)
	}
	if col(t, "SELECT refunded_amount FROM payments WHERE booking_id = ?", bid) != "2000.00" || col(t, "SELECT status FROM bookings WHERE id = ?", bid) != "CANCELLED" {
		t.Fatal("payment must show the refund and the booking must be cancelled")
	}
	if col(t, "SELECT quantity_sold FROM inventory_availability WHERE id = ?", i.avail) != "0" {
		t.Error("a fully refunded booking must give its seats back")
	}
	if col(t, "SELECT COUNT(*) FROM refund_transactions rt JOIN refund_requests r ON r.id = rt.refund_request_id WHERE r.booking_id = ?", bid) != "1" {
		t.Error("exactly one disbursement")
	}
	if r2 := refundReq(t, u, bid, "ORIGINAL_METHOD"); r2.Status != 409 {
		t.Errorf("a second refund for a refunded booking = %d", r2.Status)
	}
	other := newUser(t)
	if r3 := refundReq(t, other, bid, "ORIGINAL_METHOD"); r3.Status != 404 {
		t.Errorf("refunding someone else's booking = %d", r3.Status)
	}
}

func TestRefundAfterTheFreeWindowDueNothing(t *testing.T) {
	i := newInventory(t, 5, "1000.00")
	u := newUser(t)
	bid, _ := paid(t, i, u, 1, "")
	mustOK(t, "service is tomorrow", "UPDATE booking_items SET service_date = DATE_ADD(CURDATE(), INTERVAL 1 DAY) WHERE booking_id = ?", bid)
	if r := refundReq(t, u, bid, "ORIGINAL_METHOD"); r.Status != 400 {
		t.Errorf("inside the 48h no-refund window = %d %v", r.Status, r.Body)
	}
	if r := refundReq(t, u, bid, "CASH"); r.Status != 400 {
		t.Errorf("an unknown refund method = %d", r.Status)
	}
}

func TestRefundApprovalMatrixAndSeparationOfDuties(t *testing.T) {
	i := newInventory(t, 50, "1000.00")
	officer, manager, cfo, cfo2 := newUser(t, "REFUND_OFFICER"), newUser(t, "FINANCE_MANAGER"), newUser(t, "CFO_CEO"), newUser(t, "CFO_CEO")
	approve := func(who user, id string) resp {
		return call(t, "POST", "/api/v1/portal/refunds/"+id+"/approve", who.Token, map[string]string{"reason": "ok"})
	}

	// 4,000: above the automatic limit (3,000), within an officer's limit (5,000)
	u := newUser(t)
	bid, _ := paid(t, i, u, 4, "")
	r := refundReq(t, u, bid, "ORIGINAL_METHOD")
	id := r.data()["id"].(string)
	if r.data()["status"] != "UNDER_REVIEW" || r.data()["auto_approved"] != false {
		t.Fatalf("4,000 must need a human: %v", r.Body)
	}
	if x := call(t, "POST", "/api/v1/portal/refunds/"+id+"/approve", u.Token, nil); x.Status != 403 {
		t.Errorf("the customer approving = %d", x.Status)
	}
	if x := approve(officer, id); x.Status != 200 || x.data()["status"] != "COMPLETED" {
		t.Fatalf("officer approves 4,000: %d %v", x.Status, x.Body)
	}

	// an approver who is also the requester
	self := newUser(t, "REFUND_OFFICER")
	bid2, _ := paid(t, i, self, 4, "")
	id2 := refundReq(t, self, bid2, "ORIGINAL_METHOD").data()["id"].(string)
	if x := approve(self, id2); x.Status != 403 {
		t.Errorf("approving your own refund = %d", x.Status)
	}

	// 6,000: above an officer's limit, a finance manager may approve
	u3 := newUser(t)
	bid3, _ := paid(t, i, u3, 6, "")
	id3 := refundReq(t, u3, bid3, "ORIGINAL_METHOD").data()["id"].(string)
	if x := approve(officer, id3); x.Status != 403 {
		t.Errorf("officer above the limit = %d", x.Status)
	}
	if x := approve(manager, id3); x.Status != 200 || x.data()["status"] != "COMPLETED" {
		t.Fatalf("manager approves 6,000: %v", x.Body)
	}
	if col(t, "SELECT COUNT(*) FROM refund_approvals WHERE refund_request_id = ?", id3) != "1" {
		t.Error("one approval row")
	}

	// 60,000: a finance manager (limit 50,000) cannot; it needs two distinct approvers including the CFO
	big := newInventory(t, 5, "60000.00")
	u4 := newUser(t)
	bid4, _ := paid(t, big, u4, 1, "")
	id4 := refundReq(t, u4, bid4, "ORIGINAL_METHOD").data()["id"].(string)
	if x := approve(manager, id4); x.Status != 403 {
		t.Errorf("manager above 50,000 = %d", x.Status)
	}
	if x := approve(cfo, id4); x.Status != 200 || x.data()["status"] != "UNDER_REVIEW" {
		t.Fatalf("first CFO approval must not be enough: %v", x.Body)
	}
	if x := approve(cfo, id4); x.Status != 409 {
		t.Errorf("the same person approving twice = %d", x.Status)
	}
	if col(t, "SELECT status FROM refund_requests WHERE id = ?", id4) != "UNDER_REVIEW" {
		t.Error("still under review after one approval")
	}
	if x := approve(cfo2, id4); x.Status != 200 || x.data()["status"] != "COMPLETED" {
		t.Fatalf("second distinct approver: %v", x.Body)
	}

	// a rejection
	u5 := newUser(t)
	bid5, _ := paid(t, i, u5, 4, "")
	id5 := refundReq(t, u5, bid5, "ORIGINAL_METHOD").data()["id"].(string)
	if x := call(t, "POST", "/api/v1/portal/refunds/"+id5+"/reject", officer.Token, map[string]string{"reason": "policy"}); x.Status != 200 || x.data()["status"] != "REJECTED" {
		t.Fatalf("reject: %v", x.Body)
	}
	if x := approve(officer, id5); x.Status != 409 {
		t.Errorf("approving a rejected refund = %d", x.Status)
	}
	// a system administrator has no refund authority at all
	if x := call(t, "POST", "/api/v1/portal/refunds/"+id5+"/approve", newUser(t, "ADMIN").Token, nil); x.Status != 403 {
		t.Errorf("system admin approving a refund = %d", x.Status)
	}
}

func TestConcurrentRefundRequestsAndExecutionsPayOnce(t *testing.T) {
	i := newInventory(t, 20, "1000.00")
	u := newUser(t)
	bid, _ := paid(t, i, u, 4, "")
	var wg sync.WaitGroup
	var mu sync.Mutex
	got := map[int]int{}
	ids := map[string]bool{}
	for n := 0; n < 8; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r := refundReq(t, u, bid, "ORIGINAL_METHOD")
			mu.Lock()
			got[r.Status]++
			if id, ok := r.data()["id"].(string); ok {
				ids[id] = true
			}
			mu.Unlock()
		}()
	}
	wg.Wait()
	if got[201] != 1 || len(ids) != 1 {
		t.Fatalf("8 concurrent refund requests for one booking: %v, ids %d", got, len(ids))
	}
	id := ""
	for k := range ids {
		id = k
	}
	officer := newUser(t, "REFUND_OFFICER")
	var wg2 sync.WaitGroup
	for n := 0; n < 6; n++ {
		wg2.Add(1)
		go func() {
			defer wg2.Done()
			call(t, "POST", "/api/v1/portal/refunds/"+id+"/approve", officer.Token, nil)
		}()
	}
	wg2.Wait()
	if col(t, "SELECT COUNT(*) FROM refund_transactions WHERE refund_request_id = ?", id) != "1" || col(t, "SELECT refunded_amount FROM payments WHERE booking_id = ?", bid) != "4000.00" {
		t.Fatalf("refund executed more than once: %s tx, refunded %s", col(t, "SELECT COUNT(*) FROM refund_transactions WHERE refund_request_id = ?", id), col(t, "SELECT refunded_amount FROM payments WHERE booking_id = ?", bid))
	}
}

func TestWalletRefundNeedsLegallyApprovedConsentAndPostsAnAppendOnlyLedger(t *testing.T) {
	i := newInventory(t, 10, "1000.00")
	u := newUser(t)
	bid, _ := paid(t, i, u, 2, "")
	r := refundReq(t, u, bid, "SABAI_WALLET")
	id := r.data()["id"].(string)
	if r.data()["status"] != "APPROVED" {
		t.Fatalf("an auto-eligible wallet refund is approved but must not be paid yet: %v", r.Body)
	}
	if col(t, "SELECT COUNT(*) FROM wallet_ledger_entries WHERE user_id = ?", u.ID) != "0" {
		t.Fatal("nothing may be credited before consent")
	}
	// wording that legal has not approved cannot be consented to
	cv, hash := uuid.NewString(), strings.Repeat("d", 64)
	mustOK(t, "draft wording", "INSERT INTO consent_versions (id, created_at, version, locale, text, text_sha256) VALUES (?, "+now+", ?, 'th', 'ร่างข้อความ', ?)", cv, int(uuid.New().ID()>>1), hash)
	if x := idem(t, "POST", "/api/v1/refunds/"+id+"/consent", u.Token, "", map[string]any{"consent_version_id": cv, "text_sha256": hash}); x.Status != 400 {
		t.Fatalf("consent to unapproved wording = %d", x.Status)
	}
	lawyer := newUser(t).ID
	mustOK(t, "legal approves the wording", "UPDATE consent_versions SET legal_approved_by = ?, legal_approved_at = "+now+", effective_from = DATE_SUB("+now+", INTERVAL 1 DAY) WHERE id = ?", lawyer, cv)
	if x := idem(t, "POST", "/api/v1/refunds/"+id+"/consent", u.Token, "", map[string]any{"consent_version_id": cv, "text_sha256": strings.Repeat("e", 64)}); x.Status != 400 {
		t.Fatalf("a hash that differs from what was approved = %d", x.Status)
	}
	if x := idem(t, "POST", "/api/v1/refunds/"+id+"/consent", newUser(t).Token, "", map[string]any{"consent_version_id": cv, "text_sha256": hash}); x.Status != 404 {
		t.Fatalf("someone else's consent = %d", x.Status)
	}
	if x := idem(t, "POST", "/api/v1/refunds/"+id+"/consent", u.Token, "", map[string]any{"consent_version_id": cv, "text_sha256": hash}); x.Status != 200 {
		t.Fatalf("consent: %d %v", x.Status, x.Body)
	}
	if col(t, "SELECT status FROM refund_requests WHERE id = ?", id) != "COMPLETED" {
		t.Fatalf("after consent the approved refund is paid into the wallet, status %s", col(t, "SELECT status FROM refund_requests WHERE id = ?", id))
	}
	if col(t, "SELECT available_balance FROM wallets WHERE user_id = ?", u.ID) != "2000.00" || col(t, "SELECT balance_after FROM wallet_ledger_entries WHERE user_id = ?", u.ID) != "2000.00" {
		t.Fatal("wallet balance must equal the ledger")
	}
	if col(t, "SELECT transaction_type FROM wallet_ledger_entries WHERE user_id = ?", u.ID) != "REFUND_CREDIT" {
		t.Error("the only entry is a refund credit")
	}
}

func partnerFunded(t *testing.T, partner, value string) string {
	d, c, code := uuid.NewString(), uuid.NewString(), "P"+strings.ToUpper(uuid.NewString()[:8])
	mustOK(t, "partner discount", "INSERT INTO discounts (id, created_at, owner_type, owner_partner_id, discount_type, value, valid_from, funded_by, status) VALUES (?, "+now+", 'PARTNER', ?, 'FIXED', ?, '2020-01-01', 'PARTNER', 'ACTIVE')", d, partner, value)
	mustOK(t, "coupon", "INSERT INTO coupons (id, created_at, updated_at, code, max_redemptions, discount_id) VALUES (?, "+now+", "+now+", ?, 10, ?)", c, code, d)
	return code
}

func TestSettlementCommissionApprovalAndPayout(t *testing.T) {
	i := newInventory(t, 20, "10000.00")
	u := newUser(t)
	plain, _ := paid(t, i, u, 1, "")                                                // base 10,000 -> commission 500, net 9,500 (the specification example)
	withPartnerDiscount, _ := paid(t, i, u, 1, partnerFunded(t, i.partner, "1000")) // partner funds 1,000 -> base 9,000 -> 450
	withPlatformDiscount, _ := paid(t, i, u, 1, newCoupon(t, "FIXED", "500", 10))   // platform funds it: base stays 10,000 -> 500
	refunded, _ := paid(t, i, u, 1, "")
	notYet, _ := paid(t, i, u, 1, "")
	for _, b := range []string{plain, withPartnerDiscount, withPlatformDiscount, refunded} {
		mustOK(t, "service happened 30 days ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE booking_id = ?", b)
	}
	mustOK(t, "service ended 2 days ago: inside the 7-day reconciliation window", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 2 DAY) WHERE booking_id = ?", notYet)
	mustOK(t, "one booking was refunded", "UPDATE payments SET refunded_amount = 10000.00 WHERE booking_id = ?", refunded)

	maker, checker, other := newUser(t, "FINANCE_MANAGER"), newUser(t, "FINANCE_MANAGER"), newUser(t, "FINANCE_MANAGER")
	from, to := time.Now().UTC().AddDate(0, 0, -40).Format("2006-01-02"), time.Now().UTC().Format("2006-01-02")
	build := func(who user) resp {
		return call(t, "POST", "/api/v1/portal/settlements/build", who.Token, map[string]string{"partner_id": i.partner, "period_from": from, "period_to": to})
	}
	if x := call(t, "POST", "/api/v1/portal/settlements/build", newUser(t, "ADMIN").Token, map[string]string{"partner_id": i.partner, "period_from": from, "period_to": to}); x.Status != 403 {
		t.Errorf("system admin building a settlement = %d", x.Status)
	}
	b := build(maker)
	if b.Status != 201 || b.data()["items"] != float64(3) || b.data()["gross"] != "29000.00" || b.data()["commission"] != "1450.00" || b.data()["net"] != "27550.00" {
		t.Fatalf("3 eligible bookings (10,000 + 9,000 + 10,000), commission 500 + 450 + 500: %v", b.Body)
	}
	id := b.data()["id"].(string)
	if x := build(maker); x.Status != 409 {
		t.Errorf("a second batch for the same partner and period = %d", x.Status)
	}
	if col(t, "SELECT COUNT(*) FROM commission_calculations WHERE commission_amount = 500.00 AND commission_rate = 0.05 AND booking_id = ?", plain) != "1" {
		t.Error("the specification example: 10,000 at 5% = 500")
	}
	if col(t, "SELECT COUNT(*) FROM partner_settlement_items WHERE booking_id IN (?, ?)", refunded, notYet) != "0" {
		t.Error("a refunded booking and one inside the reconciliation window must not be settled")
	}
	pay := func(who user, step string) resp {
		return call(t, "POST", "/api/v1/portal/settlements/"+id+"/"+step, who.Token, nil)
	}
	if x := pay(maker, "approve"); x.Status != 409 {
		t.Errorf("approving before review = %d", x.Status)
	}
	if x := pay(checker, "review"); x.Status != 200 {
		t.Fatalf("review: %v", x.Body)
	}
	if x := pay(maker, "approve"); x.Status != 403 {
		t.Errorf("the maker approving their own batch = %d", x.Status)
	}
	if x := pay(checker, "approve"); x.Status != 403 {
		t.Errorf("the reviewer approving the batch they reviewed = %d", x.Status)
	}
	if x := pay(other, "approve"); x.Status != 200 {
		t.Fatalf("an independent approver: %v", x.Body)
	}
	if x := pay(other, "payout"); x.Status != 409 {
		t.Errorf("payout with no verified bank account = %d", x.Status)
	}
	mustOK(t, "verified bank account", "INSERT INTO partner_bank_accounts (id, created_at, partner_id, bank_code, account_name, account_number_enc, account_last4, verified_at, verified_by, valid_from) VALUES (UUID(), "+now+", ?, 'KBANK', 'ร้านทดสอบ', 'enc', '1234', "+now+", ?, DATE_SUB("+now+", INTERVAL 1 DAY))", i.partner, other.ID)
	var wg sync.WaitGroup
	var mu sync.Mutex
	codes := map[int]int{}
	for n := 0; n < 5; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			s := pay(other, "payout").Status
			mu.Lock()
			codes[s]++
			mu.Unlock()
		}()
	}
	wg.Wait()
	if codes[200] != 1 || col(t, "SELECT COUNT(*) FROM partner_payouts WHERE batch_id = ? AND status = 'PAID'", id) != "1" || col(t, "SELECT status FROM partner_settlement_batches WHERE id = ?", id) != "PAID" {
		t.Fatalf("5 concurrent payout requests: %v", codes)
	}
	if col(t, "SELECT amount FROM partner_payouts WHERE batch_id = ?", id) != "27550.00" {
		t.Error("the payout equals the batch net")
	}
	// the same bookings can never be settled again
	later := call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": time.Now().UTC().AddDate(0, 0, -39).Format("2006-01-02"), "period_to": to})
	if later.Status != 409 {
		t.Errorf("re-settling the same bookings = %d %v", later.Status, later.Body)
	}
	_ = fmt.Sprint
}

func TestRefundAfterSettlementIsReversedInTheNextBatch(t *testing.T) {
	i := newInventory(t, 20, "10000.00")
	u := newUser(t)
	b, _ := paid(t, i, u, 1, "")
	other, _ := paid(t, i, u, 1, "") // keeps the first batch positive and the second one non-empty
	for _, id := range []string{b, other} {
		mustOK(t, "service long ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE booking_id = ?", id)
	}
	maker := newUser(t, "FINANCE_MANAGER")
	day := func(n int) string { return time.Now().UTC().AddDate(0, 0, n).Format("2006-01-02") }
	build := func(from, to string) resp {
		return call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": from, "period_to": to})
	}
	first := build(day(-40), day(-20))
	if first.Status != 201 || first.data()["net"] != "19000.00" {
		t.Fatalf("first batch: %v", first.Body)
	}
	if x := build(day(-19), day(0)); x.Status != 409 {
		t.Fatalf("nothing to settle yet = %d", x.Status)
	}

	// 5,000 of the 10,000 payment is refunded after settlement (a completed refund, seeded: the refund window rules are tested elsewhere)
	var pay string
	if err := db.QueryRow("SELECT id FROM payments WHERE booking_id = ?", b).Scan(&pay); err != nil {
		t.Fatal(err)
	}
	rid := uuid.NewString()
	mustOK(t, "completed refund", "INSERT INTO refund_requests (id, created_at, updated_at, booking_id, payment_id, reason_code, requested_amount, approved_amount, currency_code, method, status, idempotency_key) VALUES (?, "+now+", "+now+", ?, ?, 'PARTNER_CANCELLATION', 5000.00, 5000.00, 'THB', 'ORIGINAL_METHOD', 'COMPLETED', ?)", rid, b, pay, "rev-"+rid)
	mustOK(t, "payment shows the refund", "UPDATE payments SET refunded_amount = 5000.00 WHERE id = ?", pay)

	// a later booking provides the sales the reversal is netted against
	c, _ := paid(t, i, u, 1, "")
	mustOK(t, "service long ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 10 DAY) WHERE booking_id = ?", c)
	second := build(day(-19), day(0))
	// c: gross 10,000, commission 500; reversal: gross -5,000, commission -250 -> gross 5,000, commission 250, net 4,750
	if second.Status != 201 || second.data()["items"] != float64(2) || second.data()["gross"] != "5000.00" || second.data()["commission"] != "250.00" || second.data()["net"] != "4750.00" {
		t.Fatalf("second batch with a reversal: %v", second.Body)
	}
	if col(t, "SELECT COUNT(*) FROM partner_settlement_items WHERE batch_id = ? AND kind = 'REFUND_REVERSAL' AND gross_amount = -5000.00 AND commission_amount = -250.00 AND net_amount = -4750.00", second.data()["id"].(string)) != "1" {
		t.Fatal("reversal item")
	}
	if col(t, "SELECT COUNT(*) FROM commission_calculations WHERE refund_request_id = ? AND kind = 'REFUND_REVERSAL' AND commission_rate = 0.05", rid) != "1" {
		t.Fatal("reversal uses the original rate and is tied to the refund")
	}
	// reversed exactly once
	d, _ := paid(t, i, u, 1, "")
	mustOK(t, "service long ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 9 DAY) WHERE booking_id = ?", d)
	third := call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": day(-19), "period_to": day(1)})
	if third.Status != 201 || third.data()["items"] != float64(1) || third.data()["net"] != "9500.00" {
		t.Fatalf("the refund must not be reversed twice: %v", third.Body)
	}
}

func TestReversalsLargerThanSalesAreHeldBackNotPaidAsNegative(t *testing.T) {
	i := newInventory(t, 5, "10000.00")
	u := newUser(t)
	b, _ := paid(t, i, u, 1, "")
	mustOK(t, "service long ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE booking_id = ?", b)
	maker := newUser(t, "FINANCE_MANAGER")
	day := func(n int) string { return time.Now().UTC().AddDate(0, 0, n).Format("2006-01-02") }
	if x := call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": day(-40), "period_to": day(-20)}); x.Status != 201 {
		t.Fatalf("first batch: %v", x.Body)
	}
	var pay string
	db.QueryRow("SELECT id FROM payments WHERE booking_id = ?", b).Scan(&pay)
	rid := uuid.NewString()
	mustOK(t, "full refund", "INSERT INTO refund_requests (id, created_at, updated_at, booking_id, payment_id, reason_code, requested_amount, approved_amount, currency_code, method, status, idempotency_key) VALUES (?, "+now+", "+now+", ?, ?, 'PARTNER_CANCELLATION', 10000.00, 10000.00, 'THB', 'ORIGINAL_METHOD', 'COMPLETED', ?)", rid, b, pay, "neg-"+rid)
	x := call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": day(-19), "period_to": day(0)})
	if x.Status != 409 {
		t.Fatalf("a batch whose net would be negative = %d %v", x.Status, x.Body)
	}
	if col(t, "SELECT COUNT(*) FROM commission_calculations WHERE refund_request_id = ?", rid) != "0" {
		t.Fatal("the failed build must leave no reversal behind")
	}
}

func TestCommissionPolicyPrecedenceIsPartnerThenCategoryThenDefault(t *testing.T) {
	policy := func(scope, partner, category, rate string) {
		var p, c any
		if partner != "" {
			p = partner
		}
		if category != "" {
			c = category
		}
		mustOK(t, "policy", "INSERT INTO commission_policies (id, created_at, scope, partner_id, category, commission_type, rate, effective_from, policy_version, status, approved_at) VALUES (UUID(), "+now+", ?, ?, ?, 'PERCENT', ?, '2000-01-01', 100, 'ACTIVE', "+now+")", scope, p, c, rate)
	}
	settle := func(i inv, expectCommission string) {
		u := newUser(t)
		b, _ := paid(t, i, u, 1, "")
		mustOK(t, "service long ago", "UPDATE booking_items SET service_date = DATE_SUB(CURDATE(), INTERVAL 30 DAY) WHERE booking_id = ?", b)
		maker := newUser(t, "FINANCE_MANAGER")
		day := func(n int) string { return time.Now().UTC().AddDate(0, 0, n).Format("2006-01-02") }
		r := call(t, "POST", "/api/v1/portal/settlements/build", maker.Token, map[string]string{"partner_id": i.partner, "period_from": day(-40), "period_to": day(-20)})
		if r.Status != 201 || r.data()["commission"] != expectCommission {
			t.Fatalf("commission want %s: %d %v", expectCommission, r.Status, r.Body)
		}
	}
	// default: the seeded 5% applies to a category nobody has a policy for
	plain := newInventory(t, 3, "10000.00")
	settle(plain, "500.00")
	// category policy beats the default
	cat := newInventory(t, 3, "10000.00")
	mustOK(t, "category", "UPDATE supplier_products sp JOIN inventory_items i ON i.supplier_product_id = sp.id SET sp.category = 'TRANSPORT' WHERE i.id = ?", cat.item)
	policy("CATEGORY", "", "TRANSPORT", "0.030000")
	settle(cat, "300.00")
	// a partner policy beats the category policy
	both := newInventory(t, 3, "10000.00")
	mustOK(t, "category", "UPDATE supplier_products sp JOIN inventory_items i ON i.supplier_product_id = sp.id SET sp.category = 'TRANSPORT' WHERE i.id = ?", both.item)
	policy("PARTNER", both.partner, "", "0.020000")
	settle(both, "200.00")
	// the batch audit records which policy versions were used
	if col(t, "SELECT COUNT(*) FROM financial_audit_logs WHERE action = 'settlement.calculated' AND field_changes_json LIKE '%policies_used%'") == "0" {
		t.Fatal("audit must record the policies used")
	}
}
