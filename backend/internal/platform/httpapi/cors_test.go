package httpapi

import (
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/gin-gonic/gin"
)

func TestPreflightAllowsTheHeadersTheWebAppSends(t *testing.T) {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(CORS("http://localhost:5173"))
	r.POST("/x", func(c *gin.Context) { c.Status(204) })
	req := httptest.NewRequest(http.MethodOptions, "/x", nil)
	req.Header.Set("Origin", "http://localhost:5173")
	req.Header.Set("Access-Control-Request-Method", "POST")
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	allowed := w.Header().Get("Access-Control-Allow-Headers")
	// a browser blocks the real request when any custom header is missing here: Idempotency-Key is what booking, payment and refund send
	for _, h := range []string{"Authorization", "Content-Type", "Idempotency-Key", "X-Request-ID"} {
		if !strings.Contains(allowed, h) {
			t.Errorf("preflight does not allow %s (got %q)", h, allowed)
		}
	}
	other := httptest.NewRequest(http.MethodOptions, "/x", nil)
	other.Header.Set("Origin", "https://evil.example")
	other.Header.Set("Access-Control-Request-Method", "POST")
	w2 := httptest.NewRecorder()
	r.ServeHTTP(w2, other)
	if w2.Header().Get("Access-Control-Allow-Origin") != "" {
		t.Error("an origin that is not configured must not be allowed")
	}
}
