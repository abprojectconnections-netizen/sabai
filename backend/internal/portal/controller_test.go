package portal

import (
	"errors"
	"testing"

	"github.com/DATA-DOG/go-sqlmock"
	"github.com/gin-gonic/gin"
	"github.com/travel-super-app/backend/internal/platform/testutil"
)

func router(t *testing.T) (*gin.Engine, sqlmock.Sqlmock) {
	db, mock := testutil.NewDB(t)
	return testutil.Router(func(rg *gin.RouterGroup) { RegisterRoutes(rg, db) }), mock
}

func TestTransitionTable(t *testing.T) {
	for _, c := range []struct {
		tr       transitions
		from, to string
		ok       bool
	}{
		{bookingTransitions, "PENDING", "CONFIRMED", true},
		{bookingTransitions, "CONFIRMED", "CANCELLED", true},
		{bookingTransitions, "CANCELLED", "CONFIRMED", false},
		{bookingTransitions, "CONFIRMED", "PENDING", false},
		{partnerTransitions, "REJECTED", "APPROVED", false},
		{disputeTransitions, "RESOLVED", "OPEN", false},
	} {
		if got := allowed(c.tr, c.from, c.to); got != c.ok {
			t.Errorf("%s→%s = %v, want %v", c.from, c.to, got, c.ok)
		}
	}
}

// An audit failure must roll back the status change (no change without a record), and answer 500.
func TestAuditFailureRollsBackTheStatusChange(t *testing.T) {
	r, mock := router(t)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT status FROM bookings").WithArgs("b1").WillReturnRows(sqlmock.NewRows([]string{"status"}).AddRow("PENDING"))
	mock.ExpectExec("UPDATE bookings SET status").WillReturnResult(sqlmock.NewResult(0, 1))
	mock.ExpectExec("INSERT INTO audit_logs").WillReturnError(errors.New("disk full"))
	mock.ExpectRollback()
	res := testutil.Do(t, r, "staff-1", "PATCH", "/t/bookings/b1/status", map[string]string{"status": "CONFIRMED"})
	if res.Status != 500 {
		t.Fatalf("status = %d %v", res.Status, res.Body)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}

func TestDisallowedTransitionTouchesNothing(t *testing.T) {
	r, mock := router(t)
	mock.ExpectBegin()
	mock.ExpectQuery("SELECT status FROM bookings").WillReturnRows(sqlmock.NewRows([]string{"status"}).AddRow("CANCELLED"))
	mock.ExpectRollback()
	if res := testutil.Do(t, r, "staff-1", "PATCH", "/t/bookings/b1/status", map[string]string{"status": "CONFIRMED"}); res.Status != 409 {
		t.Fatalf("status = %d", res.Status)
	}
	if err := mock.ExpectationsWereMet(); err != nil {
		t.Fatal(err)
	}
}
