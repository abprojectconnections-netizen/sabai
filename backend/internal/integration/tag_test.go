//go:build integration

package integration

import (
	"sync"
	"testing"

	"github.com/google/uuid"
)

func slugs(r resp) []string {
	out := []string{}
	for _, x := range r.list() {
		out = append(out, x.(map[string]any)["slug"].(string))
	}
	return out
}

func newTrip(t *testing.T, u user) string {
	t.Helper()
	r := call(t, "POST", "/api/v1/trips", u.Token, map[string]any{"name": "ทริปแท็ก"})
	if r.Status != 201 {
		t.Fatalf("trip: %d %v", r.Status, r.Body)
	}
	return r.data()["id"].(string)
}

func TestTagsOnOwnTripAreSetNormalisedAndReplaced(t *testing.T) {
	a := newUser(t)
	trip := newTrip(t, a)
	path := "/api/v1/content/TRIP/" + trip + "/tags"

	r := call(t, "PUT", path, a.Token, map[string]any{"tags": []string{"ธรรมชาติ", "Cafe Hop", "cafe  hop"}})
	if r.Status != 200 {
		t.Fatalf("set: %d %v", r.Status, r.Body)
	}
	got := slugs(r)
	if len(got) != 2 || got[0] != "cafe-hop" || got[1] != "ธรรมชาติ" { // duplicates by slug collapse; Thai marks survive
		t.Fatalf("tags = %v", got)
	}
	// PUT replaces the whole set and is idempotent.
	r = call(t, "PUT", path, a.Token, map[string]any{"tags": []string{"ภูเขา"}})
	call(t, "PUT", path, a.Token, map[string]any{"tags": []string{"ภูเขา"}})
	if got := slugs(call(t, "GET", path, a.Token, nil)); len(got) != 1 || got[0] != "ภูเขา" {
		t.Fatalf("after replace: %v", got)
	}
	// An empty list clears.
	call(t, "PUT", path, a.Token, map[string]any{"tags": []string{}})
	if got := slugs(call(t, "GET", path, a.Token, nil)); len(got) != 0 {
		t.Fatalf("after clear: %v", got)
	}
}

func TestTagValidationAndAuthorisation(t *testing.T) {
	a, b := newUser(t), newUser(t)
	trip := newTrip(t, a)
	path := "/api/v1/content/TRIP/" + trip + "/tags"

	bad := [][]string{{""}, {"a/b"}, {"<b>"}, {"123456789012345678901234567890x"}}
	for _, tags := range bad {
		if r := call(t, "PUT", path, a.Token, map[string]any{"tags": tags}); r.Status != 400 {
			t.Errorf("%v = %d, want 400", tags, r.Status)
		}
	}
	eleven := []string{"a1", "a2", "a3", "a4", "a5", "a6", "a7", "a8", "a9", "a10", "a11"}
	if r := call(t, "PUT", path, a.Token, map[string]any{"tags": eleven}); r.Status != 400 {
		t.Errorf("11 tags = %d", r.Status)
	}
	if r := call(t, "PUT", path, a.Token, map[string]any{}); r.Status != 400 {
		t.Errorf("missing tags field = %d", r.Status)
	}
	if r := call(t, "PUT", "/api/v1/content/POST/"+trip+"/tags", a.Token, map[string]any{"tags": []string{"x"}}); r.Status != 400 {
		t.Errorf("unknown type = %d", r.Status)
	}
	// Another user cannot see or change a private trip's tags: 404, not 403 (no existence leak).
	if r := call(t, "PUT", path, b.Token, map[string]any{"tags": []string{"x"}}); r.Status != 404 {
		t.Errorf("foreign write = %d", r.Status)
	}
	if r := call(t, "GET", path, b.Token, nil); r.Status != 404 {
		t.Errorf("foreign read = %d", r.Status)
	}
	if r := call(t, "PUT", path, "", map[string]any{"tags": []string{"x"}}); r.Status != 401 {
		t.Errorf("anonymous = %d", r.Status)
	}
	if r := call(t, "PUT", "/api/v1/content/TRIP/"+uuid.NewString()+"/tags", a.Token, map[string]any{"tags": []string{"x"}}); r.Status != 404 {
		t.Errorf("missing content = %d", r.Status)
	}
}

func TestReviewTagsArePublicToReadButOnlyTheAuthorWritesAndTripTagsStayPrivate(t *testing.T) {
	a, b := newUser(t), newUser(t)
	marker := "t" + uuid.NewString()[:8]
	rv := call(t, "POST", "/api/v1/reviews", a.Token, map[string]any{"subject_type": "HOTEL", "subject_id": "h-" + marker, "rating": 4.5, "body": "ดี"})
	if rv.Status != 201 {
		t.Fatalf("review: %d %v", rv.Status, rv.Body)
	}
	review := rv.data()["id"].(string)
	trip := newTrip(t, a)

	if r := call(t, "PUT", "/api/v1/content/REVIEW/"+review+"/tags", a.Token, map[string]any{"tags": []string{marker + "-pub"}}); r.Status != 200 {
		t.Fatalf("author tags review: %d %v", r.Status, r.Body)
	}
	if r := call(t, "PUT", "/api/v1/content/REVIEW/"+review+"/tags", b.Token, map[string]any{"tags": []string{"hijack"}}); r.Status != 404 {
		t.Errorf("non-author write = %d", r.Status)
	}
	if got := slugs(call(t, "GET", "/api/v1/content/REVIEW/"+review+"/tags", b.Token, nil)); len(got) != 1 {
		t.Errorf("another user can read review tags: %v", got)
	}
	call(t, "PUT", "/api/v1/content/TRIP/"+trip+"/tags", a.Token, map[string]any{"tags": []string{marker + "-secret"}})

	// Public statistics count review tags only: a private trip's tag never appears.
	pop := call(t, "GET", "/api/v1/tags?q="+marker, b.Token, nil)
	if got := slugs(pop); len(got) != 1 || got[0] != marker+"-pub" {
		t.Fatalf("popular = %v (private trip tag must not leak)", got)
	}
	if pop.list()[0].(map[string]any)["uses"] != float64(1) {
		t.Fatalf("uses: %v", pop.Body)
	}
	// Search by tag respects visibility.
	byTag := call(t, "GET", "/api/v1/tags/"+marker+"-pub/content?type=REVIEW", b.Token, nil)
	if ids := byTag.data()["items"].([]any); len(ids) != 1 || ids[0] != review {
		t.Fatalf("by tag: %v", byTag.Body)
	}
	if ids := call(t, "GET", "/api/v1/tags/"+marker+"-secret/content?type=TRIP", b.Token, nil).data()["items"].([]any); len(ids) != 0 {
		t.Fatalf("another user found a private trip by tag: %v", ids)
	}
	if ids := call(t, "GET", "/api/v1/tags/"+marker+"-secret/content?type=TRIP", a.Token, nil).data()["items"].([]any); len(ids) != 1 || ids[0] != trip {
		t.Fatalf("owner by tag: %v", ids)
	}
	// Deleting the review removes it from search and statistics.
	call(t, "DELETE", "/api/v1/reviews/"+review, a.Token, nil)
	if ids := call(t, "GET", "/api/v1/tags/"+marker+"-pub/content?type=REVIEW", b.Token, nil).data()["items"].([]any); len(ids) != 0 {
		t.Fatalf("deleted review still found: %v", ids)
	}
	if got := slugs(call(t, "GET", "/api/v1/tags?q="+marker, b.Token, nil)); len(got) != 0 {
		t.Fatalf("deleted review still counted: %v", got)
	}
	// LIKE wildcards in q are literal.
	if got := slugs(call(t, "GET", "/api/v1/tags?q=%25", b.Token, nil)); len(got) != 0 {
		t.Fatalf("wildcard matched: %v", got)
	}
}

func TestConcurrentTaggingOfTheSameContentLeavesOneConsistentSet(t *testing.T) {
	a := newUser(t)
	trip := newTrip(t, a)
	path := "/api/v1/content/TRIP/" + trip + "/tags"
	shared := "c" + uuid.NewString()[:8]
	var wg sync.WaitGroup
	for i := 0; i < 8; i++ {
		wg.Add(1)
		go func(i int) {
			defer wg.Done()
			r := call(t, "PUT", path, a.Token, map[string]any{"tags": []string{shared, "x" + shared + string(rune('a'+i))}})
			if r.Status != 200 {
				t.Errorf("writer %d: %d %v", i, r.Status, r.Body)
			}
		}(i)
	}
	wg.Wait()
	got := slugs(call(t, "GET", path, a.Token, nil))
	if len(got) != 2 { // the last writer's set, never a mix
		t.Fatalf("tags after race = %v", got)
	}
	var tags int
	if err := db.QueryRow("SELECT COUNT(*) FROM tags WHERE slug = ?", shared).Scan(&tags); err != nil || tags != 1 {
		t.Fatalf("shared tag rows = %d (%v)", tags, err)
	}
}
