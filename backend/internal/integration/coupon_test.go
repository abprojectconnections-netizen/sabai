//go:build integration

package integration

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

// seedCoupon inserts a discount rule and a coupon on it; offsets are in days from now (nil = no bound).
func seedCoupon(t *testing.T, code, status string, fromDays, toDays *int, max *int, redeemed int) {
	t.Helper()
	now := time.Now().UTC()
	at := func(d *int) any {
		if d == nil {
			return nil
		}
		return now.AddDate(0, 0, *d)
	}
	zero := -30
	from := at(&zero)
	if fromDays != nil {
		from = at(fromDays)
	}
	did := uuid.NewString()
	if _, err := db.Exec("INSERT INTO discounts (id, created_at, owner_type, discount_type, value, valid_from, valid_to, funded_by, status) VALUES (?, ?, 'PLATFORM', 'PERCENT', 10.00, ?, ?, 'PLATFORM', ?)", did, now, from, at(toDays), status); err != nil {
		t.Fatalf("discount: %v", err)
	}
	if _, err := db.Exec("INSERT INTO coupons (id, created_at, updated_at, code, max_redemptions, redeemed_count, discount_id) VALUES (?, ?, ?, ?, ?, ?, ?)", uuid.NewString(), now, now, code, max, redeemed, did); err != nil {
		t.Fatalf("coupon: %v", err)
	}
}

func ip(n int) *int { return &n }

func TestCouponSaveAndListShowsStateAndNeverTouchesPrices(t *testing.T) {
	a, b := newUser(t), newUser(t)
	code := "SAVE" + uuid.NewString()[:6]
	seedCoupon(t, code, "ACTIVE", nil, ip(30), nil, 0)

	// Case-insensitive code; saving twice conflicts.
	if r := call(t, "POST", "/api/v1/coupons/claim", a.Token, map[string]any{"code": " " + toLower(code) + " "}); r.Status != 201 {
		t.Fatalf("claim = %d %v", r.Status, r.Body)
	}
	if r := call(t, "POST", "/api/v1/coupons/claim", a.Token, map[string]any{"code": code}); r.Status != 409 {
		t.Errorf("second claim = %d", r.Status)
	}
	mine := call(t, "GET", "/api/v1/coupons/mine", a.Token, nil).data()["items"].([]any)
	if len(mine) != 1 {
		t.Fatalf("mine = %v", mine)
	}
	c := mine[0].(map[string]any)
	if c["code"] != code || c["state"] != "ACTIVE" || c["discount_type"] != "PERCENT" || c["value"] != "10.00" || c["valid_until"] == "" {
		t.Fatalf("coupon = %v", c)
	}
	// Per user: b has none; saving must not consume a redemption.
	if items := call(t, "GET", "/api/v1/coupons/mine", b.Token, nil).data()["items"].([]any); len(items) != 0 {
		t.Fatalf("another user's list = %v", items)
	}
	var redeemed int
	if err := db.QueryRow("SELECT redeemed_count FROM coupons WHERE code = ?", code).Scan(&redeemed); err != nil || redeemed != 0 {
		t.Fatalf("redeemed_count = %d (%v): saving a coupon must not use it", redeemed, err)
	}
}

func TestCouponClaimRejectsUnusableCoupons(t *testing.T) {
	a := newUser(t)
	cases := []struct {
		name     string
		status   string
		from, to *int
		max      *int
		redeemed int
		want     int
	}{
		{"expired", "ACTIVE", ip(-20), ip(-1), nil, 0, 409},
		{"not started", "ACTIVE", ip(2), ip(30), nil, 0, 409},
		{"fully redeemed", "ACTIVE", nil, ip(30), ip(5), 5, 409},
		{"paused discount", "PAUSED", nil, ip(30), nil, 0, 404},
		{"draft discount", "DRAFT", nil, ip(30), nil, 0, 404},
	}
	for _, c := range cases {
		code := "BAD" + uuid.NewString()[:7]
		seedCoupon(t, code, c.status, c.from, c.to, c.max, c.redeemed)
		if r := call(t, "POST", "/api/v1/coupons/claim", a.Token, map[string]any{"code": code}); r.Status != c.want {
			t.Errorf("%s = %d %v, want %d", c.name, r.Status, r.Body, c.want)
		}
	}
	for _, code := range []string{"NOPE" + uuid.NewString()[:6], "", "a b", "<x>"} {
		want := 404
		if code == "" || code == "a b" || code == "<x>" {
			want = 400
		}
		if r := call(t, "POST", "/api/v1/coupons/claim", a.Token, map[string]any{"code": code}); r.Status != want {
			t.Errorf("code %q = %d, want %d", code, r.Status, want)
		}
	}
	if r := call(t, "POST", "/api/v1/coupons/claim", "", map[string]any{"code": "X"}); r.Status != 401 {
		t.Errorf("anonymous = %d", r.Status)
	}
	if items := call(t, "GET", "/api/v1/coupons/mine", a.Token, nil).data()["items"].([]any); len(items) != 0 {
		t.Fatalf("an unusable coupon was saved: %v", items)
	}
}

func TestSavedCouponStateFollowsTheCouponAfterwards(t *testing.T) {
	a := newUser(t)
	code := "LATER" + uuid.NewString()[:5]
	seedCoupon(t, code, "ACTIVE", nil, ip(30), ip(3), 0)
	if r := call(t, "POST", "/api/v1/coupons/claim", a.Token, map[string]any{"code": code}); r.Status != 201 {
		t.Fatalf("claim = %d", r.Status)
	}
	state := func() string {
		return call(t, "GET", "/api/v1/coupons/mine", a.Token, nil).data()["items"].([]any)[0].(map[string]any)["state"].(string)
	}
	if state() != "ACTIVE" {
		t.Fatalf("state = %s", state())
	}
	if _, err := db.Exec("UPDATE coupons SET redeemed_count = 3 WHERE code = ?", code); err != nil {
		t.Fatal(err)
	}
	if state() != "EXHAUSTED" {
		t.Errorf("after use-up: %s", state())
	}
	if _, err := db.Exec("UPDATE coupons SET redeemed_count = 0, expires_at = ? WHERE code = ?", time.Now().UTC().Add(-time.Hour), code); err != nil {
		t.Fatal(err)
	}
	if state() != "EXPIRED" { // the coupon's own expiry wins over a later discount end
		t.Errorf("after coupon expiry: %s", state())
	}
	if _, err := db.Exec("UPDATE coupons SET expires_at = NULL, deleted_at = ? WHERE code = ?", time.Now().UTC(), code); err != nil {
		t.Fatal(err)
	}
	if state() != "UNAVAILABLE" {
		t.Errorf("after delete: %s", state())
	}
}
