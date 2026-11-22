//go:build integration

package integration

import (
	"net/url"
	"testing"

	"github.com/google/uuid"
)

func TestPortalListsPermissionsPerRole(t *testing.T) {
	staff, officer, refund, customer := newUser(t, "STAFF"), newUser(t, "BOOKING_OFFICER"), newUser(t, "REFUND_OFFICER"), newUser(t)
	paths := map[string]map[string]int{ // path -> who -> expected status
		"/api/v1/portal/bookings": {"staff": 200, "officer": 200, "refund": 403, "customer": 403},
		"/api/v1/portal/disputes": {"staff": 200, "officer": 200, "refund": 403, "customer": 403},
		"/api/v1/portal/partners": {"staff": 200, "officer": 403, "refund": 403, "customer": 403},
	}
	tokens := map[string]string{"staff": staff.Token, "officer": officer.Token, "refund": refund.Token, "customer": customer.Token}
	for path, want := range paths {
		if r := call(t, "GET", path, "", nil); r.Status != 401 {
			t.Errorf("anonymous GET %s = %d", path, r.Status)
		}
		for who, status := range want {
			if r := call(t, "GET", path, tokens[who], nil); r.Status != status {
				t.Errorf("%s GET %s = %d, want %d", who, path, r.Status, status)
			}
		}
	}
}

func TestPortalBookingQueueFiltersAndNextStatuses(t *testing.T) {
	staff, customer := newUser(t, "STAFF"), newUser(t)
	insert := func(status string) (string, string) {
		id := uuid.NewString()
		code := "PQ" + id[:10]
		if _, err := db.Exec("INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'THB', 1234.50, ?)", id, customer.ID, code, status); err != nil {
			t.Fatal(err)
		}
		return id, code
	}
	pendingID, pendingCode := insert("PENDING")
	_, paidCode := insert("PAID")
	list := func(query string) []map[string]any {
		return adminItems(t, call(t, "GET", "/api/v1/portal/bookings?"+query, staff.Token, nil))
	}

	got := list("q=" + url.QueryEscape(pendingCode))
	if len(got) != 1 || got[0]["id"] != pendingID || got[0]["status"] != "PENDING" || got[0]["customer_email"] != customer.Email || got[0]["total_amount"] != "1234.50" {
		t.Fatalf("pending booking row: %v", got)
	}
	if next := stringsOf(got[0]["next_statuses"]); len(next) != 2 || !hasString(next, "CONFIRMED") || !hasString(next, "CANCELLED") {
		t.Errorf("PENDING next statuses: %v", next)
	}
	// Financial statuses are listed but offer no manual transition (payment state is never changed by a person).
	paid := list("q=" + url.QueryEscape(paidCode))
	if len(paid) != 1 || len(stringsOf(paid[0]["next_statuses"])) != 0 {
		t.Errorf("PAID row: %v", paid)
	}
	if n := list("status=PAID&q=" + url.QueryEscape(pendingCode)); len(n) != 0 {
		t.Errorf("status filter must exclude the pending booking: %v", n)
	}
	if n := list("status=pending&q=" + url.QueryEscape(pendingCode)); len(n) != 1 {
		t.Errorf("status filter is case-insensitive: %v", n)
	}
	if r := call(t, "GET", "/api/v1/portal/bookings?q=%25", staff.Token, nil); r.Status != 200 || r.data()["total"].(float64) != 0 {
		t.Errorf("literal %% search: %d %v", r.Status, r.Body)
	}
	for _, q := range []string{"status=NOT-A-STATUS", "limit=0", "offset=-1"} {
		if r := call(t, "GET", "/api/v1/portal/bookings?"+q, staff.Token, nil); r.Status != 400 {
			t.Errorf("bookings?%s = %d, want 400", q, r.Status)
		}
	}

	// Acting on the row moves it through the server's own rules and the list follows.
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+pendingID+"/status", staff.Token, map[string]string{"status": "CONFIRMED"}); r.Status != 200 {
		t.Fatalf("confirm: %d", r.Status)
	}
	got = list("q=" + url.QueryEscape(pendingCode))
	if got[0]["status"] != "CONFIRMED" || len(stringsOf(got[0]["next_statuses"])) != 1 || stringsOf(got[0]["next_statuses"])[0] != "CANCELLED" {
		t.Errorf("after confirm: %v", got[0])
	}
}

func TestPortalDisputeAndPartnerQueues(t *testing.T) {
	staff, customer := newUser(t, "STAFF"), newUser(t)
	bid := uuid.NewString()
	code := "PD" + bid[:10]
	if _, err := db.Exec("INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'THB', 500.00, 'CONFIRMED')", bid, customer.ID, code); err != nil {
		t.Fatal(err)
	}
	created := call(t, "POST", "/api/v1/portal/disputes", staff.Token, map[string]string{"booking_id": bid, "reason": "NO_SHOW", "description": "ลูกค้าแจ้งว่าไม่มีผู้รับ"})
	if created.Status != 201 {
		t.Fatalf("open dispute: %d %v", created.Status, created.Body)
	}
	did := created.data()["id"].(string)

	var mine map[string]any
	for _, d := range adminItems(t, call(t, "GET", "/api/v1/portal/disputes?status=OPEN&limit=100", staff.Token, nil)) {
		if d["id"] == did {
			mine = d
		}
	}
	if mine == nil || mine["booking_code"] != code || mine["reason"] != "NO_SHOW" || mine["opened_by_email"] != staff.Email {
		t.Fatalf("dispute row: %v", mine)
	}
	if next := stringsOf(mine["next_statuses"]); len(next) != 1 || next[0] != "IN_REVIEW" {
		t.Errorf("OPEN dispute next: %v", next)
	}
	if r := call(t, "PATCH", "/api/v1/portal/disputes/"+did+"/status", staff.Token, map[string]string{"status": "IN_REVIEW"}); r.Status != 200 {
		t.Fatalf("to review: %d", r.Status)
	}
	inReview := false
	for _, d := range adminItems(t, call(t, "GET", "/api/v1/portal/disputes?status=IN_REVIEW&limit=100", staff.Token, nil)) {
		if d["id"] == did {
			inReview = true
			if next := stringsOf(d["next_statuses"]); !hasString(next, "RESOLVED") || !hasString(next, "REJECTED") {
				t.Errorf("IN_REVIEW next: %v", next)
			}
		}
	}
	if !inReview {
		t.Fatal("dispute missing from IN_REVIEW list")
	}

	owner := newUser(t)
	pid := uuid.NewString()
	if _, err := db.Exec("INSERT INTO partners (id, created_at, updated_at, owner_user_id, legal_name, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'PENDING')", pid, owner.ID, "ร้านคิว "+pid[:6]); err != nil {
		t.Fatal(err)
	}
	find := func(status string) map[string]any {
		for _, p := range adminItems(t, call(t, "GET", "/api/v1/portal/partners?status="+status+"&limit=100", staff.Token, nil)) {
			if p["id"] == pid {
				return p
			}
		}
		return nil
	}
	p := find("PENDING")
	if p == nil || p["owner_email"] != owner.Email {
		t.Fatalf("pending partner row: %v", p)
	}
	if next := stringsOf(p["next_statuses"]); !hasString(next, "APPROVED") || !hasString(next, "REJECTED") {
		t.Errorf("PENDING partner next: %v", next)
	}
	if r := call(t, "PATCH", "/api/v1/portal/partners/"+pid+"/approval", staff.Token, map[string]string{"status": "APPROVED"}); r.Status != 200 {
		t.Fatalf("approve: %d", r.Status)
	}
	if find("PENDING") != nil {
		t.Error("approved partner must leave the pending list")
	}
	if p = find("APPROVED"); p == nil || len(stringsOf(p["next_statuses"])) != 1 || stringsOf(p["next_statuses"])[0] != "SUSPENDED" {
		t.Errorf("approved partner row: %v", p)
	}
}
