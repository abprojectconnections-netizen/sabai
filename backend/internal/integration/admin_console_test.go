//go:build integration

package integration

import (
	"net/url"
	"testing"

	"github.com/google/uuid"
)

func adminItems(t *testing.T, r resp) []map[string]any {
	t.Helper()
	if r.Status != 200 {
		t.Fatalf("status %d: %v", r.Status, r.Body)
	}
	out := []map[string]any{}
	for _, x := range r.data()["items"].([]any) {
		out = append(out, x.(map[string]any))
	}
	return out
}

func stringsOf(v any) []string {
	out := []string{}
	for _, x := range v.([]any) {
		out = append(out, x.(string))
	}
	return out
}

func hasString(list []string, want string) bool {
	for _, s := range list {
		if s == want {
			return true
		}
	}
	return false
}

func TestAdminConsolePermissionsPerRole(t *testing.T) {
	admin, auditor, customer, target := newUser(t, "ADMIN"), newUser(t, "AUDITOR"), newUser(t), newUser(t)
	id := target.ID
	endpoints := []struct{ method, path string }{
		{"GET", "/api/v1/admin/dashboard"}, {"GET", "/api/v1/admin/users"}, {"GET", "/api/v1/admin/users/" + id},
		{"PATCH", "/api/v1/admin/users/" + id + "/status"}, {"GET", "/api/v1/admin/roles"}, {"GET", "/api/v1/admin/audit-logs"},
	}
	for _, e := range endpoints {
		if r := call(t, e.method, e.path, "", map[string]any{"status": "ACTIVE"}); r.Status != 401 {
			t.Errorf("anonymous %s %s = %d", e.method, e.path, r.Status)
		}
		if r := call(t, e.method, e.path, customer.Token, map[string]any{"status": "ACTIVE"}); r.Status != 403 {
			t.Errorf("customer %s %s = %d", e.method, e.path, r.Status)
		}
	}
	// System Admin manages users and roles but deliberately cannot read the audit trail; the auditor is the reverse.
	for path, want := range map[string]int{"/api/v1/admin/users": 200, "/api/v1/admin/roles": 200, "/api/v1/admin/dashboard": 200, "/api/v1/admin/audit-logs": 403} {
		if r := call(t, "GET", path, admin.Token, nil); r.Status != want {
			t.Errorf("admin GET %s = %d, want %d", path, r.Status, want)
		}
	}
	for path, want := range map[string]int{"/api/v1/admin/users": 403, "/api/v1/admin/roles": 200, "/api/v1/admin/dashboard": 200, "/api/v1/admin/audit-logs": 200} {
		if r := call(t, "GET", path, auditor.Token, nil); r.Status != want {
			t.Errorf("auditor GET %s = %d, want %d", path, r.Status, want)
		}
	}
	if r := call(t, "PATCH", "/api/v1/admin/users/"+id+"/status", auditor.Token, map[string]any{"status": "SUSPENDED", "reason": "nope"}); r.Status != 403 {
		t.Errorf("auditor must not change status: %d", r.Status)
	}
}

func TestAdminUserSearchFiltersAndDetail(t *testing.T) {
	admin, target := newUser(t, "ADMIN"), newUser(t, "STAFF")
	list := func(query string) resp {
		return call(t, "GET", "/api/v1/admin/users?"+query, admin.Token, nil)
	}
	r := list("q=" + url.QueryEscape(target.Email))
	got := adminItems(t, r)
	if len(got) != 1 || got[0]["id"] != target.ID || !hasString(stringsOf(got[0]["roles"]), "STAFF") || !hasString(stringsOf(got[0]["roles"]), "CUSTOMER") {
		t.Fatalf("search by email: %v", got)
	}
	if got[0]["last_login_at"] == nil {
		t.Errorf("target logged in, last_login_at should be set: %v", got[0])
	}
	if _, leaked := got[0]["password_hash"]; leaked {
		t.Fatal("password hash must never be returned")
	}
	if n := adminItems(t, list("q="+url.QueryEscape(target.Email)+"&role=STAFF")); len(n) != 1 {
		t.Errorf("role filter STAFF: %d", len(n))
	}
	if n := adminItems(t, list("q="+url.QueryEscape(target.Email)+"&role=PARTNER")); len(n) != 0 {
		t.Errorf("role filter PARTNER should exclude the target: %d", len(n))
	}
	if n := adminItems(t, list("q="+url.QueryEscape(target.Email)+"&status=SUSPENDED")); len(n) != 0 {
		t.Errorf("status filter SUSPENDED should exclude an active user: %d", len(n))
	}
	// LIKE wildcards in the search text are literal, so "%" matches only an address that really contains one.
	if r := list("q=%25"); r.Status != 200 || r.data()["total"].(float64) != 0 {
		t.Errorf("literal %% search: %d %v", r.Status, r.Body)
	}
	if r := list("status=DELETED"); r.Status != 400 {
		t.Errorf("bad status filter = %d", r.Status)
	}
	if r := list("limit=0"); r.Status != 400 {
		t.Errorf("limit=0 = %d", r.Status)
	}
	if r := list("limit=1&offset=0"); len(adminItems(t, r)) != 1 || r.data()["total"].(float64) < 2 {
		t.Errorf("pagination: %v", r.Body)
	}

	d := call(t, "GET", "/api/v1/admin/users/"+target.ID, admin.Token, nil)
	if d.Status != 200 || d.data()["email"] != target.Email || d.data()["status"] != "ACTIVE" {
		t.Fatalf("detail: %d %v", d.Status, d.Body)
	}
	if _, leaked := d.data()["phone"]; leaked {
		t.Error("phone must not be returned")
	}
	if r := call(t, "GET", "/api/v1/admin/users/"+uuid.NewString(), admin.Token, nil); r.Status != 404 {
		t.Errorf("unknown user = %d", r.Status)
	}
}

func TestAdminSuspendReactivateIsEnforcedAndAudited(t *testing.T) {
	admin, auditor, target := newUser(t, "ADMIN"), newUser(t, "AUDITOR"), newUser(t)
	path := "/api/v1/admin/users/" + target.ID + "/status"
	patch := func(who user, body map[string]any) resp { return call(t, "PATCH", path, who.Token, body) }

	if r := patch(admin, map[string]any{"status": "SUSPENDED"}); r.Status != 400 {
		t.Errorf("suspend without reason = %d", r.Status)
	}
	if r := patch(admin, map[string]any{"status": "BANNED", "reason": "x"}); r.Status != 400 {
		t.Errorf("unknown status = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/admin/users/"+admin.ID+"/status", admin.Token, map[string]any{"status": "SUSPENDED", "reason": "self"}); r.Status != 403 {
		t.Errorf("self-suspension = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/admin/users/"+uuid.NewString()+"/status", admin.Token, map[string]any{"status": "SUSPENDED", "reason": "ghost"}); r.Status != 404 {
		t.Errorf("unknown user = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/me", target.Token, nil); r.Status != 200 {
		t.Fatalf("target should be active: %d", r.Status)
	}

	if r := patch(admin, map[string]any{"status": "SUSPENDED", "reason": "ละเมิดกฎชุมชน"}); r.Status != 200 {
		t.Fatalf("suspend: %d %v", r.Status, r.Body)
	}
	// Takes effect on the very next request with the old token, and the account can no longer sign in.
	if r := call(t, "GET", "/api/v1/me", target.Token, nil); r.Status != 401 {
		t.Errorf("suspended user's token = %d, want 401", r.Status)
	}
	if r := call(t, "POST", "/api/v1/auth/login", "", map[string]string{"email": target.Email, "password": "password-123"}); r.Status == 200 {
		t.Error("a suspended user must not be able to log in")
	}
	// Repeating the same status is a no-op: no second audit row.
	if r := patch(admin, map[string]any{"status": "SUSPENDED", "reason": "again"}); r.Status != 200 {
		t.Fatalf("repeat suspend: %d", r.Status)
	}
	if n := adminItems(t, call(t, "GET", "/api/v1/admin/users?status=SUSPENDED&q="+url.QueryEscape(target.Email), admin.Token, nil)); len(n) != 1 {
		t.Errorf("suspended filter: %d", len(n))
	}
	if r := patch(admin, map[string]any{"status": "ACTIVE"}); r.Status != 200 {
		t.Fatalf("reactivate: %d %v", r.Status, r.Body)
	}
	if r := call(t, "POST", "/api/v1/auth/login", "", map[string]string{"email": target.Email, "password": "password-123"}); r.Status != 200 {
		t.Errorf("reactivated user should log in: %d", r.Status)
	}

	logs := adminItems(t, call(t, "GET", "/api/v1/admin/audit-logs?action=user.status.changed&subject_type=user&subject_id="+target.ID, auditor.Token, nil))
	if len(logs) != 2 {
		t.Fatalf("expected exactly 2 audit rows (suspend, reactivate), got %d: %v", len(logs), logs)
	}
	newest, oldest := logs[0], logs[1]
	if newest["actor_email"] != admin.Email || newest["actor_user_id"] != admin.ID {
		t.Errorf("actor not recorded: %v", newest)
	}
	if newest["after"].(map[string]any)["status"] != "ACTIVE" || newest["before"].(map[string]any)["status"] != "SUSPENDED" {
		t.Errorf("newest transition: %v", newest)
	}
	if oldest["after"].(map[string]any)["reason"] != "ละเมิดกฎชุมชน" || oldest["before"].(map[string]any)["status"] != "ACTIVE" {
		t.Errorf("oldest transition: %v", oldest)
	}
}

func TestAdminRolesDashboardAndAuditFilters(t *testing.T) {
	admin, auditor := newUser(t, "ADMIN"), newUser(t, "AUDITOR")

	roles := map[string]map[string]any{}
	for _, r := range adminItems(t, call(t, "GET", "/api/v1/admin/roles", admin.Token, nil)) {
		roles[r["code"].(string)] = r
	}
	if staff := roles["STAFF"]; staff == nil || !hasString(stringsOf(staff["permissions"]), "portal.read") {
		t.Fatalf("STAFF role: %v", staff)
	}
	if cfo := roles["CFO_CEO"]; cfo == nil || cfo["financial"] != true {
		t.Errorf("CFO_CEO must be flagged financial: %v", cfo)
	}
	if a := roles["ADMIN"]; a == nil || hasString(stringsOf(a["permissions"]), "refund.approve") || hasString(stringsOf(a["permissions"]), "audit.read") {
		t.Errorf("ADMIN must hold no financial or audit authority: %v", a)
	}
	if roles["ADMIN"]["user_count"].(float64) < 1 {
		t.Errorf("the admin we just created is counted: %v", roles["ADMIN"])
	}

	d := call(t, "GET", "/api/v1/admin/dashboard", auditor.Token, nil)
	if d.Status != 200 {
		t.Fatalf("dashboard: %d %v", d.Status, d.Body)
	}
	users := d.data()["users"].(map[string]any)
	if users["total"].(float64) < 2 || users["active"].(float64) < 2 || users["new_last_7_days"].(float64) < 2 {
		t.Errorf("user counts: %v", users)
	}
	queues := d.data()["queues"].(map[string]any)
	for _, k := range []string{"partners_pending", "tickets_open", "disputes_open", "refunds_open", "role_requests_pending", "community_reports_open"} {
		if _, ok := queues[k].(float64); !ok {
			t.Errorf("queue %s missing: %v", k, queues)
		}
	}
	if _, ok := d.data()["bookings"].(map[string]any)["by_status"].(map[string]any); !ok {
		t.Errorf("bookings.by_status missing: %v", d.data()["bookings"])
	}

	for _, q := range []string{"from=yesterday", "to=2026-13-01", "limit=101", "offset=-1"} {
		if r := call(t, "GET", "/api/v1/admin/audit-logs?"+q, auditor.Token, nil); r.Status != 400 {
			t.Errorf("audit-logs?%s = %d, want 400", q, r.Status)
		}
	}
	// A future "from" returns nothing; a wide window returns rows.
	if r := call(t, "GET", "/api/v1/admin/audit-logs?from=2999-01-01T00:00:00Z", auditor.Token, nil); r.Status != 200 || r.data()["total"].(float64) != 0 {
		t.Errorf("future from: %d %v", r.Status, r.Body)
	}
}
