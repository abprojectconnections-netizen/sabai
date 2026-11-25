//go:build integration

package integration

import "testing"

func TestFeatureFlagsKillSwitchIsEnforcedAndAudited(t *testing.T) {
	admin, auditor, customer := newUser(t, "ADMIN"), newUser(t, "AUDITOR"), newUser(t)
	flag := "/api/v1/admin/feature-flags/community.posting"
	// Always leave the shared database with the flag back on, even if an assertion below fails.
	t.Cleanup(func() { call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": true}) })

	for _, e := range []struct{ method, path string }{{"GET", "/api/v1/admin/feature-flags"}, {"PATCH", flag}} {
		if r := call(t, e.method, e.path, "", map[string]any{"enabled": false, "reason": "x"}); r.Status != 401 {
			t.Errorf("anonymous %s = %d", e.method, r.Status)
		}
		for who, tok := range map[string]string{"customer": customer.Token, "auditor": auditor.Token} {
			if r := call(t, e.method, e.path, tok, map[string]any{"enabled": false, "reason": "x"}); r.Status != 403 {
				t.Errorf("%s %s = %d, want 403", who, e.method, r.Status)
			}
		}
	}

	items := adminItems(t, call(t, "GET", "/api/v1/admin/feature-flags", admin.Token, nil))
	seen := map[string]bool{}
	for _, f := range items {
		seen[f["key"].(string)] = f["enabled"].(bool)
	}
	if on, ok := seen["community.posting"]; !ok || !on {
		t.Fatalf("seeded flag community.posting should exist and be on: %v", items)
	}
	if _, ok := seen["coupons.claiming"]; !ok {
		t.Fatalf("seeded flag coupons.claiming missing: %v", items)
	}

	// Validation.
	if r := call(t, "PATCH", flag, admin.Token, map[string]any{}); r.Status != 400 {
		t.Errorf("missing enabled = %d", r.Status)
	}
	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": false}); r.Status != 400 {
		t.Errorf("turning off without a reason = %d", r.Status)
	}
	if r := call(t, "PATCH", "/api/v1/admin/feature-flags/no.such.flag", admin.Token, map[string]any{"enabled": true}); r.Status != 404 {
		t.Errorf("unknown flag = %d", r.Status)
	}

	post := func() resp {
		return call(t, "POST", "/api/v1/community/posts", customer.Token, map[string]any{"body": "flag test post"})
	}
	if r := post(); r.Status != 201 {
		t.Fatalf("posting while enabled = %d %v", r.Status, r.Body)
	}

	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": false, "reason": "สแปมเข้าชุมชน"}); r.Status != 200 {
		t.Fatalf("disable: %d %v", r.Status, r.Body)
	}
	if r := post(); r.Status != 503 || r.code() != "FEATURE_DISABLED" {
		t.Errorf("posting while disabled = %d %s, want 503 FEATURE_DISABLED", r.Status, r.code())
	}
	// Only posting is switched off: reading the feed still works, and other features are unaffected.
	if r := call(t, "GET", "/api/v1/community/posts", customer.Token, nil); r.Status != 200 {
		t.Errorf("reading the feed while posting is off = %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/coupons/mine", customer.Token, nil); r.Status != 200 {
		t.Errorf("unrelated feature = %d", r.Status)
	}
	// Clients can see the state, so they can hide the control.
	cfg := call(t, "GET", "/api/v1/config/flags", customer.Token, nil)
	if cfg.Status != 200 || cfg.data()["flags"].(map[string]any)["community.posting"] != false {
		t.Errorf("config/flags = %d %v", cfg.Status, cfg.Body)
	}
	// Repeating the same value is a no-op: no second audit row.
	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": false, "reason": "again"}); r.Status != 200 {
		t.Fatalf("repeat disable: %d", r.Status)
	}

	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": true}); r.Status != 200 {
		t.Fatalf("re-enable: %d", r.Status)
	}
	if r := post(); r.Status != 201 {
		t.Errorf("posting after re-enable = %d", r.Status)
	}

	logs := adminItems(t, call(t, "GET", "/api/v1/admin/audit-logs?action=feature_flag.changed&limit=50", auditor.Token, nil))
	var mine []map[string]any
	for _, l := range logs {
		if l["actor_user_id"] == admin.ID {
			mine = append(mine, l)
		}
	}
	if len(mine) != 2 {
		t.Fatalf("expected exactly 2 audit rows from this admin (off, on), got %d: %v", len(mine), mine)
	}
	if mine[1]["after"].(map[string]any)["reason"] != "สแปมเข้าชุมชน" || mine[1]["after"].(map[string]any)["enabled"] != false {
		t.Errorf("off row: %v", mine[1])
	}
	if mine[0]["after"].(map[string]any)["enabled"] != true || mine[0]["before"].(map[string]any)["enabled"] != false {
		t.Errorf("on row: %v", mine[0])
	}
}

func TestCouponClaimingFlagBlocksClaimOnly(t *testing.T) {
	admin, customer := newUser(t, "ADMIN"), newUser(t)
	flag := "/api/v1/admin/feature-flags/coupons.claiming"
	t.Cleanup(func() { call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": true}) })
	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": false, "reason": "เดาโค้ด"}); r.Status != 200 {
		t.Fatalf("disable: %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/coupons/claim", customer.Token, map[string]any{"code": "WHATEVER"}); r.Status != 503 {
		t.Errorf("claim while disabled = %d, want 503", r.Status)
	}
	if r := call(t, "GET", "/api/v1/coupons/mine", customer.Token, nil); r.Status != 200 {
		t.Errorf("mine while claiming is off = %d", r.Status)
	}
	if r := call(t, "PATCH", flag, admin.Token, map[string]any{"enabled": true}); r.Status != 200 {
		t.Fatalf("enable: %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/coupons/claim", customer.Token, map[string]any{"code": "NO-SUCH-CODE"}); r.Status != 404 {
		t.Errorf("claim of an unknown code after re-enable = %d, want 404 (not 503)", r.Status)
	}
}
