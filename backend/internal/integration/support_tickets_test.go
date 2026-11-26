//go:build integration

package integration

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func ticketBody(subject string) map[string]any {
	return map[string]any{"subject": subject, "category": "BOOKING", "description": "ห้องพักไม่ตรงกับที่จอง"}
}

func TestSupportTicketFlowBetweenCustomerAndStaff(t *testing.T) {
	staff, other, auditor := newUser(t, "STAFF"), newUser(t), newUser(t, "AUDITOR")
	customer := newUser(t)
	bookingID, bookingCode := uuid.NewString(), "TK"+uuid.NewString()[:10]
	if _, err := db.Exec("INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'THB', 100, 'CONFIRMED')", bookingID, customer.ID, bookingCode); err != nil {
		t.Fatal(err)
	}

	// Authentication and permissions.
	for _, e := range []struct{ method, path string }{{"POST", "/api/v1/support/tickets"}, {"GET", "/api/v1/support/tickets"}, {"GET", "/api/v1/portal/tickets"}} {
		if r := call(t, e.method, e.path, "", ticketBody("anonymous")); r.Status != 401 {
			t.Errorf("anonymous %s %s = %d", e.method, e.path, r.Status)
		}
	}
	if r := call(t, "GET", "/api/v1/portal/tickets", customer.Token, nil); r.Status != 403 {
		t.Errorf("customer on the staff queue = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/portal/tickets", auditor.Token, nil); r.Status != 403 {
		t.Errorf("auditor on the staff queue = %d", r.Status)
	}

	// Validation.
	for name, body := range map[string]map[string]any{
		"short subject":     {"subject": "ab", "description": "x"},
		"empty description": {"subject": "ปัญหาการจอง", "description": "   "},
		"bad category":      {"subject": "ปัญหาการจอง", "description": "x", "category": "HACK"},
		"long subject":      {"subject": strings.Repeat("ก", 121), "description": "x"},
	} {
		if r := call(t, "POST", "/api/v1/support/tickets", customer.Token, body); r.Status != 400 {
			t.Errorf("%s = %d, want 400", name, r.Status)
		}
	}
	// A booking that is not yours is reported as not found.
	if r := call(t, "POST", "/api/v1/support/tickets", other.Token, map[string]any{"subject": "ปัญหาการจอง", "description": "x", "booking_id": bookingID}); r.Status != 404 {
		t.Errorf("someone else's booking = %d, want 404", r.Status)
	}

	body := ticketBody("ห้องไม่ตรงกับที่จอง")
	body["booking_id"] = bookingID
	created := call(t, "POST", "/api/v1/support/tickets", customer.Token, body)
	if created.Status != 201 || created.data()["status"] != "OPEN" {
		t.Fatalf("create: %d %v", created.Status, created.Body)
	}
	id := created.data()["id"].(string)

	// Isolation: another customer sees nothing and cannot touch it.
	if r := call(t, "GET", "/api/v1/support/tickets/"+id, other.Token, nil); r.Status != 404 {
		t.Errorf("other customer GET = %d, want 404", r.Status)
	}
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/messages", other.Token, map[string]any{"body": "hi"}); r.Status != 404 {
		t.Errorf("other customer reply = %d, want 404", r.Status)
	}
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/close", other.Token, nil); r.Status != 404 {
		t.Errorf("other customer close = %d, want 404", r.Status)
	}
	if n := len(adminItems(t, call(t, "GET", "/api/v1/support/tickets", other.Token, nil))); n != 0 {
		t.Errorf("other customer's list = %d items", n)
	}
	mine := adminItems(t, call(t, "GET", "/api/v1/support/tickets", customer.Token, nil))
	if len(mine) != 1 || mine[0]["id"] != id || mine[0]["booking_code"] != bookingCode || mine[0]["reply_count"].(float64) != 0 {
		t.Fatalf("customer list: %v", mine)
	}

	// Staff queue row and detail.
	var row map[string]any
	for _, x := range adminItems(t, call(t, "GET", "/api/v1/portal/tickets?status=OPEN&limit=100", staff.Token, nil)) {
		if x["id"] == id {
			row = x
		}
	}
	if row == nil || row["customer_email"] != customer.Email || row["booking_code"] != bookingCode {
		t.Fatalf("staff queue row: %v", row)
	}
	if next := stringsOf(row["next_statuses"]); len(next) != 2 || !hasString(next, "IN_PROGRESS") || !hasString(next, "CLOSED") {
		t.Errorf("OPEN next statuses: %v", next)
	}
	det := call(t, "GET", "/api/v1/portal/tickets/"+id, staff.Token, nil)
	if det.Status != 200 || det.data()["description"] != "ห้องพักไม่ตรงกับที่จอง" {
		t.Errorf("staff detail: %d %v", det.Status, det.Body)
	}
	if r := call(t, "GET", "/api/v1/portal/tickets/"+uuid.NewString(), staff.Token, nil); r.Status != 404 {
		t.Errorf("unknown ticket = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/portal/tickets?status=lower-case-bad", staff.Token, nil); r.Status != 400 {
		t.Errorf("bad status filter = %d", r.Status)
	}

	// Staff replies: the ticket moves to IN_PROGRESS and is assigned to the replier.
	if r := call(t, "POST", "/api/v1/portal/tickets/"+id+"/messages", staff.Token, map[string]any{"body": "   "}); r.Status != 400 {
		t.Errorf("empty staff reply = %d", r.Status)
	}
	rep := call(t, "POST", "/api/v1/portal/tickets/"+id+"/messages", staff.Token, map[string]any{"body": "ขออภัยค่ะ กำลังตรวจสอบกับโรงแรม"})
	if rep.Status != 201 || rep.data()["status"] != "IN_PROGRESS" {
		t.Fatalf("staff reply: %d %v", rep.Status, rep.Body)
	}
	det = call(t, "GET", "/api/v1/portal/tickets/"+id, staff.Token, nil)
	if det.data()["assigned_staff_id"] != staff.ID || det.data()["status"] != "IN_PROGRESS" {
		t.Errorf("after reply: %v", det.Body)
	}

	// The customer sees the reply as STAFF, without learning who wrote it.
	cd := call(t, "GET", "/api/v1/support/tickets/"+id, customer.Token, nil)
	msgs := cd.data()["messages"].([]any)
	if cd.Status != 200 || len(msgs) != 1 {
		t.Fatalf("customer detail: %d %v", cd.Status, cd.Body)
	}
	m := msgs[0].(map[string]any)
	if m["author_kind"] != "STAFF" || len(m) != 4 {
		t.Errorf("message must expose only id, author_kind, body, created_at: %v", m)
	}
	raw, _ := json.Marshal(cd.Body)
	if strings.Contains(strings.ToLower(string(raw)), strings.ToLower(staff.Email)) || strings.Contains(string(raw), staff.ID) {
		t.Error("the customer must never see the staff member's identity")
	}
	if l := adminItems(t, call(t, "GET", "/api/v1/support/tickets", customer.Token, nil)); l[0]["reply_count"].(float64) != 1 {
		t.Errorf("reply_count: %v", l[0])
	}

	// Staff resolves it; a customer reply reopens it.
	if r := call(t, "PATCH", "/api/v1/portal/tickets/"+id+"/status", staff.Token, map[string]any{"status": "RESOLVED"}); r.Status != 200 {
		t.Fatalf("resolve: %d %v", r.Status, r.Body)
	}
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/messages", customer.Token, map[string]any{"body": "ยังไม่ได้รับการแก้ไขค่ะ"}); r.Status != 201 {
		t.Fatalf("customer reply: %d %v", r.Status, r.Body)
	}
	if st := call(t, "GET", "/api/v1/support/tickets/"+id, customer.Token, nil).data()["status"]; st != "IN_PROGRESS" {
		t.Errorf("a reply to a resolved ticket should reopen it, status = %v", st)
	}

	// Customer closes it; after that nobody can add to it and closing again is a conflict.
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/close", customer.Token, nil); r.Status != 200 {
		t.Fatalf("close: %d %v", r.Status, r.Body)
	}
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/close", customer.Token, nil); r.Status != 409 {
		t.Errorf("second close = %d, want 409", r.Status)
	}
	if r := call(t, "POST", "/api/v1/support/tickets/"+id+"/messages", customer.Token, map[string]any{"body": "x"}); r.Status != 409 {
		t.Errorf("customer reply on closed = %d, want 409", r.Status)
	}
	if r := call(t, "POST", "/api/v1/portal/tickets/"+id+"/messages", staff.Token, map[string]any{"body": "x"}); r.Status != 409 {
		t.Errorf("staff reply on closed = %d, want 409", r.Status)
	}

	// Every step is in the audit trail.
	seen := map[string]bool{}
	for _, l := range adminItems(t, call(t, "GET", "/api/v1/admin/audit-logs?subject_type=support_ticket&subject_id="+id+"&limit=50", auditor.Token, nil)) {
		seen[l["action"].(string)] = true
	}
	for _, want := range []string{"support.ticket.created", "support.ticket.replied", "support.ticket.status.changed", "support.ticket.reopened", "support.ticket.closed"} {
		if !seen[want] {
			t.Errorf("audit trail is missing %s: %v", want, seen)
		}
	}
}

func TestSupportTicketOpenLimitPerUser(t *testing.T) {
	customer := newUser(t)
	var ids []string
	for i := 0; i < 5; i++ {
		r := call(t, "POST", "/api/v1/support/tickets", customer.Token, ticketBody("ปัญหาที่ "+string(rune('A'+i))+" ของฉัน"))
		if r.Status != 201 {
			t.Fatalf("ticket %d: %d %v", i, r.Status, r.Body)
		}
		ids = append(ids, r.data()["id"].(string))
	}
	if r := call(t, "POST", "/api/v1/support/tickets", customer.Token, ticketBody("ใบที่หกของฉัน")); r.Status != 409 {
		t.Errorf("sixth open ticket = %d, want 409", r.Status)
	}
	// Closing one frees a slot.
	if r := call(t, "POST", "/api/v1/support/tickets/"+ids[0]+"/close", customer.Token, nil); r.Status != 200 {
		t.Fatalf("close: %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/support/tickets", customer.Token, ticketBody("ใบใหม่หลังปิด")); r.Status != 201 {
		t.Errorf("ticket after closing one = %d, want 201", r.Status)
	}
}
