//go:build integration

package integration

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http/httptest"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/booking"
	"github.com/travel-super-app/backend/internal/finance/faudit"
	"github.com/travel-super-app/backend/internal/finance/safety"
	"github.com/travel-super-app/backend/internal/platform/httpapi"
)

type inv struct{ partner, item, avail, date string }

// newInventory creates an approved partner with one internal-inventory item sold on a future day.
func newInventory(t *testing.T, qty int, price string) inv {
	t.Helper()
	owner := newUser(t)
	i := inv{partner: uuid.NewString(), item: uuid.NewString(), avail: uuid.NewString(), date: time.Now().UTC().AddDate(0, 0, 30).Format("2006-01-02")}
	sup, sp := uuid.NewString(), uuid.NewString()
	mustOK(t, "partner", "INSERT INTO partners (id, created_at, updated_at, owner_user_id, legal_name, status) VALUES (?, "+now+", "+now+", ?, 'ร้านทดสอบ', 'APPROVED')", i.partner, owner.ID)
	mustOK(t, "supplier", "INSERT INTO suppliers (id, created_at, updated_at, supplier_type, adapter_code) VALUES (?, "+now+", "+now+", 'TOUR', ?)", sup, "s-"+sup[:8])
	mustOK(t, "product", "INSERT INTO supplier_products (id, created_at, updated_at, supplier_id, partner_id, category, external_ref) VALUES (?, "+now+", "+now+", ?, ?, 'TOUR', 'tour-1')", sp, sup, i.partner)
	mustOK(t, "item", "INSERT INTO inventory_items (id, created_at, supplier_product_id, sku) VALUES (?, "+now+", ?, 'DAY-TOUR')", i.item, sp)
	mustOK(t, "availability", "INSERT INTO inventory_availability (id, created_at, updated_at, inventory_item_id, service_date, quantity_total, base_price) VALUES (?, "+now+", "+now+", ?, ?, ?, ?)", i.avail, i.item, i.date, qty, price)
	return i
}

func (i inv) body(qty int, coupon string) map[string]any {
	b := map[string]any{"items": []map[string]any{{"inventory_item_id": i.item, "service_date": i.date, "quantity": qty}},
		// a client trying to dictate the price: must be ignored (unknown fields are not part of the contract)
		"total": "1.00", "unit_price": "1.00"}
	if coupon != "" {
		b["coupon_code"] = coupon
	}
	return b
}

func idem(t *testing.T, method, path, token, key string, body any) resp {
	t.Helper()
	var buf strings.Builder
	if body != nil {
		_ = json.NewEncoder(&buf).Encode(body)
	}
	req := httptest.NewRequest(method, path, strings.NewReader(buf.String()))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+token)
	if key != "" {
		req.Header.Set("Idempotency-Key", key)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	out := resp{Status: w.Code}
	_ = json.Unmarshal(w.Body.Bytes(), &out.Body)
	return out
}

func webhookBody(event, typ, ref, amount string, ts time.Time) []byte {
	b, _ := json.Marshal(map[string]any{"event_id": event, "type": typ, "payment_reference": ref, "amount": amount, "currency": "THB", "timestamp": ts.Unix()})
	return b
}

func sendWebhook(t *testing.T, body []byte, sig string) resp {
	t.Helper()
	if sig == "" {
		sig = mockPSP.Sign(body)
	}
	req := httptest.NewRequest("POST", "/api/v1/webhooks/payments", strings.NewReader(string(body)))
	req.Header.Set("X-Signature", sig)
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	out := resp{Status: w.Code}
	_ = json.Unmarshal(w.Body.Bytes(), &out.Body)
	return out
}

func TestFinancialEndpointsAreOffByDefault(t *testing.T) {
	u := newUser(t)
	r := gin.New()
	httpapi.RegisterRoutes(r, db, secret) // environment defaults: FINANCIAL_TRANSACTIONS_ENABLED unset
	req := httptest.NewRequest("POST", "/api/v1/bookings", strings.NewReader(`{"items":[]}`))
	req.Header.Set("Authorization", "Bearer "+u.Token)
	req.Header.Set("Idempotency-Key", "k")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	if w.Code != 503 {
		t.Fatalf("with the switch off a booking must be refused with 503, got %d %s", w.Code, w.Body.String())
	}
}

func TestBookingPriceIsComputedByTheServerAndIsIdempotent(t *testing.T) {
	i := newInventory(t, 10, "1500.00")
	u := newUser(t)
	c := idem(t, "POST", "/api/v1/bookings", u.Token, "bk-"+uuid.NewString(), i.body(2, ""))
	if c.Status != 201 || c.data()["payable_total"] != "3000.00" || c.data()["status"] != "PENDING_PAYMENT" {
		t.Fatalf("2 x 1,500 must be 3,000 whatever the client sends: %d %v", c.Status, c.Body)
	}
	id := c.data()["id"].(string)
	var snap, total string
	db.QueryRow("SELECT s.payable_total, b.total_amount FROM bookings b JOIN booking_price_snapshots s ON s.id = b.price_snapshot_id WHERE b.id = ?", id).Scan(&snap, &total)
	if snap != "3000.00" || total != "3000.00" {
		t.Fatalf("snapshot %s booking %s", snap, total)
	}
	var sold int
	db.QueryRow("SELECT quantity_sold FROM inventory_availability WHERE id = ?", i.avail).Scan(&sold)
	if sold != 2 {
		t.Fatalf("sold = %d", sold)
	}
	key := "same-" + uuid.NewString()
	a := idem(t, "POST", "/api/v1/bookings", u.Token, key, i.body(1, ""))
	b := idem(t, "POST", "/api/v1/bookings", u.Token, key, i.body(1, ""))
	if a.Status != 201 || b.Status != 200 || a.data()["id"] != b.data()["id"] || b.data()["replayed"] != true {
		t.Fatalf("the same Idempotency-Key must return the same booking: %v / %v", a.Body, b.Body)
	}
	db.QueryRow("SELECT quantity_sold FROM inventory_availability WHERE id = ?", i.avail).Scan(&sold)
	if sold != 3 {
		t.Fatalf("a replay must not hold inventory twice, sold = %d", sold)
	}
	if r := idem(t, "POST", "/api/v1/bookings", u.Token, "", i.body(1, "")); r.Status != 400 {
		t.Errorf("missing Idempotency-Key = %d", r.Status)
	}
	if r := idem(t, "POST", "/api/v1/bookings", "", "x", i.body(1, "")); r.Status != 401 {
		t.Errorf("anonymous booking = %d", r.Status)
	}
	past := i.body(1, "")
	past["items"].([]map[string]any)[0]["service_date"] = "2020-01-01"
	if r := idem(t, "POST", "/api/v1/bookings", u.Token, "p-"+uuid.NewString(), past); r.Status != 400 {
		t.Errorf("a past service date = %d", r.Status)
	}
}

func TestInventoryIsNeverOversoldUnderConcurrentBookings(t *testing.T) {
	i := newInventory(t, 3, "500.00")
	var wg sync.WaitGroup
	var mu sync.Mutex
	statuses := map[int]int{}
	for n := 0; n < 10; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			u := newUser(t)
			r := idem(t, "POST", "/api/v1/bookings", u.Token, "c-"+uuid.NewString(), i.body(1, ""))
			mu.Lock()
			statuses[r.Status]++
			mu.Unlock()
		}()
	}
	wg.Wait()
	var sold int
	db.QueryRow("SELECT quantity_sold FROM inventory_availability WHERE id = ?", i.avail).Scan(&sold)
	if statuses[201] != 3 || statuses[409] != 7 || sold != 3 {
		t.Fatalf("3 seats, 10 buyers: created=%d conflict=%d other=%v sold=%d", statuses[201], statuses[409], statuses, sold)
	}
}

func newCoupon(t *testing.T, kind, value string, maxRedemptions int) string {
	d, c, code := uuid.NewString(), uuid.NewString(), "T"+strings.ToUpper(uuid.NewString()[:8])
	mustOK(t, "discount", "INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, funded_by, status) VALUES (?, "+now+", 'PLATFORM', ?, ?, '2020-01-01', 'PLATFORM', 'ACTIVE')", d, kind, value)
	mustOK(t, "coupon", "INSERT INTO coupons (id, created_at, updated_at, code, max_redemptions, discount_id) VALUES (?, "+now+", "+now+", ?, ?, ?)", c, code, maxRedemptions, d)
	return code
}

func TestCouponIsAppliedOnTheServerAndLimitedUnderConcurrency(t *testing.T) {
	i := newInventory(t, 50, "1000.00")
	u := newUser(t)
	code := newCoupon(t, "FIXED", "100", 2)
	r := idem(t, "POST", "/api/v1/bookings", u.Token, "k1-"+uuid.NewString(), i.body(1, code))
	if r.Status != 201 || r.data()["payable_total"] != "900.00" || r.data()["discount_total"] != "100.00" {
		t.Fatalf("coupon booking: %v", r.Body)
	}
	if bad := idem(t, "POST", "/api/v1/bookings", u.Token, "k2-"+uuid.NewString(), i.body(1, "NO-SUCH")); bad.Status != 400 {
		t.Errorf("unknown coupon = %d", bad.Status)
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for n := 0; n < 6; n++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			if idem(t, "POST", "/api/v1/bookings", u.Token, fmt.Sprintf("kc-%d-%s", n, uuid.NewString()), i.body(1, code)).Status == 201 {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}(n)
	}
	wg.Wait()
	var redeemed int
	db.QueryRow("SELECT redeemed_count FROM coupons WHERE code = ?", code).Scan(&redeemed)
	if ok != 1 || redeemed != 2 {
		t.Fatalf("a coupon with 2 redemptions (1 already used): %d more succeeded, counter=%d", ok, redeemed)
	}
	pct := newCoupon(t, "PERCENT", "10", 5)
	p := idem(t, "POST", "/api/v1/bookings", u.Token, "kp-"+uuid.NewString(), i.body(3, pct))
	if p.data()["payable_total"] != "2700.00" {
		t.Fatalf("10%% of 3,000: %v", p.Body)
	}
}

func TestPaymentHappyPathAndAllWebhookDefences(t *testing.T) {
	i := newInventory(t, 5, "2000.00")
	u, other := newUser(t), newUser(t)
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "b-"+uuid.NewString(), i.body(1, ""))
	bid := b.data()["id"].(string)

	if r := idem(t, "POST", "/api/v1/payments/intents", other.Token, "i-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR"}); r.Status != 404 {
		t.Errorf("paying for someone else's booking = %d", r.Status)
	}
	if r := idem(t, "POST", "/api/v1/payments/intents", u.Token, "i-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "BITCOIN"}); r.Status != 400 {
		t.Errorf("unsupported method = %d", r.Status)
	}
	key := "i-" + uuid.NewString()
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, key, map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR", "amount": "1.00"})
	if in.Status != 201 || in.data()["amount"] != "2000.00" {
		t.Fatalf("the charged amount is the booking total, never the client's: %v", in.Body)
	}
	ref := in.data()["payment_reference"].(string)
	if again := idem(t, "POST", "/api/v1/payments/intents", u.Token, key, map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR"}); again.Status != 200 || again.data()["payment_reference"] != ref {
		t.Errorf("idempotent replay: %v", again.Body)
	}
	if r := idem(t, "POST", "/api/v1/payments/intents", u.Token, "i2-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "CARD"}); r.Status != 409 {
		t.Errorf("a second live payment attempt = %d", r.Status)
	}
	var startSeq int64
	db.QueryRow("SELECT COALESCE(MAX(seq),0) FROM financial_audit_logs").Scan(&startSeq)

	status := func() string {
		var s string
		db.QueryRow("SELECT status FROM bookings WHERE id = ?", bid).Scan(&s)
		return s
	}
	now := time.Now()
	// 1 bad signature
	body := webhookBody("ev-"+uuid.NewString(), "CHARGE_SUCCEEDED", ref, "2000.00", now)
	if r := sendWebhook(t, body, "deadbeef"); r.Status != 401 || status() != "PENDING_PAYMENT" {
		t.Errorf("forged signature: %d, booking %s", r.Status, status())
	}
	// 2 stale (replayed) event
	if r := sendWebhook(t, webhookBody("ev-"+uuid.NewString(), "CHARGE_SUCCEEDED", ref, "2000.00", now.Add(-time.Hour)), ""); r.Status != 400 || status() != "PENDING_PAYMENT" {
		t.Errorf("replayed old event: %d, booking %s", r.Status, status())
	}
	// 3 wrong amount is never applied
	if r := sendWebhook(t, webhookBody("ev-"+uuid.NewString(), "CHARGE_SUCCEEDED", ref, "1.00", now), ""); r.Status != 200 || status() != "PENDING_PAYMENT" {
		t.Errorf("amount mismatch must not pay the booking: %d %v, booking %s", r.Status, r.Body, status())
	}
	// 4 unknown reference
	if r := sendWebhook(t, webhookBody("ev-"+uuid.NewString(), "CHARGE_SUCCEEDED", "PAY-nope", "2000.00", now), ""); r.data()["result"] != "REJECTED_UNKNOWN" {
		t.Errorf("unknown payment: %v", r.Body)
	}
	// 5 genuine success delivered 8 times concurrently: applied exactly once
	ev := "ev-" + uuid.NewString()
	good := webhookBody(ev, "CHARGE_SUCCEEDED", ref, "2000.00", now)
	var wg sync.WaitGroup
	var mu sync.Mutex
	results := map[string]int{}
	for n := 0; n < 8; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			r := sendWebhook(t, good, "")
			mu.Lock()
			results[fmt.Sprint(r.data()["result"])]++
			mu.Unlock()
		}()
	}
	wg.Wait()
	if results["APPLIED"] != 1 || results["IGNORED_DUPLICATE"] != 7 {
		t.Fatalf("8 concurrent deliveries: %v", results)
	}
	var txns, hist, paid int
	var cap string
	db.QueryRow("SELECT COUNT(*) FROM payment_transactions WHERE external_id = ?", ev).Scan(&txns)
	db.QueryRow("SELECT COUNT(*) FROM booking_status_histories WHERE booking_id = ? AND to_status = 'PAID'", bid).Scan(&hist)
	db.QueryRow("SELECT captured_amount, status = 'SUCCEEDED' FROM payments WHERE provider_reference = ?", ref).Scan(&cap, &paid)
	if status() != "PAID" || txns != 1 || hist != 1 || cap != "2000.00" || paid != 1 {
		t.Fatalf("booking %s, transactions %d, histories %d, captured %s, payment succeeded %d", status(), txns, hist, cap, paid)
	}
	var held string
	db.QueryRow("SELECT status FROM inventory_holds WHERE booking_id = ?", bid).Scan(&held)
	if held != "CONSUMED" {
		t.Errorf("hold after payment = %s", held)
	}
	// 6 a later FAILED event cannot undo a success
	if r := sendWebhook(t, webhookBody("ev-"+uuid.NewString(), "CHARGE_FAILED", ref, "2000.00", now), ""); r.data()["result"] != "IGNORED_DUPLICATE" || status() != "PAID" {
		t.Errorf("a failure after success must be ignored: %v booking %s", r.Body, status())
	}
	// 7 no endpoint lets a person mark it paid
	staff := newUser(t, "STAFF")
	if r := call(t, "PATCH", "/api/v1/portal/payments/"+ref+"/verify", staff.Token, map[string]string{"status": "PAID"}); r.Status != 404 {
		t.Errorf("manual payment verification must not exist: %d", r.Status)
	}
	// 8 the audit chain written along the way verifies
	bad, rows, err := faudit.Verify(context.Background(), db, startSeq)
	if err != nil || bad != 0 || rows < 2 {
		t.Fatalf("audit chain: bad=%d rows=%d err=%v", bad, rows, err)
	}
}

func TestAuditChainDetectsAForgedRowAndConcurrentWritersStayLinked(t *testing.T) {
	var start int64
	db.QueryRow("SELECT COALESCE(MAX(seq),0) FROM financial_audit_logs").Scan(&start)
	var wg sync.WaitGroup
	for n := 0; n < 10; n++ {
		wg.Add(1)
		go func(n int) {
			defer wg.Done()
			tx, _ := db.Begin()
			defer tx.Rollback()
			if err := faudit.Append(context.Background(), tx, faudit.Entry{ActorType: "SYSTEM", EntityType: "test", EntityID: uuid.NewString(), Action: "t", Changes: map[string]any{"n": n, "b": "ก", "a": []int{1, 2}}}); err != nil {
				t.Error(err)
				return
			}
			tx.Commit()
		}(n)
	}
	wg.Wait()
	if bad, rows, err := faudit.Verify(context.Background(), db, start); err != nil || bad != 0 || rows != 10 {
		t.Fatalf("10 concurrent writers must form one valid chain: bad=%d rows=%d err=%v", bad, rows, err)
	}
	// a forged row inserted straight into the table (INSERT is allowed, rewriting is not) breaks verification
	mustOK(t, "forged row", "INSERT INTO financial_audit_logs (id, occurred_at, entity_type, entity_id, action, prev_hash, row_hash) VALUES (UUID(), "+now+", 'test', 'x', 'forged', ?, ?)", strings.Repeat("0", 64), strings.Repeat("1", 64))
	if bad, _, _ := faudit.Verify(context.Background(), db, start); bad == 0 {
		t.Fatal("a forged audit row must be detected")
	}
}

func TestExpiredBookingReleasesInventoryAndCouponAndLatePaymentIsFlagged(t *testing.T) {
	i := newInventory(t, 4, "1000.00")
	u := newUser(t)
	code := newCoupon(t, "FIXED", "50", 3)
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "e-"+uuid.NewString(), i.body(2, code))
	bid := b.data()["id"].(string)
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, "ei-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "CARD"})
	ref := in.data()["payment_reference"].(string)

	mustOK(t, "make the payment window pass", "UPDATE bookings SET expires_at = DATE_SUB(UTC_TIMESTAMP(6), INTERVAL 1 MINUTE) WHERE id = ?", bid)
	n, err := booking.NewService(db).ExpireHolds(context.Background())
	if err != nil || n < 1 {
		t.Fatalf("expire: %d %v", n, err)
	}
	var sold, red int
	var st string
	db.QueryRow("SELECT quantity_sold FROM inventory_availability WHERE id = ?", i.avail).Scan(&sold)
	db.QueryRow("SELECT redeemed_count FROM coupons WHERE code = ?", code).Scan(&red)
	db.QueryRow("SELECT status FROM bookings WHERE id = ?", bid).Scan(&st)
	if sold != 0 || red != 0 || st != "CANCELLED" {
		t.Fatalf("after expiry sold=%d redeemed=%d booking=%s", sold, red, st)
	}
	// money arrives after the booking was cancelled: recorded and flagged, the booking is NOT revived
	r := sendWebhook(t, webhookBody("late-"+uuid.NewString(), "CHARGE_SUCCEEDED", ref, "1950.00", time.Now()), "")
	var late int
	db.QueryRow("SELECT COUNT(*) FROM financial_audit_logs WHERE action = 'payment.late_success' AND entity_id = (SELECT id FROM payments WHERE provider_reference = ?)", ref).Scan(&late)
	db.QueryRow("SELECT status FROM bookings WHERE id = ?", bid).Scan(&st)
	if r.data()["result"] != "APPLIED" || late != 1 || st != "CANCELLED" {
		t.Fatalf("late payment: %v flagged=%d booking=%s", r.Body, late, st)
	}
}

func TestPerUserCouponLimitHoldsUnderConcurrency(t *testing.T) {
	i := newInventory(t, 50, "1000.00")
	u := newUser(t)
	d, c, code := uuid.NewString(), uuid.NewString(), "U"+strings.ToUpper(uuid.NewString()[:8])
	mustOK(t, "discount", "INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, funded_by, status, usage_limit_per_user) VALUES (?, "+now+", 'PLATFORM', 'FIXED', 100, '2020-01-01', 'PLATFORM', 'ACTIVE', 1)", d)
	mustOK(t, "coupon", "INSERT INTO coupons (id, created_at, updated_at, code, max_redemptions, discount_id) VALUES (?, "+now+", "+now+", ?, 100, ?)", c, code, d)
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for n := 0; n < 6; n++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if idem(t, "POST", "/api/v1/bookings", u.Token, "pu-"+uuid.NewString(), i.body(1, code)).Status == 201 {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	if ok != 1 {
		t.Fatalf("a coupon limited to one use per user was used %d times", ok)
	}
}

func TestSimulatedPaymentGoesThroughTheRealWebhookPath(t *testing.T) {
	i := newInventory(t, 3, "1000.00")
	u, other := newUser(t), newUser(t)
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "sim-"+uuid.NewString(), i.body(1, ""))
	bid := b.data()["id"].(string)
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, "simi-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR"})
	ref := in.data()["payment_reference"].(string)

	if x := call(t, "POST", "/api/v1/dev/payments/simulate", other.Token, map[string]string{"payment_reference": ref}); x.Status != 404 {
		t.Fatalf("someone else's payment = %d", x.Status)
	}
	if x := call(t, "POST", "/api/v1/dev/payments/simulate", u.Token, map[string]string{}); x.Status != 400 {
		t.Fatalf("missing reference = %d", x.Status)
	}
	if x := call(t, "POST", "/api/v1/dev/payments/simulate", u.Token, map[string]string{"payment_reference": ref}); x.Status != 200 || x.data()["result"] != "APPLIED" {
		t.Fatalf("simulate: %d %v", x.Status, x.Body)
	}
	got := call(t, "GET", "/api/v1/bookings/"+bid, u.Token, nil)
	if got.data()["status"] != "CONFIRMED" && got.data()["status"] != "PAID" {
		t.Fatalf("booking after payment: %v", got.Body)
	}
	if got.data()["payment_status"] == nil {
		t.Fatalf("payment status must be visible: %v", got.Body)
	}
	if x := call(t, "POST", "/api/v1/dev/payments/simulate", u.Token, map[string]string{"payment_reference": ref}); x.Status != 404 {
		t.Fatalf("an already-paid intent cannot be simulated again = %d", x.Status)
	}
}

func TestSimulatedFailedPaymentLeavesTheBookingUnpaidAndIsLabelledSandbox(t *testing.T) {
	i := newInventory(t, 3, "1000.00")
	u := newUser(t)
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "simf-"+uuid.NewString(), i.body(1, ""))
	bid := b.data()["id"].(string)
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, "simfi-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "PROMPTPAY_QR"})
	ref := in.data()["payment_reference"].(string)

	if x := call(t, "POST", "/api/v1/dev/payments/simulate", u.Token, map[string]string{"payment_reference": ref, "outcome": "PAID"}); x.Status != 400 {
		t.Fatalf("unknown outcome = %d", x.Status)
	}
	x := call(t, "POST", "/api/v1/dev/payments/simulate", u.Token, map[string]string{"payment_reference": ref, "outcome": "FAILED"})
	if x.Status != 200 || x.data()["result"] != "APPLIED" || x.data()["sandbox"] != true || x.data()["outcome"] != "CHARGE_FAILED" {
		t.Fatalf("simulate failure: %d %v", x.Status, x.Body)
	}
	got := call(t, "GET", "/api/v1/bookings/"+bid, u.Token, nil)
	if got.data()["status"] != "PENDING_PAYMENT" {
		t.Fatalf("a failed payment must not confirm the booking: %v", got.Body)
	}
	if got.data()["payment_status"] != "FAILED" {
		t.Fatalf("payment status must show FAILED: %v", got.Body)
	}
}

func TestPaymentSimulatorDoesNotExistInProduction(t *testing.T) {
	prod := gin.New()
	httpapi.RegisterRoutesWith(prod, db, secret, safety.Config{PaymentProvider: "mock", SupplierMode: "mock", Enabled: true, Environment: "prod"}, mockPSP)
	w := httptest.NewRecorder()
	prod.ServeHTTP(w, httptest.NewRequest("POST", "/api/v1/dev/payments/simulate", strings.NewReader("{}")))
	if w.Code != 404 {
		t.Fatalf("production must not even have the route, got %d", w.Code)
	}
}
