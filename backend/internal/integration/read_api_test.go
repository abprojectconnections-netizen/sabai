//go:build integration

package integration

import (
	"testing"

	"github.com/google/uuid"
)

func TestCatalogIsPublicAndShowsOnlyApprovedPartnersWithStock(t *testing.T) {
	shown := newInventory(t, 3, "1200.00")
	mustOK(t, "title", "UPDATE supplier_products sp JOIN inventory_items i ON i.supplier_product_id = sp.id SET sp.title = 'ทัวร์เกาะทดสอบ' WHERE i.id = ?", shown.item)
	soldOut := newInventory(t, 1, "900.00")
	mustOK(t, "sold out", "UPDATE inventory_availability SET quantity_sold = 1 WHERE id = ?", soldOut.avail)
	pending := newInventory(t, 3, "800.00")
	mustOK(t, "partner not approved", "UPDATE partners SET status = 'PENDING' WHERE id = ?", pending.partner)

	r := call(t, "GET", "/api/v1/catalog/items?limit=100", "", nil) // no token: browsing is public
	if r.Status != 200 {
		t.Fatalf("catalog: %d %v", r.Status, r.Body)
	}
	found := map[string]map[string]any{}
	for _, x := range r.list() {
		m := x.(map[string]any)
		found[m["id"].(string)] = m
	}
	if m := found[shown.item]; m == nil || m["title"] != "ทัวร์เกาะทดสอบ" || m["from_price"] != "1200.00" || m["category"] != "TOUR" {
		t.Fatalf("available item: %v", m)
	}
	if found[soldOut.item] != nil || found[pending.item] != nil {
		t.Fatal("a sold-out item or one from an unapproved partner must not be listed")
	}
	if call(t, "GET", "/api/v1/catalog/items?limit=0", "", nil).Status != 400 {
		t.Fatal("bad paging")
	}
}

func TestCustomersSeeOnlyTheirOwnBookingsAndWallet(t *testing.T) {
	i := newInventory(t, 5, "1000.00")
	a, b := newUser(t), newUser(t)
	made := idem(t, "POST", "/api/v1/bookings", a.Token, "rd-"+uuid.NewString(), i.body(2, ""))
	id := made.data()["id"].(string)

	list := call(t, "GET", "/api/v1/bookings", a.Token, nil)
	if list.Status != 200 || len(list.list()) != 1 {
		t.Fatalf("own list: %d %v", list.Status, list.Body)
	}
	row := list.list()[0].(map[string]any)
	if row["id"] != id || row["payable_total"] != "2000.00" || row["status"] != "PENDING_PAYMENT" || row["payment_status"] != nil {
		t.Fatalf("list row: %v", row)
	}
	one := call(t, "GET", "/api/v1/bookings/"+id, a.Token, nil)
	items, _ := one.data()["items"].([]any)
	terms, _ := one.data()["terms"].(map[string]any)
	if one.Status != 200 || len(items) != 1 || terms == nil || one.data()["refunds"] == nil {
		t.Fatalf("detail: %v", one.Body)
	}
	if x := call(t, "GET", "/api/v1/bookings/"+id, b.Token, nil); x.Status != 404 {
		t.Fatalf("someone else's booking = %d", x.Status)
	}
	if x := call(t, "GET", "/api/v1/bookings", b.Token, nil); len(x.list()) != 0 {
		t.Fatalf("another user's list leaked: %v", x.Body)
	}
	if call(t, "GET", "/api/v1/bookings", "", nil).Status != 401 {
		t.Fatal("bookings need a token")
	}

	// wallet: empty by default, then shows its ledger newest first
	w := call(t, "GET", "/api/v1/wallet", a.Token, nil)
	if w.Status != 200 || w.data()["available_balance"] != "0.00" || w.data()["balance_type"] != "REFUND_CREDIT" {
		t.Fatalf("empty wallet: %v", w.Body)
	}
	wid := uuid.NewString()
	mustOK(t, "wallet", "INSERT INTO wallets (id, created_at, updated_at, user_id, currency_code, available_balance) VALUES (?, "+now+", "+now+", ?, 'THB', 300.00)", wid, a.ID)
	mustOK(t, "ledger", "INSERT INTO wallet_ledger_entries (id, created_at, wallet_id, user_id, transaction_type, reference_type, reference_id, credit_amount, debit_amount, balance_after, currency_code, idempotency_key) VALUES (UUID(), "+now+", ?, ?, 'REFUND_CREDIT', 'REFUND', UUID(), 300.00, 0, 300.00, 'THB', ?)", wid, a.ID, "k-"+wid)
	w = call(t, "GET", "/api/v1/wallet", a.Token, nil)
	tx := call(t, "GET", "/api/v1/wallet/transactions", a.Token, nil)
	if w.data()["available_balance"] != "300.00" || len(tx.list()) != 1 || tx.list()[0].(map[string]any)["balance_after"] != "300.00" {
		t.Fatalf("wallet %v ledger %v", w.Body, tx.Body)
	}
	if len(call(t, "GET", "/api/v1/wallet/transactions", b.Token, nil).list()) != 0 {
		t.Fatal("ledger leaked to another user")
	}
}
