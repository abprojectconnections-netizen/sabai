//go:build integration

// Package integration runs the HTTP API against a REAL MySQL (schema from database/migrations).
// It exists because the unit tests use sqlmock, which cannot prove that SQL is valid or that constraints,
// transactions and concurrency behave as intended.
//
//	MYSQL_TEST_DSN='user:pass@tcp(127.0.0.1:3306)/db?parseTime=true' go test -tags integration ./internal/integration
//
// Run migrations first: MYSQL_DATABASE=db database/migrate.sh up. Tests create their own users and never assume an empty database.
package integration

import (
	"bytes"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"sync"
	"testing"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/travel-super-app/backend/internal/notification"
	"github.com/travel-super-app/backend/internal/platform/database"
	"github.com/travel-super-app/backend/internal/platform/httpapi"
)

const secret = "integration-test-secret"

var (
	db     *sql.DB
	router *gin.Engine
)

func TestMain(m *testing.M) {
	dsn := os.Getenv("MYSQL_TEST_DSN")
	if dsn == "" {
		fmt.Println("MYSQL_TEST_DSN not set; skipping integration tests")
		os.Exit(0)
	}
	var err error
	if db, err = database.Open(dsn); err != nil {
		fmt.Println("cannot connect:", err)
		os.Exit(1)
	}
	gin.SetMode(gin.TestMode)
	router = gin.New()
	httpapi.RegisterRoutes(router, db, secret)
	os.Exit(m.Run())
}

type resp struct {
	Status int
	Body   map[string]any
}

func (r resp) data() map[string]any { d, _ := r.Body["data"].(map[string]any); return d }
func (r resp) list() []any          { d, _ := r.Body["data"].([]any); return d }
func (r resp) code() string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		s, _ := e["code"].(string)
		return s
	}
	return ""
}

func call(t *testing.T, method, path, token string, body any) resp {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		if err := json.NewEncoder(&buf).Encode(body); err != nil {
			t.Fatal(err)
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if token != "" {
		req.Header.Set("Authorization", "Bearer "+token)
	}
	w := httptest.NewRecorder()
	router.ServeHTTP(w, req)
	out := resp{Status: w.Code}
	if w.Body.Len() > 0 {
		_ = json.Unmarshal(w.Body.Bytes(), &out.Body)
	}
	return out
}

type user struct{ ID, Email, Token string }

// newUser registers through the real endpoint and logs in; roles lists extra role codes granted directly in SQL.
func newUser(t *testing.T, roles ...string) user {
	t.Helper()
	email := "it-" + uuid.NewString() + "@example.com"
	r := call(t, "POST", "/api/v1/auth/register", "", map[string]string{"email": email, "password": "password-123", "display_name": "ทดสอบ"})
	if r.Status != 201 {
		t.Fatalf("register: %d %v", r.Status, r.Body)
	}
	id := r.data()["user"].(map[string]any)["id"].(string)
	for _, role := range roles {
		if _, err := db.Exec("INSERT INTO user_roles (id, created_at, updated_at, user_id, role_id) SELECT UUID(), UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, id FROM roles WHERE code = ?", id, role); err != nil {
			t.Fatal(err)
		}
	}
	l := call(t, "POST", "/api/v1/auth/login", "", map[string]string{"email": email, "password": "password-123"})
	if l.Status != 200 {
		t.Fatalf("login: %d %v", l.Status, l.Body)
	}
	return user{ID: id, Email: email, Token: l.data()["access_token"].(string)}
}

func TestAuthAgainstRealDatabase(t *testing.T) {
	u := newUser(t)
	var profiles, roleRows int
	db.QueryRow("SELECT COUNT(*) FROM user_profiles WHERE user_id = ?", u.ID).Scan(&profiles)
	db.QueryRow("SELECT COUNT(*) FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? AND r.code = 'CUSTOMER'", u.ID).Scan(&roleRows)
	if profiles != 1 || roleRows != 1 {
		t.Fatalf("register must create one profile and the CUSTOMER role, got %d/%d", profiles, roleRows)
	}
	if r := call(t, "POST", "/api/v1/auth/register", "", map[string]string{"email": u.Email, "password": "password-123"}); r.Status != 400 {
		t.Errorf("duplicate email = %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/auth/login", "", map[string]string{"email": u.Email, "password": "wrong-password"}); r.Status != 401 {
		t.Errorf("wrong password = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/trips", u.Token, nil); r.Status != 200 {
		t.Errorf("token must work on a protected route: %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/trips", "", nil); r.Status != 401 {
		t.Errorf("no token = %d", r.Status)
	}
}

func TestConcurrentRegistrationOfTheSameEmailCreatesOneAccount(t *testing.T) {
	email := "it-race-" + uuid.NewString() + "@example.com"
	var wg sync.WaitGroup
	statuses := make([]int, 8)
	for i := range statuses {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			statuses[i] = call(t, "POST", "/api/v1/auth/register", "", map[string]string{"email": email, "password": "password-123"}).Status
		}(i)
	}
	wg.Wait()
	var n int
	db.QueryRow("SELECT COUNT(*) FROM users WHERE email = ? AND deleted_at IS NULL", email).Scan(&n)
	created := 0
	for _, s := range statuses {
		if s == 201 {
			created++
		} else if s >= 500 {
			t.Errorf("a concurrent duplicate must be a clean 4xx, got %d", s)
		}
	}
	if n != 1 || created != 1 {
		t.Fatalf("users=%d created=%d statuses=%v", n, created, statuses)
	}
}

func TestTripLifecycleAndItineraryOnRealMySQL(t *testing.T) {
	alice, bob := newUser(t), newUser(t)
	dest := uuid.NewString()
	if _, err := db.Exec("INSERT INTO destinations (id, created_at, updated_at, name, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), 'เชียงใหม่', 'ACTIVE')", dest); err != nil {
		t.Fatal(err)
	}
	// The prototype currently sends slugs such as "chiangmai"; a reference to a row that does not exist must be a 400, not a 500.
	if r := call(t, "POST", "/api/v1/trips", alice.Token, map[string]string{"name": "x", "destination_id": "chiangmai"}); r.Status != 400 {
		t.Errorf("unknown destination = %d %v", r.Status, r.Body)
	}
	c := call(t, "POST", "/api/v1/trips", alice.Token, map[string]string{"name": "ทริปเชียงใหม่ 3 วัน", "destination_id": dest, "start_date": "2026-10-25", "end_date": "2026-10-27"})
	if c.Status != 201 {
		t.Fatalf("create: %d %v", c.Status, c.Body)
	}
	id := c.data()["id"].(string)

	// The exact payload the web prototype sends (empty dates)
	if r := call(t, "POST", "/api/v1/trips", alice.Token, map[string]string{"name": "ไม่ระบุวัน", "start_date": "", "end_date": ""}); r.Status != 201 || r.data()["start_date"] != "" {
		t.Fatalf("prototype payload: %d %v", r.Status, r.Body)
	}

	for _, path := range []string{"/" + id} {
		if r := call(t, "GET", "/api/v1/trips"+path, bob.Token, nil); r.Status != 404 {
			t.Errorf("another user's trip must be 404, got %d", r.Status)
		}
		if r := call(t, "PATCH", "/api/v1/trips"+path, bob.Token, map[string]string{"name": "hijack"}); r.Status != 404 {
			t.Errorf("another user's patch = %d", r.Status)
		}
		if r := call(t, "DELETE", "/api/v1/trips"+path, bob.Token, nil); r.Status != 404 {
			t.Errorf("another user's delete = %d", r.Status)
		}
	}
	if l := call(t, "GET", "/api/v1/trips", bob.Token, nil); len(l.list()) != 0 {
		t.Errorf("bob must see none of alice's trips: %v", l.Body)
	}

	for _, a := range []map[string]string{
		{"title": "ข้าวซอย", "date": "2026-10-26", "start_time": "12:00"},
		{"title": "ดอยสุเทพ", "date": "2026-10-26", "start_time": "09:30", "end_time": "11:00"},
		{"title": "เดินทางถึง", "date": "2026-10-25"},
	} {
		if r := call(t, "POST", "/api/v1/trips/"+id+"/activities", alice.Token, a); r.Status != 201 {
			t.Fatalf("add activity %v: %d %v", a, r.Status, r.Body)
		}
	}
	if r := call(t, "POST", "/api/v1/trips/"+id+"/activities", alice.Token, map[string]string{"title": "x", "date": "2026-11-30"}); r.Status != 400 {
		t.Errorf("outside trip dates = %d", r.Status)
	}
	g := call(t, "GET", "/api/v1/trips/"+id, alice.Token, nil)
	days := g.data()["days"].([]any)
	if len(days) != 2 {
		t.Fatalf("days: %v", days)
	}
	d2 := days[1].(map[string]any)
	acts := d2["activities"].([]any)
	if d2["date"] != "2026-10-26" || d2["day_number"] != float64(2) || len(acts) != 2 || acts[0].(map[string]any)["title"] != "ดอยสุเทพ" || acts[0].(map[string]any)["starts_at"] != "2026-10-26T09:30:00.000000Z" {
		t.Fatalf("day 2 / ordering / timestamp format: %v", d2)
	}

	actID := acts[0].(map[string]any)["id"].(string)
	if r := call(t, "DELETE", "/api/v1/trips/"+id+"/activities/"+actID, bob.Token, nil); r.Status != 404 {
		t.Errorf("another user's activity delete = %d", r.Status)
	}
	if r := call(t, "DELETE", "/api/v1/trips/"+id+"/activities/"+actID, alice.Token, nil); r.Status != 204 {
		t.Errorf("activity delete = %d", r.Status)
	}
	if r := call(t, "DELETE", "/api/v1/trips/"+id+"/activities/"+actID, alice.Token, nil); r.Status != 404 {
		t.Errorf("second delete = %d", r.Status)
	}

	p := call(t, "PATCH", "/api/v1/trips/"+id, alice.Token, map[string]string{"status": "PLANNED"})
	if p.Status != 200 || p.data()["status"] != "PLANNED" || p.data()["name"] != "ทริปเชียงใหม่ 3 วัน" {
		t.Fatalf("patch: %d %v", p.Status, p.Body)
	}
	if r := call(t, "PATCH", "/api/v1/trips/"+id, alice.Token, map[string]string{"name": "ทริปเชียงใหม่ 3 วัน"}); r.Status != 200 {
		t.Errorf("a no-op update must not be reported as missing: %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/trips/"+id, alice.Token, map[string]string{"start_date": "2026-11-05"}); r.Status != 400 {
		t.Errorf("start after stored end = %d", r.Status)
	}
	if r := call(t, "DELETE", "/api/v1/trips/"+id, alice.Token, nil); r.Status != 204 {
		t.Errorf("delete = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/trips/"+id, alice.Token, nil); r.Status != 404 {
		t.Errorf("deleted trip must be gone: %d", r.Status)
	}
	l := call(t, "GET", "/api/v1/trips", alice.Token, nil)
	for _, it := range l.list() {
		if it.(map[string]any)["id"] == id {
			t.Error("deleted trip still listed")
		}
	}
	// Non-ASCII survives the round trip (utf8mb4)
	if len(l.list()) == 0 || l.list()[0].(map[string]any)["name"] != "ไม่ระบุวัน" {
		t.Errorf("list: %v", l.Body)
	}
}

func TestConcurrentActivitiesOnTheSameDayShareOneTripDay(t *testing.T) {
	u := newUser(t)
	c := call(t, "POST", "/api/v1/trips", u.Token, map[string]string{"name": "race", "start_date": "2026-10-25", "end_date": "2026-10-27"})
	id := c.data()["id"].(string)
	var wg sync.WaitGroup
	fail := make(chan string, 20)
	for i := 0; i < 12; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			if r := call(t, "POST", "/api/v1/trips/"+id+"/activities", u.Token, map[string]string{"title": fmt.Sprintf("a%d", i), "date": "2026-10-26"}); r.Status != 201 {
				fail <- fmt.Sprintf("status %d %v", r.Status, r.Body)
			}
		}(i)
	}
	wg.Wait()
	close(fail)
	for f := range fail {
		t.Error(f)
	}
	var days, acts int
	db.QueryRow("SELECT COUNT(*) FROM trip_days WHERE trip_id = ? AND deleted_at IS NULL", id).Scan(&days)
	db.QueryRow("SELECT COUNT(*) FROM trip_activities a JOIN trip_days d ON d.id = a.trip_day_id WHERE d.trip_id = ?", id).Scan(&acts)
	if days != 1 || acts != 12 {
		t.Fatalf("days=%d activities=%d, want 1 and 12", days, acts)
	}
}

func TestNotificationsOnRealMySQL(t *testing.T) {
	alice, bob := newUser(t), newUser(t)
	svc := notification.NewService(db)
	ctx := context.Background()
	var ids []string
	for i := 0; i < 3; i++ {
		id, err := svc.Create(ctx, alice.ID, "BOOKING", fmt.Sprintf("แจ้งเตือน %d", i), "รายละเอียด")
		if err != nil {
			t.Fatal(err)
		}
		ids = append(ids, id)
	}
	l := call(t, "GET", "/api/v1/notifications", alice.Token, nil)
	d := l.data()
	if l.Status != 200 || len(d["items"].([]any)) != 3 || d["unread_count"] != float64(3) {
		t.Fatalf("list: %v", l.Body)
	}
	if r := call(t, "PATCH", "/api/v1/notifications/"+ids[0]+"/read", alice.Token, nil); r.Status != 200 {
		t.Errorf("mark read = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/notifications/"+ids[0]+"/read", alice.Token, nil); r.Status != 200 {
		t.Errorf("mark read twice must stay 200 (idempotent): %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/notifications/"+ids[1]+"/read", bob.Token, nil); r.Status != 404 {
		t.Errorf("someone else's notification = %d", r.Status)
	}
	u := call(t, "GET", "/api/v1/notifications?unread=true", alice.Token, nil)
	if len(u.data()["items"].([]any)) != 2 || u.data()["unread_count"] != float64(2) {
		t.Fatalf("unread: %v", u.Body)
	}
	if r := call(t, "POST", "/api/v1/notifications/read-all", alice.Token, nil); r.Status != 200 || r.data()["updated"] != float64(2) {
		t.Errorf("read-all: %v", r.Body)
	}
	if call(t, "GET", "/api/v1/notifications", bob.Token, nil).data()["unread_count"] != float64(0) {
		t.Error("bob must not see alice's notifications")
	}
}

func TestReviewsOnRealMySQL(t *testing.T) {
	alice, bob := newUser(t), newUser(t)
	subject := "h-" + uuid.NewString()[:8]
	c := call(t, "POST", "/api/v1/reviews", alice.Token, map[string]any{"subject_type": "HOTEL", "subject_id": subject, "rating": 4.5, "body": "ที่พักสวยมาก"})
	if c.Status != 201 {
		t.Fatalf("create: %d %v", c.Status, c.Body)
	}
	if r := call(t, "POST", "/api/v1/reviews", alice.Token, map[string]any{"subject_type": "HOTEL", "subject_id": subject, "rating": 5}); r.Status != 409 {
		t.Errorf("duplicate = %d", r.Status)
	}
	call(t, "POST", "/api/v1/reviews", bob.Token, map[string]any{"subject_type": "HOTEL", "subject_id": subject, "rating": 4})
	l := call(t, "GET", "/api/v1/reviews?subject_type=HOTEL&subject_id="+subject, alice.Token, nil)
	sum := l.data()["summary"].(map[string]any)
	if len(l.data()["items"].([]any)) != 2 || sum["count"] != float64(2) || sum["average"] != 4.3 {
		t.Fatalf("list/summary (DECIMAL rating must round-trip): %v", l.Body)
	}
	mine := 0
	for _, it := range l.data()["items"].([]any) {
		if it.(map[string]any)["mine"] == true {
			mine++
		}
	}
	if mine != 1 {
		t.Errorf("exactly one item should be mine, got %d", mine)
	}
	id := c.data()["id"].(string)
	if r := call(t, "DELETE", "/api/v1/reviews/"+id, bob.Token, nil); r.Status != 404 {
		t.Errorf("deleting someone else's review = %d", r.Status)
	}
	if r := call(t, "DELETE", "/api/v1/reviews/"+id, alice.Token, nil); r.Status != 204 {
		t.Errorf("delete = %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/reviews", alice.Token, map[string]any{"subject_type": "HOTEL", "subject_id": subject, "rating": 5}); r.Status != 201 {
		t.Errorf("re-review after deletion must be allowed: %d", r.Status)
	}
}

func TestConcurrentDuplicateReviewsCreateOnlyOne(t *testing.T) {
	u := newUser(t)
	subject := "r-" + uuid.NewString()[:8]
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			call(t, "POST", "/api/v1/reviews", u.Token, map[string]any{"subject_type": "TOUR", "subject_id": subject, "rating": 5})
		}()
	}
	wg.Wait()
	var n int
	db.QueryRow("SELECT COUNT(*) FROM reviews WHERE user_id = ? AND subject_id = ? AND deleted_at IS NULL", u.ID, subject).Scan(&n)
	if n != 1 {
		t.Fatalf("%d reviews were stored for one user and subject, want 1", n)
	}
}

func TestPortalTransitionsAreEnforcedAndAudited(t *testing.T) {
	staff := newUser(t, "STAFF")
	customer := newUser(t)
	if r := call(t, "GET", "/api/v1/portal/queue", customer.Token, nil); r.Status != 403 {
		t.Errorf("customer on portal = %d", r.Status)
	}
	bid := uuid.NewString()
	if _, err := db.Exec("INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'THB', 1000.00, 'PENDING')", bid, customer.ID, "IT"+bid[:8]); err != nil {
		t.Fatal(err)
	}
	// F1: a person must not be able to mark payments as paid
	if r := call(t, "PATCH", "/api/v1/portal/payments/x/verify", staff.Token, map[string]string{"status": "PAID"}); r.Status != 404 {
		t.Errorf("the payment verify endpoint must not exist, got %d", r.Status)
	}
	// F2: invalid jumps are refused
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "COMPLETED"}); r.Status != 400 {
		t.Errorf("unknown status = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "CONFIRMED"}); r.Status != 200 {
		t.Fatalf("PENDING→CONFIRMED = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "PENDING"}); r.Status != 400 && r.Status != 409 {
		t.Errorf("CONFIRMED→PENDING must be refused, got %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "CANCELLED"}); r.Status != 200 {
		t.Fatalf("CONFIRMED→CANCELLED = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "CONFIRMED"}); r.Status != 409 {
		t.Errorf("CANCELLED is terminal, got %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/portal/bookings/"+uuid.NewString()+"/status", staff.Token, map[string]string{"status": "CONFIRMED"}); r.Status != 404 {
		t.Errorf("unknown booking = %d", r.Status)
	}
	var audits int
	db.QueryRow("SELECT COUNT(*) FROM audit_logs WHERE subject_type = 'booking' AND subject_id = ? AND actor_user_id = ?", bid, staff.ID).Scan(&audits)
	if audits != 2 {
		t.Errorf("each successful change must have exactly one audit row, got %d", audits)
	}
	var status string
	db.QueryRow("SELECT status FROM bookings WHERE id = ?", bid).Scan(&status)
	if status != "CANCELLED" {
		t.Errorf("final status %s", status)
	}

	// disputes require an existing booking
	if r := call(t, "POST", "/api/v1/portal/disputes", staff.Token, map[string]string{"booking_id": uuid.NewString(), "reason": "x"}); r.Status != 404 {
		t.Errorf("dispute on a missing booking = %d", r.Status)
	}
	d := call(t, "POST", "/api/v1/portal/disputes", staff.Token, map[string]string{"booking_id": bid, "reason": "เรียกเก็บซ้ำ"})
	if d.Status != 201 {
		t.Fatalf("dispute: %d %v", d.Status, d.Body)
	}
}

func TestConcurrentStatusChangesApplyExactlyOnce(t *testing.T) {
	staff := newUser(t, "STAFF")
	bid := uuid.NewString()
	if _, err := db.Exec("INSERT INTO bookings (id, created_at, updated_at, user_id, booking_code, currency_code, total_amount, status) VALUES (?, UTC_TIMESTAMP(6), UTC_TIMESTAMP(6), ?, ?, 'THB', 1.00, 'PENDING')", bid, staff.ID, "CC"+bid[:8]); err != nil {
		t.Fatal(err)
	}
	var wg sync.WaitGroup
	var mu sync.Mutex
	ok := 0
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			if call(t, "PATCH", "/api/v1/portal/bookings/"+bid+"/status", staff.Token, map[string]string{"status": "CONFIRMED"}).Status == 200 {
				mu.Lock()
				ok++
				mu.Unlock()
			}
		}()
	}
	wg.Wait()
	var audits int
	db.QueryRow("SELECT COUNT(*) FROM audit_logs WHERE subject_type = 'booking' AND subject_id = ?", bid).Scan(&audits)
	if ok != 1 || audits != 1 {
		t.Fatalf("PENDING→CONFIRMED succeeded %d times with %d audit rows, want 1 and 1", ok, audits)
	}
}

func TestAdminRoleAssignment(t *testing.T) {
	admin1, admin2, target := newUser(t, "ADMIN"), newUser(t, "ADMIN"), newUser(t)
	if r := call(t, "PUT", "/api/v1/admin/users/"+admin1.ID+"/roles", admin1.Token, map[string]string{"role": "STAFF"}); r.Status != 403 {
		t.Errorf("changing your own roles = %d", r.Status)
	}
	if r := call(t, "PUT", "/api/v1/admin/users/"+target.ID+"/roles", target.Token, map[string]string{"role": "ADMIN"}); r.Status != 403 {
		t.Errorf("a customer must not assign roles = %d", r.Status)
	}
	for i, want := range []bool{true, false} {
		r := call(t, "PUT", "/api/v1/admin/users/"+target.ID+"/roles", admin2.Token, map[string]string{"role": "STAFF"})
		if r.Status != 200 || r.data()["new_assignment"] != want {
			t.Errorf("grant #%d: %d %v", i+1, r.Status, r.Body)
		}
	}
	var n, audits int
	db.QueryRow("SELECT COUNT(*) FROM user_roles ur JOIN roles r ON r.id = ur.role_id WHERE ur.user_id = ? AND r.code = 'STAFF' AND ur.deleted_at IS NULL", target.ID).Scan(&n)
	db.QueryRow("SELECT COUNT(*) FROM audit_logs WHERE subject_type = 'user' AND subject_id = ? AND action = 'user.role.assigned'", target.ID).Scan(&audits)
	if n != 1 || audits != 2 {
		t.Fatalf("active STAFF grants=%d (want 1), audit rows=%d (want 2)", n, audits)
	}
	if r := call(t, "PUT", "/api/v1/admin/users/"+uuid.NewString()+"/roles", admin2.Token, map[string]string{"role": "STAFF"}); r.Status != 404 {
		t.Errorf("unknown user = %d", r.Status)
	}
}

var _ = http.StatusOK
