//go:build integration

package integration

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/google/uuid"
)

func toJSON(v any) string { b, _ := json.Marshal(v); return string(b) }

func toLower(s string) string { return strings.ToLower(s) }

func feedIDs(r resp) []string {
	out := []string{}
	for _, x := range r.data()["items"].([]any) {
		out = append(out, x.(map[string]any)["id"].(string))
	}
	return out
}

func contains(ids []string, id string) bool {
	for _, x := range ids {
		if x == id {
			return true
		}
	}
	return false
}

func TestCommunityPostIsVisibleImmediatelyAndNeverLeaksTheEmail(t *testing.T) {
	a, b := newUser(t), newUser(t)
	marker := "โพสต์ " + uuid.NewString()[:8]
	r := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": "  " + marker + "  "})
	if r.Status != 201 {
		t.Fatalf("create: %d %v", r.Status, r.Body)
	}
	post := r.data()
	id := post["id"].(string)
	if post["body"] != marker || post["mine"] != true || strings.Contains(strings.ToLower(toJSON(post)), "@") {
		t.Fatalf("post = %v", post)
	}
	// Published at once: another user sees it, flagged as not theirs.
	feed := call(t, "GET", "/api/v1/community/posts?limit=100", b.Token, nil)
	if !contains(feedIDs(feed), id) {
		t.Fatalf("not in feed: %v", feed.Body)
	}
	for _, x := range feed.data()["items"].([]any) {
		m := x.(map[string]any)
		if m["id"] == id && (m["mine"] != false || m["author"].(map[string]any)["display_name"] == "") {
			t.Fatalf("author view: %v", m)
		}
		if strings.Contains(toJSON(m), "@") {
			t.Fatalf("e-mail leaked in feed: %v", m)
		}
	}
}

func TestCommunityPostValidationAndOwnership(t *testing.T) {
	a, b := newUser(t), newUser(t)
	for _, body := range []string{"", "   ", strings.Repeat("ก", 1001)} {
		if r := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": body}); r.Status != 400 {
			t.Errorf("body len %d = %d, want 400", len([]rune(body)), r.Status)
		}
	}
	if r := call(t, "POST", "/api/v1/community/posts", "", map[string]any{"body": "x"}); r.Status != 401 {
		t.Errorf("anonymous = %d", r.Status)
	}
	ok := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": strings.Repeat("ก", 1000)})
	if ok.Status != 201 {
		t.Fatalf("1000 characters must be accepted: %d", ok.Status)
	}
	id := ok.data()["id"].(string)
	if r := call(t, "DELETE", "/api/v1/community/posts/"+id, b.Token, nil); r.Status != 404 {
		t.Errorf("foreign delete = %d", r.Status)
	}
	if r := call(t, "DELETE", "/api/v1/community/posts/"+id, a.Token, nil); r.Status != 204 {
		t.Errorf("own delete = %d", r.Status)
	}
	if contains(feedIDs(call(t, "GET", "/api/v1/community/posts?limit=100", b.Token, nil)), id) {
		t.Error("deleted post still in feed")
	}
	if r := call(t, "DELETE", "/api/v1/community/posts/"+id, a.Token, nil); r.Status != 404 {
		t.Errorf("second delete = %d", r.Status)
	}
}

func TestCommunityReportHidesThePostForTheReporterOnly(t *testing.T) {
	a, b, c := newUser(t), newUser(t), newUser(t)
	id := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": "สแปม " + uuid.NewString()[:6]}).data()["id"].(string)
	path := "/api/v1/community/posts/" + id + "/report"

	if r := call(t, "POST", path, a.Token, map[string]any{"reason": "SPAM"}); r.Status != 400 {
		t.Errorf("reporting own post = %d", r.Status)
	}
	if r := call(t, "POST", path, b.Token, map[string]any{"reason": "NOPE"}); r.Status != 400 {
		t.Errorf("bad reason = %d", r.Status)
	}
	if r := call(t, "POST", path, b.Token, map[string]any{"reason": "spam", "detail": strings.Repeat("ก", 501)}); r.Status != 400 {
		t.Errorf("long detail = %d", r.Status)
	}
	if r := call(t, "POST", "/api/v1/community/posts/"+uuid.NewString()+"/report", b.Token, map[string]any{"reason": "SPAM"}); r.Status != 404 {
		t.Errorf("unknown post = %d", r.Status)
	}
	for i := 0; i < 2; i++ { // idempotent
		if r := call(t, "POST", path, b.Token, map[string]any{"reason": "spam", "detail": "โฆษณา"}); r.Status != 200 {
			t.Fatalf("report %d = %d %v", i, r.Status, r.Body)
		}
	}
	var n int
	if err := db.QueryRow("SELECT COUNT(*) FROM community_reports WHERE post_id = ?", id).Scan(&n); err != nil || n != 1 {
		t.Fatalf("report rows = %d (%v)", n, err)
	}
	if contains(feedIDs(call(t, "GET", "/api/v1/community/posts?limit=100", b.Token, nil)), id) {
		t.Error("the reporter still sees the post")
	}
	if !contains(feedIDs(call(t, "GET", "/api/v1/community/posts?limit=100", c.Token, nil)), id) {
		t.Error("an unrelated user lost the post: one report must not remove it for everyone")
	}
}

func TestCommunityPostTagsUseTheCentralTagSystem(t *testing.T) {
	a, b := newUser(t), newUser(t)
	marker := "g" + uuid.NewString()[:8]
	id := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": "แท็ก"}).data()["id"].(string)
	if r := call(t, "PUT", "/api/v1/content/COMMUNITY_POST/"+id+"/tags", b.Token, map[string]any{"tags": []string{"x"}}); r.Status != 404 {
		t.Errorf("non-author tagging = %d", r.Status)
	}
	if r := call(t, "PUT", "/api/v1/content/COMMUNITY_POST/"+id+"/tags", a.Token, map[string]any{"tags": []string{marker, "คาเฟ่"}}); r.Status != 200 {
		t.Fatalf("author tagging = %d %v", r.Status, r.Body)
	}
	// Tags ride along in the feed (one query for the page).
	var tags []any
	for _, x := range call(t, "GET", "/api/v1/community/posts?limit=100", b.Token, nil).data()["items"].([]any) {
		if x.(map[string]any)["id"] == id {
			tags = x.(map[string]any)["tags"].([]any)
		}
	}
	if len(tags) != 2 {
		t.Fatalf("tags in feed = %v", tags)
	}
	if got := slugs(call(t, "GET", "/api/v1/tags?q="+marker, b.Token, nil)); len(got) != 1 || got[0] != marker {
		t.Fatalf("popular = %v", got)
	}
	if ids := call(t, "GET", "/api/v1/tags/"+marker+"/content?type=COMMUNITY_POST", b.Token, nil).data()["items"].([]any); len(ids) != 1 || ids[0] != id {
		t.Fatalf("by tag = %v", ids)
	}
	call(t, "DELETE", "/api/v1/community/posts/"+id, a.Token, nil)
	if got := slugs(call(t, "GET", "/api/v1/tags?q="+marker, b.Token, nil)); len(got) != 0 {
		t.Fatalf("a deleted post is still counted: %v", got)
	}
}

func TestCommunityWritesAreRateLimitedPerUser(t *testing.T) {
	a, b := newUser(t), newUser(t)
	limited := false
	for i := 0; i < 15; i++ {
		r := call(t, "POST", "/api/v1/community/posts", a.Token, map[string]any{"body": "สแปม " + uuid.NewString()[:6]})
		if r.Status == 429 {
			limited = r.code() == "RATE_LIMITED"
			break
		}
		if r.Status != 201 {
			t.Fatalf("post %d = %d", i, r.Status)
		}
	}
	if !limited {
		t.Fatal("a burst of posts must hit 429 RATE_LIMITED")
	}
	if r := call(t, "POST", "/api/v1/community/posts", b.Token, map[string]any{"body": "คนอื่นยังโพสต์ได้"}); r.Status != 201 {
		t.Fatalf("another user must not be affected: %d", r.Status)
	}
	if r := call(t, "GET", "/api/v1/community/posts", a.Token, nil); r.Status != 200 {
		t.Fatalf("reading stays allowed: %d", r.Status)
	}
}
