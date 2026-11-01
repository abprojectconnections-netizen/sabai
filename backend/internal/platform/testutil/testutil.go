// Package testutil holds helpers shared by handler tests. It must only be imported from _test.go files.
package testutil

import (
	"bytes"
	"database/sql"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/auth"
)

// Contains matches a query when it contains the expected fragment (whitespace-normalised).
var Contains sqlmock.QueryMatcher = sqlmock.QueryMatcherFunc(func(expected, actual string) error {
	norm := func(s string) string { return strings.Join(strings.Fields(s), " ") }
	if !strings.Contains(norm(actual), norm(expected)) {
		return &mismatch{expected: expected, actual: actual}
	}
	return nil
})

type mismatch struct{ expected, actual string }

func (m *mismatch) Error() string {
	return "query mismatch\n expected fragment: " + m.expected + "\n actual: " + m.actual
}

func NewDB(t *testing.T) (*sql.DB, sqlmock.Sqlmock) {
	t.Helper()
	db, mock, err := sqlmock.New(sqlmock.QueryMatcherOption(Contains))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db, mock
}

// Router returns an engine whose requests are authenticated as the user in the X-Test-User header
// (no header = unauthenticated), so handlers can be tested without the JWT/role middleware.
func Router(register func(rg *gin.RouterGroup)) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	r.Use(func(c *gin.Context) {
		if u := c.GetHeader("X-Test-User"); u != "" {
			auth.SetPrincipal(c, auth.Principal{UserID: u, Roles: map[string]bool{"CUSTOMER": true}})
		}
		c.Next()
	})
	register(r.Group("/t"))
	return r
}

type Response struct {
	Status int
	Body   map[string]any
}

// Do sends a request as the given user ("" = anonymous) and decodes the JSON envelope.
func Do(t *testing.T, r http.Handler, user, method, path string, body any) Response {
	t.Helper()
	var buf bytes.Buffer
	if body != nil {
		switch b := body.(type) {
		case string:
			buf.WriteString(b)
		default:
			if err := json.NewEncoder(&buf).Encode(b); err != nil {
				t.Fatal(err)
			}
		}
	}
	req := httptest.NewRequest(method, path, &buf)
	req.Header.Set("Content-Type", "application/json")
	if user != "" {
		req.Header.Set("X-Test-User", user)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	out := Response{Status: w.Code}
	if w.Body.Len() > 0 {
		if err := json.Unmarshal(w.Body.Bytes(), &out.Body); err != nil {
			t.Fatalf("response is not JSON: %q", w.Body.String())
		}
	}
	return out
}

// ErrorCode extracts error.code from an envelope ("" when there is no error).
func (r Response) ErrorCode() string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		s, _ := e["code"].(string)
		return s
	}
	return ""
}

func (r Response) ErrorMessage() string {
	if e, ok := r.Body["error"].(map[string]any); ok {
		s, _ := e["message"].(string)
		return s
	}
	return ""
}
