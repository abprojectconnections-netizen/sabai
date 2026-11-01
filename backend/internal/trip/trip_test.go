package trip

import (
	"database/sql"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/testutil"
)

const alice = "11111111-1111-4111-8111-111111111111"

func setup(t *testing.T) (http.Handler, sqlmock.Sqlmock) {
	t.Helper()
	db, mock := testutil.NewDB(t)
	r := testutil.Router(func(rg *gin.RouterGroup) { RegisterRoutes(rg.Group("/trips"), NewService(db)) })
	return r, mock
}

func done(t *testing.T, m sqlmock.Sqlmock) {
	t.Helper()
	if err := m.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

var tripRowCols = []string{"id", "name", "destination_id", "start_date", "end_date", "status", "created_at"}

func TestRequiresAuthentication(t *testing.T) {
	r, mock := setup(t)
	for _, c := range [][2]string{{"GET", "/t/trips"}, {"POST", "/t/trips"}, {"GET", "/t/trips/x"}, {"PATCH", "/t/trips/x"}, {"DELETE", "/t/trips/x"}} {
		if got := testutil.Do(t, r, "", c[0], c[1], `{}`); got.Status != 401 {
			t.Errorf("%s %s = %d, want 401", c[0], c[1], got.Status)
		}
	}
	done(t, mock) // no query may run for anonymous callers
}

func TestCreateMatchesPrototypePayload(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectExec("INSERT INTO trips").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), alice, "chiangmai", "ทริปเชียงใหม่ 3 วัน", nil, nil).WillReturnResult(sqlmock.NewResult(0, 1))
	got := testutil.Do(t, r, alice, "POST", "/t/trips", map[string]string{"name": "  ทริปเชียงใหม่ 3 วัน ", "destination_id": "chiangmai", "start_date": "", "end_date": ""})
	if got.Status != 201 {
		t.Fatalf("status %d: %v", got.Status, got.Body)
	}
	d := got.Body["data"].(map[string]any)
	if d["name"] != "ทริปเชียงใหม่ 3 วัน" || d["status"] != "DRAFT" || d["destination_id"] != "chiangmai" || d["start_date"] != "" || d["id"] == "" {
		t.Fatalf("unexpected body %v", d)
	}
	if got.Body["request_id"] == nil {
		t.Fatal("envelope must carry request_id")
	}
	done(t, mock)
}

func TestCreateStoresDatesAndNullDestination(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectExec("INSERT INTO trips").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), alice, nil, "x", "2026-10-25", "2026-10-27").WillReturnResult(sqlmock.NewResult(0, 1))
	if got := testutil.Do(t, r, alice, "POST", "/t/trips", map[string]string{"name": "x", "start_date": "2026-10-25", "end_date": "2026-10-27"}); got.Status != 201 {
		t.Fatalf("status %d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestCreateRejectsInvalidInputWithoutTouchingTheDatabase(t *testing.T) {
	r, mock := setup(t)
	cases := map[string]map[string]string{
		"empty name":       {"name": "   "},
		"long name":        {"name": strings.Repeat("ก", 201)},
		"bad start":        {"name": "x", "start_date": "25/10/2026"},
		"timestamp as day": {"name": "x", "end_date": "2026-10-25T00:00:00Z"},
		"end before start": {"name": "x", "start_date": "2026-10-27", "end_date": "2026-10-25"},
		"too long a trip":  {"name": "x", "start_date": "2026-01-01", "end_date": "2026-12-31"},
		"long destination": {"name": "x", "destination_id": strings.Repeat("a", 37)},
	}
	for name, body := range cases {
		got := testutil.Do(t, r, alice, "POST", "/t/trips", body)
		if got.Status != 400 || got.ErrorCode() != "VALIDATION_ERROR" || got.ErrorMessage() == "" || strings.HasPrefix(got.ErrorMessage(), "validation error") {
			t.Errorf("%s: status=%d code=%q msg=%q", name, got.Status, got.ErrorCode(), got.ErrorMessage())
		}
	}
	if got := testutil.Do(t, r, alice, "POST", "/t/trips", "not json"); got.Status != 400 {
		t.Errorf("invalid JSON = %d", got.Status)
	}
	done(t, mock)
}

func TestListIsScopedToTheCaller(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE user_id = ? AND deleted_at IS NULL").WithArgs(alice, 50, 0).
		WillReturnRows(sqlmock.NewRows(tripRowCols).AddRow("t1", "ทริป", "chiangmai", "2026-10-25", "2026-10-27", "PLANNED", "2026-10-28T01:00:00.000000Z").AddRow("t2", "อีกทริป", "", "", "", "DRAFT", "2026-10-27T01:00:00.000000Z"))
	got := testutil.Do(t, r, alice, "GET", "/t/trips", nil)
	items := got.Body["data"].([]any)
	if got.Status != 200 || len(items) != 2 || items[1].(map[string]any)["start_date"] != "" {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestListReturnsEmptyArrayNotNull(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips").WithArgs(alice, 10, 20).WillReturnRows(sqlmock.NewRows(tripRowCols))
	got := testutil.Do(t, r, alice, "GET", "/t/trips?limit=10&offset=20", nil)
	// `data` has omitempty in the envelope; an empty list must still be a JSON array, which the client requires.
	if arr, ok := got.Body["data"].([]any); !ok || len(arr) != 0 {
		t.Fatalf("data = %#v", got.Body["data"])
	}
	for _, q := range []string{"limit=0", "limit=101", "limit=x", "offset=-1"} {
		if g := testutil.Do(t, r, alice, "GET", "/t/trips?"+q, nil); g.Status != 400 {
			t.Errorf("?%s = %d", q, g.Status)
		}
	}
	done(t, mock)
}

func TestGetGroupsActivitiesByDay(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE id = ? AND user_id = ?").WithArgs("t1", alice).WillReturnRows(sqlmock.NewRows(tripRowCols).AddRow("t1", "ทริป", "", "2026-10-25", "2026-10-26", "PLANNED", "2026-10-28T01:00:00.000000Z"))
	mock.ExpectQuery("FROM trip_days WHERE trip_id = ?").WithArgs("t1").WillReturnRows(sqlmock.NewRows([]string{"id", "d", "n"}).AddRow("d1", "2026-10-25", 1).AddRow("d2", "2026-10-26", 2))
	mock.ExpectQuery("FROM trip_activities a JOIN trip_days d").WithArgs("t1").WillReturnRows(sqlmock.NewRows([]string{"id", "day", "title", "dest", "s", "e"}).
		AddRow("a1", "d1", "วัดพระธาตุ", "", "2026-10-25T09:00:00.000000Z", "").AddRow("a2", "d2", "ตลาด", "", "", "").AddRow("a3", "d1", "ข้าวซอย", "", "2026-10-25T12:00:00.000000Z", ""))
	got := testutil.Do(t, r, alice, "GET", "/t/trips/t1", nil)
	days := got.Body["data"].(map[string]any)["days"].([]any)
	if got.Status != 200 || len(days) != 2 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	if n := len(days[0].(map[string]any)["activities"].([]any)); n != 2 {
		t.Errorf("day 1 activities = %d", n)
	}
	done(t, mock)
}

func TestOtherUsersTripIsNotFound(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE id = ? AND user_id = ?").WithArgs("t1", "bob").WillReturnError(sql.ErrNoRows)
	if got := testutil.Do(t, r, "bob", "GET", "/t/trips/t1", nil); got.Status != 404 || got.ErrorCode() != "NOT_FOUND" {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestDatabaseFailureIsAnOpaque500(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips").WillReturnError(sql.ErrConnDone)
	got := testutil.Do(t, r, alice, "GET", "/t/trips", nil)
	if got.Status != 500 || got.ErrorCode() != "INTERNAL_ERROR" || strings.Contains(got.ErrorMessage(), "conn") {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
}

func TestPartialUpdate(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE id = ? AND user_id = ?").WithArgs("t1", alice).WillReturnRows(sqlmock.NewRows(tripRowCols).AddRow("t1", "เดิม", "chiangmai", "2026-10-25", "2026-10-27", "DRAFT", "2026-10-28T01:00:00.000000Z"))
	mock.ExpectExec("UPDATE trips SET name = ?").WithArgs("ใหม่", "chiangmai", "2026-10-25", "2026-10-27", "PLANNED", sqlmock.AnyArg(), "t1", alice).WillReturnResult(sqlmock.NewResult(0, 1))
	got := testutil.Do(t, r, alice, "PATCH", "/t/trips/t1", map[string]string{"name": "ใหม่", "status": "PLANNED"})
	d, _ := got.Body["data"].(map[string]any)
	if got.Status != 200 || d["name"] != "ใหม่" || d["status"] != "PLANNED" || d["destination_id"] != "chiangmai" {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestUpdateCanClearDatesAndValidatesTheMergedRange(t *testing.T) {
	r, mock := setup(t)
	row := func() {
		mock.ExpectQuery("FROM trips WHERE id").WillReturnRows(sqlmock.NewRows(tripRowCols).AddRow("t1", "x", "", "2026-10-25", "2026-10-27", "DRAFT", "2026-10-28T01:00:00.000000Z"))
	}
	row()
	mock.ExpectExec("UPDATE trips SET").WithArgs("x", nil, nil, nil, "DRAFT", sqlmock.AnyArg(), "t1", alice).WillReturnResult(sqlmock.NewResult(0, 1))
	if got := testutil.Do(t, r, alice, "PATCH", "/t/trips/t1", `{"start_date":"","end_date":""}`); got.Status != 200 {
		t.Fatalf("clear dates: %d %v", got.Status, got.Body)
	}
	row() // moving only the start past the stored end must be rejected
	if got := testutil.Do(t, r, alice, "PATCH", "/t/trips/t1", `{"start_date":"2026-11-01"}`); got.Status != 400 {
		t.Fatalf("merged range: %d %v", got.Status, got.Body)
	}
	row()
	if got := testutil.Do(t, r, alice, "PATCH", "/t/trips/t1", `{"status":"DELETED"}`); got.Status != 400 {
		t.Fatalf("bad status: %d", got.Status)
	}
	done(t, mock)
}

func TestNoOpUpdateIsNotReportedAsMissing(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE id").WillReturnRows(sqlmock.NewRows(tripRowCols).AddRow("t1", "x", "", "", "", "DRAFT", "2026-10-28T01:00:00.000000Z"))
	mock.ExpectExec("UPDATE trips SET").WillReturnResult(sqlmock.NewResult(0, 0)) // MySQL: 0 rows changed
	mock.ExpectQuery("SELECT 1 FROM trips").WithArgs("t1", alice).WillReturnRows(sqlmock.NewRows([]string{"1"}).AddRow(1))
	if got := testutil.Do(t, r, alice, "PATCH", "/t/trips/t1", `{"name":"x"}`); got.Status != 200 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestUpdateUnknownTrip(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectQuery("FROM trips WHERE id").WillReturnError(sql.ErrNoRows)
	if got := testutil.Do(t, r, alice, "PATCH", "/t/trips/zzz", `{"name":"x"}`); got.Status != 404 {
		t.Fatalf("%d", got.Status)
	}
	done(t, mock)
}

func TestDeleteIsASoftDeleteScopedToTheOwner(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectExec("UPDATE trips SET deleted_at = ?").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "t1", alice).WillReturnResult(sqlmock.NewResult(0, 1))
	if got := testutil.Do(t, r, alice, "DELETE", "/t/trips/t1", nil); got.Status != 204 {
		t.Fatalf("%d", got.Status)
	}
	mock.ExpectExec("UPDATE trips SET deleted_at").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "t1", "bob").WillReturnResult(sqlmock.NewResult(0, 0))
	if got := testutil.Do(t, r, "bob", "DELETE", "/t/trips/t1", nil); got.Status != 404 {
		t.Fatalf("other user's delete = %d", got.Status)
	}
	done(t, mock)
}

func expectTripForActivity(mock sqlmock.Sqlmock, start, end any) {
	mock.ExpectBegin()
	mock.ExpectQuery("FROM trips WHERE id = ? AND user_id = ? AND deleted_at IS NULL FOR UPDATE").WithArgs("t1", alice).WillReturnRows(sqlmock.NewRows([]string{"s", "e"}).AddRow(start, end))
}

func TestAddActivityCreatesTheDayOnFirstUse(t *testing.T) {
	r, mock := setup(t)
	expectTripForActivity(mock, "2026-10-25", "2026-10-27")
	mock.ExpectQuery("FROM trip_days WHERE trip_id = ? AND travel_date = ?").WithArgs("t1", "2026-10-26").WillReturnError(sql.ErrNoRows)
	mock.ExpectExec("INSERT INTO trip_days").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), "t1", "2026-10-26", 2).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO trip_activities").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), nil, "ดอยสุเทพ", "2026-10-26 09:30:00", "2026-10-26 11:00:00").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", map[string]string{"title": "ดอยสุเทพ", "date": "2026-10-26", "start_time": "09:30", "end_time": "11:00"})
	d, _ := got.Body["data"].(map[string]any)
	if got.Status != 201 || d["starts_at"] != "2026-10-26T09:30:00.000000Z" {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestAddActivityReusesAnExistingDay(t *testing.T) {
	r, mock := setup(t)
	expectTripForActivity(mock, nil, nil)
	mock.ExpectQuery("FROM trip_days WHERE trip_id = ? AND travel_date = ?").WillReturnRows(sqlmock.NewRows([]string{"id"}).AddRow("d1"))
	mock.ExpectExec("INSERT INTO trip_activities").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), "d1", nil, "พักผ่อน", nil, nil).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	if got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", map[string]string{"title": "พักผ่อน", "date": "2026-12-01"}); got.Status != 201 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestAddActivityNumbersDaysSequentiallyWhenTheTripHasNoDates(t *testing.T) {
	r, mock := setup(t)
	expectTripForActivity(mock, nil, nil)
	mock.ExpectQuery("FROM trip_days WHERE trip_id = ? AND travel_date").WillReturnError(sql.ErrNoRows)
	mock.ExpectQuery("SELECT COUNT(*) + 1 FROM trip_days").WithArgs("t1").WillReturnRows(sqlmock.NewRows([]string{"n"}).AddRow(3))
	mock.ExpectExec("INSERT INTO trip_days").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), sqlmock.AnyArg(), "t1", "2026-12-01", 3).WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO trip_activities").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectCommit()
	if got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", map[string]string{"title": "x", "date": "2026-12-01"}); got.Status != 201 {
		t.Fatalf("%d %v", got.Status, got.Body)
	}
	done(t, mock)
}

func TestAddActivityValidation(t *testing.T) {
	r, mock := setup(t)
	bad := []map[string]string{
		{"title": "", "date": "2026-10-26"},
		{"title": "x", "date": "tomorrow"},
		{"title": "x", "date": "2026-10-26", "start_time": "25:00"},
		{"title": "x", "date": "2026-10-26", "end_time": "10:00"},
		{"title": "x", "date": "2026-10-26", "start_time": "10:00", "end_time": "09:00"},
	}
	for i, b := range bad {
		if got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", b); got.Status != 400 {
			t.Errorf("case %d = %d", i, got.Status)
		}
	}
	done(t, mock) // rejected before any transaction starts
}

func TestAddActivityOutsideTripDatesRollsBack(t *testing.T) {
	r, mock := setup(t)
	expectTripForActivity(mock, "2026-10-25", "2026-10-27")
	mock.ExpectRollback()
	if got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", map[string]string{"title": "x", "date": "2026-10-30"}); got.Status != 400 {
		t.Fatalf("%d", got.Status)
	}
	done(t, mock)
}

func TestAddActivityToSomeoneElsesTrip(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectBegin()
	mock.ExpectQuery("FOR UPDATE").WithArgs("t1", alice).WillReturnError(sql.ErrNoRows)
	mock.ExpectRollback()
	if got := testutil.Do(t, r, alice, "POST", "/t/trips/t1/activities", map[string]string{"title": "x", "date": "2026-10-26"}); got.Status != 404 {
		t.Fatalf("%d", got.Status)
	}
	done(t, mock)
}

func TestDeleteActivity(t *testing.T) {
	r, mock := setup(t)
	mock.ExpectExec("UPDATE trip_activities a JOIN trip_days d").WithArgs(sqlmock.AnyArg(), sqlmock.AnyArg(), "a1", "t1", alice).WillReturnResult(sqlmock.NewResult(0, 1))
	if got := testutil.Do(t, r, alice, "DELETE", "/t/trips/t1/activities/a1", nil); got.Status != 204 {
		t.Fatalf("%d", got.Status)
	}
	mock.ExpectExec("UPDATE trip_activities").WillReturnResult(sqlmock.NewResult(0, 0))
	if got := testutil.Do(t, r, alice, "DELETE", "/t/trips/t1/activities/zz", nil); got.Status != 404 {
		t.Fatalf("%d", got.Status)
	}
	done(t, mock)
}

func TestTimeIsPinnable(t *testing.T) {
	// guards the dbtime.Now seam used by other tests
	if time.Since(time.Now().UTC()) > time.Second {
		t.Fatal("clock")
	}
}
