//go:build integration

package integration

import (
	"testing"

	"github.com/google/uuid"
)

func queueIDs(t *testing.T, token string) map[string]map[string]any {
	t.Helper()
	r := call(t, "GET", "/api/v1/portal/community/reports?limit=100", token, nil)
	if r.Status != 200 {
		t.Fatalf("queue: %d %v", r.Status, r.Body)
	}
	out := map[string]map[string]any{}
	for _, x := range r.data()["items"].([]any) {
		m := x.(map[string]any)
		out[m["id"].(string)] = m
	}
	return out
}

func TestStaffModerationQueueRemoveAndDismiss(t *testing.T) {
	staff := newUser(t, "STAFF")
	author, r1, r2, customer := newUser(t), newUser(t), newUser(t), newUser(t)

	mk := func() string {
		p := call(t, "POST", "/api/v1/community/posts", author.Token, map[string]any{"body": "โพสต์ตรวจสอบ " + uuid.NewString()[:8]})
		if p.Status != 201 {
			t.Fatalf("create: %d", p.Status)
		}
		return p.data()["id"].(string)
	}
	bad, fine := mk(), mk()
	for _, c := range []struct {
		who  user
		post string
		why  string
	}{{r1, bad, "SPAM"}, {r2, bad, "ABUSE"}, {r1, fine, "OTHER"}} {
		if x := call(t, "POST", "/api/v1/community/posts/"+c.post+"/report", c.who.Token, map[string]any{"reason": c.why}); x.Status != 200 {
			t.Fatalf("report: %d %v", x.Status, x.Body)
		}
	}

	// Customers cannot see or act on the queue.
	if x := call(t, "GET", "/api/v1/portal/community/reports", customer.Token, nil); x.Status != 403 {
		t.Fatalf("customer queue = %d", x.Status)
	}
	if x := call(t, "POST", "/api/v1/portal/community/posts/"+bad+"/remove", customer.Token, map[string]any{}); x.Status != 403 {
		t.Fatalf("customer remove = %d", x.Status)
	}

	q := queueIDs(t, staff.Token)
	if q[bad] == nil || q[fine] == nil {
		t.Fatalf("queue missing posts: %v", q)
	}
	if q[bad]["report_count"].(float64) != 2 || q[fine]["report_count"].(float64) != 1 {
		t.Fatalf("counts: %v %v", q[bad], q[fine])
	}

	// Dismiss keeps the post public and clears it from the queue.
	if x := call(t, "POST", "/api/v1/portal/community/posts/"+fine+"/dismiss", staff.Token, map[string]any{"note": "ok"}); x.Status != 200 {
		t.Fatalf("dismiss: %d %v", x.Status, x.Body)
	}
	if queueIDs(t, staff.Token)[fine] != nil {
		t.Fatal("dismissed post must leave the queue")
	}
	if !contains(feedIDs(call(t, "GET", "/api/v1/community/posts?limit=100", customer.Token, nil)), fine) {
		t.Fatal("dismissed post must stay public")
	}
	// A second action on the same post finds nothing open.
	if x := call(t, "POST", "/api/v1/portal/community/posts/"+fine+"/dismiss", staff.Token, map[string]any{}); x.Status != 404 {
		t.Fatalf("second dismiss = %d", x.Status)
	}

	// Remove deletes the post for everyone and is audited.
	if x := call(t, "POST", "/api/v1/portal/community/posts/"+bad+"/remove", staff.Token, map[string]any{"note": "spam"}); x.Status != 200 {
		t.Fatalf("remove: %d %v", x.Status, x.Body)
	}
	if contains(feedIDs(call(t, "GET", "/api/v1/community/posts?limit=100", customer.Token, nil)), bad) {
		t.Fatal("removed post must leave the feed")
	}
	if queueIDs(t, staff.Token)[bad] != nil {
		t.Fatal("removed post must leave the queue")
	}
	var n int
	if err := db.QueryRow("SELECT COUNT(*) FROM audit_logs WHERE subject_type = 'community_post' AND subject_id = ? AND action = 'community.post.remove' AND actor_user_id = ?", bad, staff.ID).Scan(&n); err != nil || n != 1 {
		t.Fatalf("audit rows = %d, err = %v", n, err)
	}
	if x := call(t, "POST", "/api/v1/portal/community/posts/"+uuid.NewString()+"/remove", staff.Token, map[string]any{}); x.Status != 404 {
		t.Fatalf("unknown post = %d", x.Status)
	}
}

func TestMeReportsRolesAndPermissions(t *testing.T) {
	customer, staff := newUser(t), newUser(t, "STAFF")
	if r := call(t, "GET", "/api/v1/me", "", nil); r.Status != 401 {
		t.Fatalf("anonymous /me = %d", r.Status)
	}
	has := func(r resp, key, want string) bool {
		for _, x := range r.data()[key].([]any) {
			if x == want {
				return true
			}
		}
		return false
	}
	c := call(t, "GET", "/api/v1/me", customer.Token, nil)
	if c.Status != 200 || c.data()["id"] != customer.ID || !has(c, "roles", "CUSTOMER") || has(c, "permissions", "support.manage") {
		t.Fatalf("customer /me = %d %v", c.Status, c.Body)
	}
	s := call(t, "GET", "/api/v1/me", staff.Token, nil)
	if s.Status != 200 || !has(s, "roles", "STAFF") || !has(s, "permissions", "support.manage") || !has(s, "permissions", "portal.read") {
		t.Fatalf("staff /me = %d %v", s.Status, s.Body)
	}
}
