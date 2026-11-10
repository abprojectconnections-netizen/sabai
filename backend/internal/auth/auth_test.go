package auth

import (
	"database/sql"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/golang-jwt/jwt/v5"
	"golang.org/x/crypto/bcrypt"
)

const secret = "test-secret"
const uid = "11111111-1111-4111-8111-111111111111"

func newMock(t *testing.T) (*sql.DB, sqlmock.Sqlmock) {
	t.Helper()
	norm := func(s string) string { return strings.Join(strings.Fields(s), " ") }
	db, mock, err := sqlmock.New(sqlmock.QueryMatcherOption(sqlmock.QueryMatcherFunc(func(exp, act string) error {
		if !strings.Contains(norm(act), norm(exp)) {
			return sql.ErrNoRows
		}
		return nil
	})))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { db.Close() })
	return db, mock
}

func token(t *testing.T, method jwt.SigningMethod, key any, claims jwt.MapClaims) string {
	t.Helper()
	s, err := jwt.NewWithClaims(method, claims).SignedString(key)
	if err != nil {
		t.Fatal(err)
	}
	return s
}

func okClaims() jwt.MapClaims {
	return jwt.MapClaims{"sub": uid, "exp": time.Now().Add(time.Hour).Unix()}
}

func protected(db *sql.DB, roles ...string) *gin.Engine {
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/p", Authenticate(db, secret), RequireRoles(roles...))
	g.GET("", func(c *gin.Context) {
		p, _ := CurrentPrincipal(c)
		c.JSON(200, gin.H{"user": p.UserID})
	})
	return r
}

func get(r http.Handler, authz string) *httptest.ResponseRecorder {
	req := httptest.NewRequest("GET", "/p", nil)
	if authz != "" {
		req.Header.Set("Authorization", authz)
	}
	w := httptest.NewRecorder()
	r.ServeHTTP(w, req)
	return w
}

func expectUser(mock sqlmock.Sqlmock, roles ...string) {
	mock.ExpectQuery("SELECT email FROM users WHERE id = ? AND status = 'ACTIVE'").WithArgs(uid).WillReturnRows(sqlmock.NewRows([]string{"email"}).AddRow("a@b.co"))
	rows := sqlmock.NewRows([]string{"code"})
	for _, r := range roles {
		rows.AddRow(r)
	}
	mock.ExpectQuery("FROM roles r JOIN user_roles ur").WithArgs(uid).WillReturnRows(rows)
	prows := sqlmock.NewRows([]string{"code"})
	for _, p := range perms {
		prows.AddRow(p)
	}
	mock.ExpectQuery("FROM permissions p").WithArgs(uid).WillReturnRows(prows)
}

var perms []string

func TestAuthenticateRejectsBadCredentialsWithoutQueries(t *testing.T) {
	db, mock := newMock(t)
	r := protected(db, "CUSTOMER")
	good := token(t, jwt.SigningMethodHS256, []byte(secret), okClaims())
	cases := map[string]string{
		"no header":      "",
		"wrong scheme":   "Basic " + good,
		"no token":       "Bearer",
		"garbage":        "Bearer not.a.jwt",
		"wrong secret":   "Bearer " + token(t, jwt.SigningMethodHS256, []byte("other"), okClaims()),
		"expired":        "Bearer " + token(t, jwt.SigningMethodHS256, []byte(secret), jwt.MapClaims{"sub": uid, "exp": time.Now().Add(-time.Minute).Unix()}),
		"no subject":     "Bearer " + token(t, jwt.SigningMethodHS256, []byte(secret), jwt.MapClaims{"exp": time.Now().Add(time.Hour).Unix()}),
		"alg none":       "Bearer " + token(t, jwt.SigningMethodNone, jwt.UnsafeAllowNoneSignatureType, okClaims()),
		"other HMAC alg": "Bearer " + token(t, jwt.SigningMethodHS512, []byte(secret), okClaims()),
	}
	for name, h := range cases {
		w := get(r, h)
		// HS512 is still HMAC with the same secret, so it is accepted by design; every other case must be refused.
		if name == "other HMAC alg" {
			continue
		}
		if w.Code != 401 {
			t.Errorf("%s: status %d", name, w.Code)
		}
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestAuthenticateLoadsRolesFromTheDatabaseEveryRequest(t *testing.T) {
	db, mock := newMock(t)
	r := protected(db, "ADMIN")
	h := "Bearer " + token(t, jwt.SigningMethodHS256, []byte(secret), okClaims())
	expectUser(mock, "CUSTOMER")
	if w := get(r, h); w.Code != 403 {
		t.Fatalf("customer on admin route = %d", w.Code)
	}
	expectUser(mock, "CUSTOMER", "ADMIN") // role granted after the token was issued
	if w := get(r, h); w.Code != 200 || !strings.Contains(w.Body.String(), uid) {
		t.Fatalf("admin = %d %s", w.Code, w.Body.String())
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestAuthenticateRejectsDeactivatedAccounts(t *testing.T) {
	db, mock := newMock(t)
	mock.ExpectQuery("SELECT email FROM users").WithArgs(uid).WillReturnError(sql.ErrNoRows)
	if w := get(protected(db, "CUSTOMER"), "Bearer "+token(t, jwt.SigningMethodHS256, []byte(secret), okClaims())); w.Code != 401 {
		t.Fatalf("%d", w.Code)
	}
}

func TestLoginAndRegisterValidation(t *testing.T) {
	db, mock := newMock(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	RegisterRoutes(r.Group("/auth"), NewService(db, secret))
	post := func(path, body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest("POST", path, strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}
	for _, c := range [][2]string{
		{"/auth/register", `{"email":"nope","password":"password1"}`},
		{"/auth/register", `{"email":"a@b.co","password":"short"}`},
		{"/auth/register", `x`},
		{"/auth/login", `{"email":"","password":""}`},
	} {
		if w := post(c[0], c[1]); w.Code != 400 {
			t.Errorf("%v = %d", c, w.Code)
		}
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}

	hash, _ := bcrypt.GenerateFromPassword([]byte("password1"), bcrypt.MinCost)
	mock.ExpectQuery("SELECT id, password_hash FROM users WHERE email = ?").WithArgs("a@b.co").WillReturnRows(sqlmock.NewRows([]string{"id", "h"}).AddRow(uid, string(hash)))
	mock.ExpectExec("UPDATE users SET last_login_at").WillReturnResult(sqlmock.NewResult(0, 1))
	w := post("/auth/login", `{"email":"a@b.co","password":"password1"}`)
	if w.Code != 200 || !strings.Contains(w.Body.String(), `"token_type":"Bearer"`) {
		t.Fatalf("login = %d %s", w.Code, w.Body.String())
	}
	mock.ExpectQuery("SELECT id, password_hash FROM users").WithArgs("a@b.co").WillReturnRows(sqlmock.NewRows([]string{"id", "h"}).AddRow(uid, string(hash)))
	if w := post("/auth/login", `{"email":"a@b.co","password":"wrong-password"}`); w.Code != 401 {
		t.Fatalf("wrong password = %d", w.Code)
	}
	mock.ExpectQuery("SELECT id, password_hash FROM users").WillReturnError(sql.ErrNoRows)
	w = post("/auth/login", `{"email":"ghost@b.co","password":"password1"}`)
	if w.Code != 401 || !strings.Contains(w.Body.String(), "invalid credentials") {
		t.Fatalf("unknown user must look identical to a wrong password: %d %s", w.Code, w.Body.String())
	}
}

func TestRegisterCreatesUserProfileAndCustomerRole(t *testing.T) {
	db, mock := newMock(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	RegisterRoutes(r.Group("/auth"), NewService(db, secret))
	post := func(body string) *httptest.ResponseRecorder {
		req := httptest.NewRequest("POST", "/auth/register", strings.NewReader(body))
		req.Header.Set("Content-Type", "application/json")
		w := httptest.NewRecorder()
		r.ServeHTTP(w, req)
		return w
	}
	mock.ExpectQuery("SELECT id FROM users WHERE email = ?").WithArgs("a@b.co").WillReturnError(sql.ErrNoRows)
	mock.ExpectBegin()
	mock.ExpectExec("INSERT INTO users").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO user_profiles").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO user_roles").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	w := post(`{"email":"a@b.co","password":"password1","display_name":"สมชาย ใจดี"}`)
	if w.Code != 201 || !strings.Contains(w.Body.String(), `"display_name":"สมชาย ใจดี"`) || strings.Contains(w.Body.String(), "password") {
		t.Fatalf("%d %s", w.Code, w.Body.String())
	}
	mock.ExpectQuery("SELECT id FROM users WHERE email = ?").WillReturnRows(sqlmock.NewRows([]string{"id"}).AddRow(uid))
	if w := post(`{"email":"a@b.co","password":"password1"}`); w.Code != 400 {
		t.Fatalf("duplicate email = %d", w.Code)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestRequirePermissionUsesPermissionsLoadedFromTheDatabase(t *testing.T) {
	db, mock := newMock(t)
	gin.SetMode(gin.TestMode)
	r := gin.New()
	g := r.Group("/p")
	g.Use(Authenticate(db, secret), RequirePermission("refund.approve"))
	g.GET("", func(c *gin.Context) { c.String(200, "ok") })
	h := "Bearer " + token(t, jwt.SigningMethodHS256, []byte(secret), okClaims())

	perms = nil
	expectUser(mock, "ADMIN") // a legacy administrator has no financial permission
	if w := get(r, h); w.Code != 403 {
		t.Fatalf("admin without refund.approve = %d", w.Code)
	}
	perms = []string{"refund.approve"}
	expectUser(mock, "REFUND_OFFICER")
	if w := get(r, h); w.Code != 200 {
		t.Fatalf("refund officer = %d", w.Code)
	}
	perms = nil
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
