//go:build integration

package integration

import (
	"context"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/finance/reconcile"
)

func TestReconciliationFindsEveryKindOfDifference(t *testing.T) {
	// a real payment gives us a payment_id to hang provider-specific transactions on
	i := newInventory(t, 2, "1000.00")
	u := newUser(t)
	b := idem(t, "POST", "/api/v1/bookings", u.Token, "rc-"+uuid.NewString(), i.body(1, ""))
	bid := b.data()["id"].(string)
	in := idem(t, "POST", "/api/v1/payments/intents", u.Token, "rci-"+uuid.NewString(), map[string]any{"booking_id": bid, "method": "CARD"})
	sendWebhook(t, webhookBody("rc-"+uuid.NewString(), "CHARGE_SUCCEEDED", in.data()["payment_reference"].(string), "1000.00", time.Now()), "")
	var pay string
	if err := db.QueryRow("SELECT id FROM payments WHERE booking_id = ?", bid).Scan(&pay); err != nil {
		t.Fatal(err)
	}
	prov := "recon-" + uuid.NewString()[:8] // isolates this test from every other row in the suite
	add := func(ext, typ, amt string) {
		mustOK(t, "seed "+ext, "INSERT INTO payment_transactions (id, created_at, payment_id, provider, external_id, event_type, amount, currency_code, status) VALUES (UUID(), UTC_TIMESTAMP(6), ?, ?, ?, ?, ?, 'THB', 'SUCCEEDED')", pay, prov, ext, typ, amt)
	}
	add("ok-1", "CHARGE", "1000.00")
	add("diff-1", "CHARGE", "500.00")
	add("ours-only", "CHARGE", "70.00")
	add("refund-1", "REFUND", "200.00")

	statement := []reconcile.Line{
		{ExternalID: "ok-1", EventType: "CHARGE", Amount: 100000},
		{ExternalID: "ok-1", EventType: "CHARGE", Amount: 100000}, // duplicated line must not count twice
		{ExternalID: "diff-1", EventType: "CHARGE", Amount: 49000},
		{ExternalID: "theirs-only", EventType: "CHARGE", Amount: 1234},
		{ExternalID: "refund-1", EventType: "REFUND", Amount: 20000},
	}
	from, to := time.Now().Add(-time.Hour), time.Now().Add(time.Hour)
	s, err := reconcile.NewService(db).Run(context.Background(), prov, "stmt.csv", "", from, to, statement)
	if err != nil {
		t.Fatal(err)
	}
	if s.Matched != 2 || s.Mismatch != 1 || s.MissingOurs != 1 || s.MissingProvider != 1 || s.Unresolved() != 3 {
		t.Fatalf("summary %+v", s)
	}
	var status string
	var matched, unmatched, records int
	db.QueryRow("SELECT status, matched_count, unmatched_count FROM payment_reconciliations WHERE id = ?", s.ID).Scan(&status, &matched, &unmatched)
	db.QueryRow("SELECT COUNT(*) FROM financial_reconciliation_records WHERE reconciliation_id = ?", s.ID).Scan(&records)
	if status != "COMPLETED" || matched != 2 || unmatched != 3 || records != 5 {
		t.Fatalf("stored status=%s matched=%d unmatched=%d records=%d", status, matched, unmatched, records)
	}
	// findings are append-only
	if _, err := db.Exec("DELETE FROM financial_reconciliation_records WHERE reconciliation_id = ?", s.ID); err == nil {
		t.Fatal("reconciliation records must not be deletable")
	}
	if _, err := reconcile.NewService(db).Run(context.Background(), prov, "x", "", to, from, nil); err != reconcile.ErrPeriod {
		t.Fatalf("bad period: %v", err)
	}
}
