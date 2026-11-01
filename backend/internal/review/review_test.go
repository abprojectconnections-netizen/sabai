package review

import (
	"net/http"
	"strings"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/testutil"
)

const alice = "11111111-1111-4111-8111-111111111111"

func setup(t *testing.T) (http.Handler, sqlmock.Sqlmock) {
	db, mock := testutil.NewDB(t)
	return testutil.Router(func(rg *gin.RouterGroup) { RegisterRoutes(rg.Group("/r"), NewService(db)) }), mock
}

var rowCols = []string{"id", "subject_type", "subject_id", "rating", "body", "created", "mine"}

func TestRequiresAuthentication(t *testing.T) {
	r, mock := setup(t)
	if got := testutil.Do(t, r, "", "POST", "/t/r", `{}`); got.Status != 401 {
		t.Fatalf("%d", got.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestCreate(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("SELECT 1 FROM reviews WHERE user_id = ? AND subject_type = ? AND subject_id = ?").WithArgs(alice, "HOTEL", "h1").WillReturnRows(sqlmock.NewRows([]string{"1"}))
	mock.ExpectExec("INSERT INTO reviews").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), alice, "HOTEL", "h1", 4.5, "ดีมาก").WillReturnResult(sqlmock.NewResult(0, 1))
	got := testutil.Do(t, r, alice, "POST", "/t/r", map[string]any{"subject_type": "hotel", "subject_id": "h1", "rating": 4.5, "body": " ดีมาก "})
	d, _ := got.Body["data"].(map[string]any)
	if got.Status != 201 || d["subject_type"] != "HOTEL" || d["rating"] != 4.5 || d["mine"] != true {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestCreateRejectsDuplicates(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("SELECT 1 FROM reviews").WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))
	got := testutil.Do(t, r, alice, "POST", "/t/r", map[string]any{"subject_type": "HOTEL", "subject_id": "h1", "rating": 5})
	if got.Status != 409 || got.ErrorCode() != "CONFLICT" {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestCreateValidation(t *testing.T) {
	r, mock := setup(t)
	ok := func() map[string]any { return map[string]any{"subject_type": "HOTEL", "subject_id": "h1", "rating": 4} }
	mut := func(k string, v any) map[string]any { m := ok(); m[k] = v; return m }
	for name, body := range map[string]map[string]any{
		"unknown type": mut("subject_type", "CAR"), "no subject": mut("subject_id", " "), "long subject": mut("subject_id", strings.Repeat("a", 37)),
		"zero": mut("rating", 0), "too high": mut("rating", 5.5), "quarter step": mut("rating", 3.7), "long body": mut("body", strings.Repeat("ก", 2001)),
	} {
		got := testutil.Do(t, r, alice, "POST", "/t/r", body)
		if got.Status != 400 || got.ErrorCode() != "VALIDATION_ERROR" || strings.Contains(got.ErrorMessage(), "validation error") {
			t.Errorf("%s: %d %q", name, got.Status, got.ErrorMessage())
		}
	}
	if got := testutil.Do(t, r, alice, "POST", "/t/r", "nope"); got.Status != 400 {
		t.Errorf("bad json %d", got.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestListForSubjectWithSummary(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM reviews WHERE subject_type = ? AND subject_id = ? AND deleted_at IS NULL ORDER BY").WithArgs(alice, "HOTEL", "h1", 50, 0).
		WillReturnRows(sqlmock.NewRows(rowCols).AddRow("r1", "HOTEL", "h1", 4.5, "ดี", "2026-10-28T01:00:00.000000Z", true).AddRow("r2", "HOTEL", "h1", 4.0, "", "2026-10-27T01:00:00.000000Z", false))
	mock.ExpectQuery("SELECT COUNT(*), AVG(rating)").WithArgs("HOTEL", "h1").WillReturnRows(sqlmock.NewRows([]string{"c", "a"}).AddRow(2, 4.25))
	got := testutil.Do(t, r, alice, "GET", "/t/r?subject_type=hotel&subject_id=h1", nil)
	d, _ := got.Body["data"].(map[string]any)
	sum, _ := d["summary"].(map[string]any)
	if got.Status != 200 || len(d["items"].([]any)) != 2 || sum["count"] != float64(2) || sum["average"] != 4.3 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestListRequiresASubject(t *testing.T) {
	r, _ := setup(t)
	if got := testutil.Do(t, r, alice, "GET", "/t/r", nil); got.Status != 400 {
		t.Fatalf("%d", got.Status)
	}
}

func TestEmptySubjectHasZeroAverage(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM reviews WHERE subject_type").WillReturnRows(sqlmock.NewRows(rowCols))
	mock.ExpectQuery("SELECT COUNT(*), AVG(rating)").WillReturnRows(sqlmock.NewRows([]string{"c", "a"}).AddRow(0, nil))
	got := testutil.Do(t, r, alice, "GET", "/t/r?subject_type=TOUR&subject_id=t1", nil)
	d, _ := got.Body["data"].(map[string]any)
	if got.Status != 200 || d["summary"].(map[string]any)["average"] != float64(0) {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestMineAndDelete(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM reviews WHERE user_id = ? AND deleted_at IS NULL").WithArgs(alice, alice, 50, 0).WillReturnRows(sqlmock.NewRows(rowCols).AddRow("r1", "TOUR", "t1", 5.0, "", "2026-10-28T01:00:00.000000Z", true))
	if got := testutil.Do(t, r, alice, "GET", "/t/r/mine", nil); got.Status != 200 {
		t.Fatalf("%d", got.Status)
	}
	mock.ExpectExec("UPDATE reviews SET deleted_at = ?").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "r1", alice).WillReturnResult(sqlmock.NewResult(0, 1))
	if got := testutil.Do(t, r, alice, "DELETE", "/t/r/r1", nil); got.Status != 204 {
		t.Fatalf("%d", got.Status)
	}
	mock.ExpectExec("UPDATE reviews SET deleted_at").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "r1", "bob").WillReturnResult(sqlmock.NewResult(0, 0))
	if got := testutil.Do(t, r, "bob", "DELETE", "/t/r/r1", nil); got.Status != 404 {
		t.Fatalf("other user's review = %d", got.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
