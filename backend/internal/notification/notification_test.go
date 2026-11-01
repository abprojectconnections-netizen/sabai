package notification

import (
	"context"
	"database/sql"
	"net/http"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/testutil"
)

const alice = "11111111-1111-4111-8111-111111111111"

func setup(t *testing.T) (http.Handler, sqlmock.Sqlmock, *Service) {
	db, mock := testutil.NewDB(t)
	s := NewService(db)
	return testutil.Router(func(rg *gin.RouterGroup) { RegisterRoutes(rg.Group("/n"), s) }), mock, s
}

func TestRequiresAuthentication(t *testing.T) {
	r, mock, _ := setup(t)
	for _, c := range [][2]string{{"GET", "/t/n"}, {"POST", "/t/n/read-all"}, {"PATCH", "/t/n/x/read"}} {
		if got := testutil.Do(t, r, "", c[0], c[1], nil); got.Status != 401 {
			t.Errorf("%v = %d", c, got.Status)
		}
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestListWithUnreadCount(t *testing.T) {
	r, mock, _ := setup(t)
	mock.ExpectQuery("FROM notifications WHERE user_id = ? AND deleted_at IS NULL ORDER BY created_at DESC").WithArgs(alice, 50, 0).
		WillReturnRows(sqlmock.NewRows([]string{"id", "type", "title", "body", "read", "created"}).AddRow("n1", "BOOKING", "จองสำเร็จ", "", false, "2026-10-28T01:00:00.000000Z").AddRow("n2", "PROMO", "คูปอง", "ลด 10%", true, "2026-10-27T01:00:00.000000Z"))
	mock.ExpectQuery("SELECT COUNT(*) FROM notifications WHERE user_id = ?").WithArgs(alice).WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(1))
	got := testutil.Do(t, r, alice, "GET", "/t/n", nil)
	d, _ := got.Body["data"].(map[string]any)
	if got.Status != 200 || len(d["items"].([]any)) != 2 || d["unread_count"] != float64(1) || d["items"].([]any)[1].(map[string]any)["read"] != true {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestListUnreadFilter(t *testing.T) {
	r, mock, _ := setup(t)
	mock.ExpectQuery("AND read_at IS NULL ORDER BY created_at DESC").WithArgs(alice, 50, 0).WillReturnRows(sqlmock.NewRows([]string{"id", "type", "title", "body", "read", "created"}))
	mock.ExpectQuery("SELECT COUNT(*)").WillReturnRows(sqlmock.NewRows([]string{"c"}).AddRow(0))
	got := testutil.Do(t, r, alice, "GET", "/t/n?unread=true", nil)
	if items := got.Body["data"].(map[string]any)["items"]; got.Status != 200 || items == nil || len(items.([]any)) != 0 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestMarkReadIsIdempotentAndOwnerScoped(t *testing.T) {
	r, mock, _ := setup(t)
	mock.ExpectExec("UPDATE notifications SET read_at = COALESCE(read_at, ?)").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "n1", alice).WillReturnResult(sqlmock.NewResult(0, 0)) // already read: 0 rows changed
	mock.ExpectQuery("SELECT 1 FROM notifications WHERE id = ? AND user_id = ?").WithArgs("n1", alice).WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))
	if got := testutil.Do(t, r, alice, "PATCH", "/t/n/n1/read", nil); got.Status != 200 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	mock.ExpectExec("UPDATE notifications").WillReturnResult(sqlmock.NewResult(0, 0))
	mock.ExpectQuery("SELECT 1 FROM notifications").WithArgs("n1", "bob").WillReturnError(sql.ErrNoRows)
	if got := testutil.Do(t, r, "bob", "PATCH", "/t/n/n1/read", nil); got.Status != 404 {
		t.Fatalf("other user's notification = %d", got.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestMarkAllRead(t *testing.T) {
	r, mock, _ := setup(t)
	mock.ExpectExec("UPDATE notifications SET read_at = ?, updated_at = ? WHERE user_id = ? AND deleted_at IS NULL AND read_at IS NULL").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), alice).WillReturnResult(sqlmock.NewResult(0, 4))
	got := testutil.Do(t, r, alice, "POST", "/t/n/read-all", nil)
	if got.Status != 200 || got.Body["data"].(map[string]any)["updated"] != float64(4) {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestCreateValidatesAndStores(t *testing.T) {
	_, mock, s := setup(t)
	ctx := context.Background()
	for _, c := range [][3]string{{"", "T", "x"}, {alice, "", "x"}, {alice, "T", "  "}, {alice, "T", strings.Repeat("a", 201)}, {alice, strings.Repeat("a", 51), "x"}} {
		if _, err := s.Create(ctx, c[0], c[1], c[2], ""); err == nil {
			t.Errorf("expected error for %v", c[:2])
		}
	}
	mock.ExpectExec("INSERT INTO notifications").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), alice, "BOOKING", "จองสำเร็จ", "รายละเอียด").WillReturnResult(sqlmock.NewResult(0, 1))
	if id, err := s.Create(ctx, alice, "BOOKING", " จองสำเร็จ ", "รายละเอียด"); err != nil || id == "" {
		t.Fatalf("%v %q", err, id)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
