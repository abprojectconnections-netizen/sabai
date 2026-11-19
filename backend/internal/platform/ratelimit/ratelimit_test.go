package ratelimit

import (
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/gin-gonic/gin"
)

func TestAllowCountsPerKeyAndResetsAfterTheWindow(t *testing.T) {
	now := time.Date(2030, 1, 1, 0, 0, 0, 0, time.UTC)
	l := New(2, time.Minute)
	l.nowFor = func() time.Time { return now }
	for i := 0; i < 2; i++ {
		if ok, _ := l.Allow("a"); !ok {
			t.Fatalf("request %d should pass", i+1)
		}
	}
	ok, wait := l.Allow("a")
	if ok || wait <= 0 || wait > time.Minute {
		t.Fatalf("third request: ok=%v wait=%v", ok, wait)
	}
	if ok, _ := l.Allow("b"); !ok {
		t.Fatal("another key has its own budget")
	}
	now = now.Add(time.Minute)
	if ok, _ := l.Allow("a"); !ok {
		t.Fatal("window must reset")
	}
}

func TestDisabledLimiterAllowsEverything(t *testing.T) {
	l := New(0, time.Minute)
	for i := 0; i < 100; i++ {
		if ok, _ := l.Allow("a"); !ok {
			t.Fatal("limit 0 means off")
		}
	}
	var none *Limiter
	if ok, _ := none.Allow("a"); !ok {
		t.Fatal("nil limiter means off")
	}
}

func TestMiddlewareLimitsWritesOnlyAndSendsRetryAfter(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(New(1, time.Minute).PerIPWrites())
	r.GET("/x", func(c *gin.Context) { c.Status(http.StatusOK) })
	r.POST("/x", func(c *gin.Context) { c.Status(http.StatusOK) })
	do := func(method string) *httptest.ResponseRecorder {
		w := httptest.NewRecorder()
		req := httptest.NewRequest(method, "/x", nil)
		req.RemoteAddr = "203.0.113.7:1234"
		r.ServeHTTP(w, req)
		return w
	}
	for i := 0; i < 5; i++ {
		if w := do(http.MethodGet); w.Code != http.StatusOK {
			t.Fatalf("reads are never limited, got %d", w.Code)
		}
	}
	if w := do(http.MethodPost); w.Code != http.StatusOK {
		t.Fatalf("first write = %d", w.Code)
	}
	w := do(http.MethodPost)
	if w.Code != http.StatusTooManyRequests || w.Header().Get("Retry-After") == "" {
		t.Fatalf("second write = %d, Retry-After %q", w.Code, w.Header().Get("Retry-After"))
	}
}
